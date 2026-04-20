-- ================================================================
-- FRIKO RAG SYSTEM - SCHEMA V2
-- Base de datos Supabase con pgvector para sistema conversacional
-- Ejecutar en orden: 01 → 02 → 03
-- ================================================================

CREATE EXTENSION IF NOT EXISTS vector;
-- ----------------------------------------------------------------
-- TABLA: bot_sessions
-- manejo de sessiones chat por usuario (chat_id de Telegram)
-- ----------------------------------------------------------------
CREATE TABLE public.bot_sessions (
  chat_id text NOT NULL,
  session jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + '00:30:00'::interval),
  CONSTRAINT bot_sessions_pkey PRIMARY KEY (chat_id)
);
-- ----------------------------------------------------------------
-- TABLA: regiones
-- 6 regiones de cobertura del catálogo
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.regiones (
  id         bigserial PRIMARY KEY,
  nombre     text NOT NULL UNIQUE,
  slug       text NOT NULL UNIQUE,
  activo     boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.regiones IS 'Regiones de cobertura donde hay productos disponibles';

-- NOTA: La validación ciudad → región se delega al LLM mediante su
-- conocimiento geográfico incorporado en el system prompt de Flowise.
-- No existe tabla de ciudades en la base de datos.

-- ----------------------------------------------------------------
-- TABLA: categorias
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categorias (
  id         bigserial PRIMARY KEY,
  nombre     text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.categorias IS 'Categorías de producto: Pollo, Mariscos, Pescado, etc.';

-- ----------------------------------------------------------------
-- TABLA: productos
-- Catálogo completo con todos los campos del Excel
-- UNIQUE(sku, region_id) porque el mismo SKU puede estar en varias regiones
-- ----------------------------------------------------------------
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
  metodos_preparacion text[],         -- Ej: '{Horno, Airfryer}'
  contenido_semantico text,           -- Texto enriquecido para el embedding
  embedding           vector(1536),   -- OpenAI text-embedding-ada-002
  metadata            jsonb DEFAULT '{}',
  activo              boolean DEFAULT true,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now(),
  UNIQUE(sku, region_id)
);
CREATE INDEX IF NOT EXISTS idx_productos_sku    ON public.productos (sku);
CREATE INDEX IF NOT EXISTS idx_productos_region ON public.productos (region_id);
CREATE INDEX IF NOT EXISTS idx_productos_cat    ON public.productos (categoria_id);
CREATE INDEX IF NOT EXISTS idx_productos_pers   ON public.productos (pers_min, pers_max);
CREATE INDEX IF NOT EXISTS idx_productos_embed  ON public.productos
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);
COMMENT ON TABLE public.productos IS 'Catálogo de productos Friko/Antillana con embeddings para búsqueda semántica';
COMMENT ON COLUMN public.productos.metodos_preparacion IS 'Array de métodos: {Horno, Airfryer, Sartén, Parrilla, Plancha, Wok, Salteado}';
COMMENT ON COLUMN public.productos.contenido_semantico IS 'Texto que se embeddea; combina nombre, descripción, categoría, métodos, rango de personas';

-- ----------------------------------------------------------------
-- TABLA: recetas
-- 200 recetas reales de momentosfriko.com
-- ----------------------------------------------------------------
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
CREATE INDEX IF NOT EXISTS idx_recetas_embed ON public.recetas
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);
COMMENT ON TABLE public.recetas IS 'Recetas reales de momentosfriko.com; base para Regla 6 (receta real vs generada)';

-- ----------------------------------------------------------------
-- TABLA: producto_receta (N:M)
-- Asocia productos con sus recetas reales
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.producto_receta (
  producto_id bigint NOT NULL REFERENCES public.productos(id) ON DELETE CASCADE,
  receta_id   bigint NOT NULL REFERENCES public.recetas(id)   ON DELETE CASCADE,
  relevancia  smallint DEFAULT 1 CHECK (relevancia IN (1,2,3)),
  PRIMARY KEY (producto_id, receta_id)
);
COMMENT ON TABLE public.producto_receta IS 'Relación producto ↔ receta. relevancia: 1=mencionado, 2=ingrediente principal, 3=receta oficial Friko';

-- ----------------------------------------------------------------
-- TABLA: documents (Vector Store unificado para Flowise)
-- UNA sola tabla para productos Y recetas con metadata estructurado
-- Flowise lee de aquí; el filtrado por región/tipo se hace en metadata
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.documents (
  id         bigserial PRIMARY KEY,
  content    text NOT NULL,
  embedding  vector(1536),
  metadata   jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_documents_embed    ON public.documents
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_documents_metadata ON public.documents USING gin (metadata);
CREATE INDEX IF NOT EXISTS idx_documents_type     ON public.documents ((metadata->>'type'));
CREATE INDEX IF NOT EXISTS idx_documents_region   ON public.documents ((metadata->>'region'));
COMMENT ON TABLE public.documents IS 'Vector store principal para Flowise. metadata.type = producto | receta';
COMMENT ON COLUMN public.documents.metadata IS 'Estructura: {type, sku, nombre, marca, region, categoria, pers_min, pers_max, metodos, score_base, tiene_receta_real}';

-- ----------------------------------------------------------------
-- TABLA: bot_sessions
-- Estado conversacional por usuario (chat_id de Telegram u otro)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bot_sessions (
  chat_id    text PRIMARY KEY,
  session    jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes')
);
CREATE INDEX IF NOT EXISTS idx_bot_sessions_expires ON public.bot_sessions (expires_at);
COMMENT ON TABLE public.bot_sessions IS 'Sesión conversacional. session = {region, personas, metodo, ocasion, estado}';

-- ----------------------------------------------------------------
-- FUNCIÓN: match_documents
-- Búsqueda semántica con filtro de metadata para Flowise
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_count     int     DEFAULT 8,
  filter          jsonb   DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) AS similarity
  FROM public.documents d
  WHERE
    (filter = '{}'::jsonb OR d.metadata @> filter)
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- NOTA: La función get_region_by_ciudad fue eliminada.
-- La validación ciudad → región la realiza el LLM con conocimiento
-- geográfico embebido en el system prompt. Ver FrikoRAGPipeline_ChatflowV2.json.

-- ----------------------------------------------------------------
-- TRIGGER: updated_at automático
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_productos_upd') THEN
    CREATE TRIGGER trg_productos_upd
      BEFORE UPDATE ON public.productos
      FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_recetas_upd') THEN
    CREATE TRIGGER trg_recetas_upd
      BEFORE UPDATE ON public.recetas
      FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();
  END IF;
END;
$$;
