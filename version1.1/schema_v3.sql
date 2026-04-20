-- ============================================================
--  FRIKO RECOMIENDA — Schema v3 (PRODUCCIÓN VALIDADA)
--  Ejecutar en Supabase SQL Editor
--  v3 vs v2: Fix match_documents filter (NULL guard + jsonb cast)
--            + Nota compatibilidad HNSW
--            + match_documents más robusto
-- ============================================================

-- ── 0. EXTENSIONES ───────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ── 1. TABLAS BASE ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.regiones (
  id         bigserial PRIMARY KEY,
  nombre     text NOT NULL UNIQUE,
  slug       text NOT NULL UNIQUE,
  activo     boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.categorias (
  id         bigserial PRIMARY KEY,
  nombre     text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.productos (
  id                  bigserial PRIMARY KEY,
  sku                 text NOT NULL,
  marca               text NOT NULL DEFAULT 'FRIKO',
  nombre              text NOT NULL,
  descripcion         text,
  categoria_id        bigint REFERENCES public.categorias(id),
  region_id           bigint REFERENCES public.regiones(id),
  gramos              integer,
  unidades            integer,
  pers_min            integer,
  pers_max            integer,
  metodos_preparacion text[],
  contenido_semantico text,
  embedding           vector(1536),
  metadata            jsonb DEFAULT '{}',
  activo              boolean DEFAULT true,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.recetas (
  id                  bigserial PRIMARY KEY,
  titulo              text NOT NULL,
  url                 text,
  imagen_url          text,
  tiempo_preparacion  text,
  porciones           text,
  ingredientes        jsonb NOT NULL DEFAULT '[]',
  pasos               jsonb NOT NULL DEFAULT '[]',
  contenido_semantico text,
  embedding           vector(1536),
  metadata            jsonb DEFAULT '{}',
  activo              boolean DEFAULT true,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.producto_receta (
  producto_id bigint NOT NULL REFERENCES public.productos(id),
  receta_id   bigint NOT NULL REFERENCES public.recetas(id),
  relevancia  smallint DEFAULT 1 CHECK (relevancia BETWEEN 1 AND 3),
  PRIMARY KEY (producto_id, receta_id)
);

CREATE TABLE IF NOT EXISTS public.documents (
  id         bigserial PRIMARY KEY,
  content    text NOT NULL,
  embedding  vector(1536),
  metadata   jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bot_sessions (
  chat_id    text PRIMARY KEY,
  session    jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes')
);

-- ── 2. ÍNDICES VECTORIALES ────────────────────────────────────
-- HNSW requiere pgvector >= 0.5.0 (Supabase >= Nov 2023).
-- Para verificar tu versión: SELECT extversion FROM pg_extension WHERE extname='vector';
-- Si la versión es < 0.5.0, usa IVFFlat (ver comentario al final).

CREATE INDEX IF NOT EXISTS idx_documents_embedding
  ON public.documents USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_productos_embedding
  ON public.productos USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_recetas_embedding
  ON public.recetas USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Índices relacionales
CREATE INDEX IF NOT EXISTS idx_productos_region   ON public.productos(region_id);
CREATE INDEX IF NOT EXISTS idx_productos_sku      ON public.productos(sku);
CREATE INDEX IF NOT EXISTS idx_documents_metadata ON public.documents USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_bot_sessions_exp   ON public.bot_sessions(expires_at);

/*
  FALLBACK IVFFLAT (si HNSW no está disponible):
  Comenta los bloques HNSW de arriba y ejecuta:

  CREATE INDEX IF NOT EXISTS idx_documents_embedding
    ON public.documents USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);

  CREATE INDEX IF NOT EXISTS idx_productos_embedding
    ON public.productos USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);

  CREATE INDEX IF NOT EXISTS idx_recetas_embedding
    ON public.recetas USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);

  NOTA: ivfflat requiere datos en la tabla antes de ser útil.
  Ejecuta seed_documents.py ANTES de crear el índice IVFFlat.
*/

-- ── 3. FUNCIÓN match_documents v3 (CORREGIDA) ────────────────
-- FIXES vs v2:
--   + NULL guard en el WHERE (filter IS NULL)
--   + Cast explícito a jsonb (filter = '{}'::jsonb) — evita
--     comparación implícita que puede fallar en algunos contextos PG
--   + Manejo de similarity negativa (cosine distance puede dar > 1)
--
-- Firma esperada por Flowise:
--   rpc('match_documents', { query_embedding, match_count, filter })

DROP FUNCTION IF EXISTS public.match_documents(vector, int, jsonb);

CREATE OR REPLACE FUNCTION public.match_documents (
  query_embedding  vector(1536),
  match_count      int     DEFAULT 10,
  filter           jsonb   DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.content,
    d.metadata,
    -- Clamp similarity to [0,1] para evitar valores negativos por precisión float
    GREATEST(0.0, 1.0 - (d.embedding <=> query_embedding))::float AS similarity
  FROM public.documents d
  WHERE
    d.embedding IS NOT NULL
    AND (
      filter IS NULL
      OR filter = '{}'::jsonb
      OR d.metadata @> filter
    )
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ── 4. FUNCIÓN match_productos ────────────────────────────────

DROP FUNCTION IF EXISTS public.match_productos(vector, int, text, text);

CREATE OR REPLACE FUNCTION public.match_productos (
  query_embedding  vector(1536),
  match_count      int     DEFAULT 8,
  filter_region    text    DEFAULT NULL,
  filter_marca     text    DEFAULT NULL
)
RETURNS TABLE (
  id          bigint,
  sku         text,
  marca       text,
  nombre      text,
  descripcion text,
  categoria   text,
  region      text,
  gramos      integer,
  pers_min    integer,
  pers_max    integer,
  metodos     text[],
  similarity  float
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.sku,
    p.marca,
    p.nombre,
    p.descripcion,
    c.nombre                                                          AS categoria,
    r.nombre                                                          AS region,
    p.gramos,
    p.pers_min,
    p.pers_max,
    p.metodos_preparacion,
    GREATEST(0.0, 1.0 - (p.embedding <=> query_embedding))::float    AS similarity
  FROM public.productos p
  JOIN public.regiones   r ON r.id = p.region_id
  JOIN public.categorias c ON c.id = p.categoria_id
  WHERE
    p.activo = true
    AND p.embedding IS NOT NULL
    AND (filter_region IS NULL OR r.nombre ILIKE filter_region)
    AND (filter_marca  IS NULL OR p.marca = filter_marca)
  ORDER BY p.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ── 5. FUNCIÓN match_recetas ─────────────────────────────────

DROP FUNCTION IF EXISTS public.match_recetas(vector, int);

CREATE OR REPLACE FUNCTION public.match_recetas (
  query_embedding vector(1536),
  match_count     int DEFAULT 3
)
RETURNS TABLE (
  id                 bigint,
  titulo             text,
  url                text,
  tiempo_preparacion text,
  porciones          text,
  ingredientes       jsonb,
  pasos              jsonb,
  similarity         float
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id, r.titulo, r.url, r.tiempo_preparacion, r.porciones,
    r.ingredientes, r.pasos,
    GREATEST(0.0, 1.0 - (r.embedding <=> query_embedding))::float AS similarity
  FROM public.recetas r
  WHERE r.activo = true AND r.embedding IS NOT NULL
  ORDER BY r.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ── 6. LIMPIEZA DE SESIONES ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.cleanup_expired_sessions()
RETURNS void LANGUAGE sql AS $$
  DELETE FROM public.bot_sessions WHERE expires_at < now();
$$;

-- ── 7. DATOS INICIALES ────────────────────────────────────────

INSERT INTO public.regiones (nombre, slug) VALUES
  ('Antioquia',          'antioquia'),
  ('Atlántico',          'atlantico'),
  ('Bogotá',             'bogota'),
  ('Eje Cafetero',       'eje-cafetero'),
  ('Norte de Santander', 'norte-de-santander'),
  ('Santander',          'santander')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.categorias (nombre) VALUES
  ('Pollo'),
  ('Pollo Procesado'),
  ('Mariscos'),
  ('Pescado'),
  ('Pescado Procesado'),
  ('Carnes frias')
ON CONFLICT (nombre) DO NOTHING;

-- ── 8. GRANTS (para anon key de Flowise) ─────────────────────
-- Ejecuta esto si Flowise usa la anon key (y no la service_role key):
--
-- GRANT EXECUTE ON FUNCTION public.match_documents TO anon, authenticated;
-- GRANT SELECT ON public.documents TO anon, authenticated;
--
-- Si usas service_role key en Flowise, no necesitas estos grants.
-- RECOMENDADO: usa la anon key en Flowise (menor superficie de ataque).

-- ── 9. VERIFICACIÓN RÁPIDA ────────────────────────────────────
-- Ejecuta después del seed para verificar:
--
-- SELECT COUNT(*), COUNT(embedding) FROM documents;
-- -- Debe dar el mismo número en ambas columnas (99 si catálogo completo)
--
-- SELECT match_documents('[0.1,0.2,...]'::vector, 3);
-- -- Debe retornar 3 filas sin error
