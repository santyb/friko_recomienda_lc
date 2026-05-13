-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.categorias (
  id bigint NOT NULL DEFAULT nextval('categorias_id_seq'::regclass),
  nombre text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categorias_pkey PRIMARY KEY (id)
);
CREATE TABLE public.documents (
  id bigint NOT NULL DEFAULT nextval('documents_id_seq'::regclass),
  content text NOT NULL,
  embedding USER-DEFINED,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT documents_pkey PRIMARY KEY (id)
);
CREATE TABLE public.producto_receta (
  producto_id bigint NOT NULL,
  receta_id bigint NOT NULL,
  relevancia smallint DEFAULT 1 CHECK (relevancia >= 1 AND relevancia <= 3),
  CONSTRAINT producto_receta_pkey PRIMARY KEY (producto_id, receta_id),
  CONSTRAINT producto_receta_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.productos(id),
  CONSTRAINT producto_receta_receta_id_fkey FOREIGN KEY (receta_id) REFERENCES public.recetas(id)
);
CREATE TABLE public.productos (
  id bigint NOT NULL DEFAULT nextval('productos_id_seq'::regclass),
  sku text NOT NULL,
  marca text NOT NULL DEFAULT 'FRIKO'::text,
  nombre text NOT NULL,
  descripcion text,
  categoria_id bigint,
  region_id bigint,
  gramos integer,
  unidades integer,
  pers_min integer,
  pers_max integer,
  metodos_preparacion ARRAY,
  contenido_semantico text,
  embedding USER-DEFINED,
  metadata jsonb DEFAULT '{}'::jsonb,
  activo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT productos_pkey PRIMARY KEY (id),
  CONSTRAINT productos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id),
  CONSTRAINT productos_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.regiones(id)
);
CREATE TABLE public.recetas (
  id bigint NOT NULL DEFAULT nextval('recetas_id_seq'::regclass),
  titulo text NOT NULL,
  url text,
  imagen_url text,
  tiempo_preparacion text,
  porciones text,
  ingredientes jsonb NOT NULL DEFAULT '[]'::jsonb,
  pasos jsonb NOT NULL DEFAULT '[]'::jsonb,
  contenido_semantico text,
  embedding USER-DEFINED,
  metadata jsonb DEFAULT '{}'::jsonb,
  activo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT recetas_pkey PRIMARY KEY (id)
);
CREATE TABLE public.regiones (
  id bigint NOT NULL DEFAULT nextval('regiones_id_seq'::regclass),
  nombre text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  activo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT regiones_pkey PRIMARY KEY (id)
);