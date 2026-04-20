-- ============================================================
--  FRIKO RECOMIENDA — Schema v2 (CORREGIDO Y OPTIMIZADO)
--  Ejecutar en Supabase SQL Editor
--  Cambios vs v1:
--    + Función match_documents (pgvector RPC) [BUG-02]
--    + Función match_productos y match_recetas
--    + Índices HNSW en columnas embedding [BUG-03]
--    + Corrección de Bogota → Bogotá [BUG-12]
--    + Tabla de datos iniciales (regiones, categorías)
-- ============================================================

-- ── 0. EXTENSIONES ───────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ── 1. TABLAS BASE ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.regiones (
  id         bigserial PRIMARY KEY,
  nombre     text NOT NULL UNIQUE,   -- "Antioquia", "Bogotá", etc.
  slug       text NOT NULL UNIQUE,   -- "antioquia", "bogota", etc.
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
  contenido_semantico text,      -- texto enriquecido para embedding
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

-- Tabla RAG principal para Flowise
CREATE TABLE IF NOT EXISTS public.documents (
  id         bigserial PRIMARY KEY,
  content    text NOT NULL,
  embedding  vector(1536),
  metadata   jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Sesiones del bot (Telegram / web)
CREATE TABLE IF NOT EXISTS public.bot_sessions (
  chat_id    text PRIMARY KEY,
  session    jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes')
);

-- ── 2. ÍNDICES VECTORIALES HNSW [BUG-03] ─────────────────────
-- HNSW: mejor para queries en tiempo real (baja latencia)
-- Dimensión 1536 = text-embedding-3-small / ada-002

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

-- ── 3. FUNCIÓN RPC match_documents [BUG-02] ──────────────────
-- Requerida por Flowise (queryName: "match_documents")

CREATE OR REPLACE FUNCTION public.match_documents (
  query_embedding  vector(1536),
  match_count      int     DEFAULT 10,
  filter           jsonb   DEFAULT '{}'
)
RETURNS TABLE (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
)
LANGUAGE plpgsql
AS $$
#variable_conflict use_variable
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM public.documents d
  WHERE
    -- Filtro por metadata si se proporciona
    (filter = '{}' OR d.metadata @> filter)
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ── 4. FUNCIÓN RPC match_productos ───────────────────────────
-- Para queries directas desde Edge Functions o n8n

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
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.sku,
    p.marca,
    p.nombre,
    p.descripcion,
    c.nombre  AS categoria,
    r.nombre  AS region,
    p.gramos,
    p.pers_min,
    p.pers_max,
    p.metodos_preparacion,
    1 - (p.embedding <=> query_embedding) AS similarity
  FROM public.productos p
  JOIN public.regiones   r ON r.id = p.region_id
  JOIN public.categorias c ON c.id = p.categoria_id
  WHERE
    p.activo = true
    AND (filter_region IS NULL OR r.nombre ILIKE filter_region)
    AND (filter_marca  IS NULL OR p.marca  = filter_marca)
  ORDER BY p.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ── 5. FUNCIÓN RPC match_recetas ─────────────────────────────

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
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id, r.titulo, r.url, r.tiempo_preparacion, r.porciones,
    r.ingredientes, r.pasos,
    1 - (r.embedding <=> query_embedding) AS similarity
  FROM public.recetas r
  WHERE r.activo = true
  ORDER BY r.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ── 6. FUNCIÓN limpieza de sesiones expiradas ─────────────────

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

-- ── 8. NOTAS DE USO ───────────────────────────────────────────
--
-- Para popular la tabla documents desde Python/n8n:
--
--   1. Genera el contenido_semantico de cada producto:
--      "Producto: {nombre} ({marca}). {descripcion}. Categoría: {cat}.
--       Región: {region}. Para {pmin}-{pmax} personas.
--       Métodos de preparación: {metodos}. SKU: {sku}.
--       Ocasiones ideales: {ocasiones_inferidas}."
--
--   2. Genera el embedding con text-embedding-3-small (dim=1536)
--
--   3. Inserta en documents con metadata:
--      {"sku": "FRIK-001", "region": "Antioquia", "marca": "FRIKO",
--       "categoria": "Pollo", "pers_min": 4, "pers_max": 6,
--       "metodos": ["Horno","Airfryer"], "tipo": "producto"}
--
--   4. Para recetas, usa metadata:
--      {"producto_sku": "FRIK-001", "tipo": "receta",
--       "es_oficial": true, "url": "https://momentosfriko.com/..."}
--
-- IMPORTANTE: El modelo de embedding en Flowise (text-embedding-3-small)
-- DEBE ser el mismo que se usó para poblar la tabla documents.
-- Si se cambia el modelo, hay que re-embeddear todos los documentos.
