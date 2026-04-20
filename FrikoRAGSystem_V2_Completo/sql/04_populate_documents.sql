-- ================================================================
-- 04_populate_documents.sql
-- Puebla la tabla documents desde productos y recetas
-- NOTA: Los embeddings se generan DESPUÉS con el script Python
--       (populate_embeddings.py). Este script solo prepara el contenido.
-- ================================================================

-- Limpiar documentos existentes antes de repoblar
TRUNCATE public.documents;

-- ----------------------------------------------------------------
-- PARTE 1: Insertar documentos de PRODUCTOS
-- Un documento por producto-región (cada combinación es única)
-- ----------------------------------------------------------------
INSERT INTO public.documents (content, metadata)
SELECT
  -- Contenido rico para embedding semántico
  format(
    'PRODUCTO FRIKO - %s
Marca: %s
Descripción: %s
Categoría: %s
Región disponible: %s
Gramaje: %sg | Unidades: %s
Rinde para: %s a %s personas
Métodos de preparación: %s
Disponibilidad regional: Producto disponible en %s.',
    p.nombre,
    p.marca,
    COALESCE(p.descripcion, 'Sin descripción'),
    c.nombre,
    r.nombre,
    p.gramos,
    COALESCE(p.unidades::text, 'N/A'),
    p.pers_min,
    p.pers_max,
    array_to_string(p.metodos_preparacion, ', '),
    r.nombre
  ) AS content,
  jsonb_build_object(
    'type',           'producto',
    'sku',            p.sku,
    'nombre',         p.nombre,
    'marca',          p.marca,
    'region',         r.nombre,
    'region_slug',    r.slug,
    'categoria',      c.nombre,
    'gramos',         p.gramos,
    'pers_min',       p.pers_min,
    'pers_max',       p.pers_max,
    'metodos',        to_jsonb(p.metodos_preparacion),
    'tiene_receta_real', EXISTS(
      SELECT 1 FROM public.producto_receta pr2
      JOIN public.productos p2 ON pr2.producto_id = p2.id
      WHERE p2.sku = p.sku
    ),
    'score_base',     50  -- Regla 1: +50 por región (se suma en el prompt)
  ) AS metadata
FROM public.productos p
JOIN public.categorias c ON p.categoria_id = c.id
JOIN public.regiones   r ON p.region_id    = r.id
WHERE p.activo = true;

-- ----------------------------------------------------------------
-- PARTE 2: Insertar documentos de RECETAS
-- ----------------------------------------------------------------
INSERT INTO public.documents (content, metadata)
SELECT
  format(
    'RECETA FRIKO - %s
Tiempo de preparación: %s | Porciones: %s
Ingredientes: %s
Preparación: %s',
    rec.titulo,
    COALESCE(NULLIF(rec.tiempo_preparacion, ''), 'No especificado'),
    COALESCE(NULLIF(rec.porciones, ''), 'Variable'),
    (SELECT string_agg(elem::text, ', ') 
     FROM jsonb_array_elements_text(rec.ingredientes) elem),
    (SELECT string_agg(elem::text, ' | ') 
     FROM jsonb_array_elements_text(rec.pasos) elem)
  ) AS content,
  jsonb_build_object(
    'type',            'receta',
    'receta_id',       rec.id,
    'titulo',          rec.titulo,
    'url',             rec.url,
    'imagen_url',      rec.imagen_url,
    'tiempo',          rec.tiempo_preparacion,
    'porciones',       rec.porciones,
    'tipo_receta',     'receta_real',
    'productos_mencionados', rec.metadata->'productos_mencionados'
  ) AS metadata
FROM public.recetas rec
WHERE rec.activo = true;

-- ----------------------------------------------------------------
-- VERIFICACIÓN
-- ----------------------------------------------------------------
SELECT
  metadata->>'type' AS tipo,
  COUNT(*)          AS total
FROM public.documents
GROUP BY 1;

-- Los embeddings se generarán con el script Python externo.
-- Ver: docs/populate_embeddings.py
