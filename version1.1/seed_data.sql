-- ============================================================
--  FRIKO RECOMIENDA — seed_data.sql
--  Script de poblado inicial de todas las tablas
--  Compatible con schema_v3.sql
--
--  Orden de ejecución:
--    1. Ejecutar schema_v3.sql (crea tablas, índices, funciones)
--    2. Ejecutar este script (inserta datos)
--
--  Tablas pobladas:
--    ✅ regiones       (6 regiones)
--    ✅ categorias      (6 categorías)
--    ✅ productos       (55 filas — 15 SKUs × regiones disponibles)
--    ✅ recetas         (15 recetas colombianas auténticas)
--    ✅ producto_receta (55 relaciones producto–receta)
--
--  NOTA: La tabla public.documents NO se pobla aquí.
--  Usa seed_documents.py para generar embeddings con OpenAI
--  y poblar documents con los vectores semánticos.
-- ============================================================

BEGIN;

-- ── 1. REGIONES ───────────────────────────────────────────────
-- (idempotente — ya incluidas en schema_v3.sql)
INSERT INTO public.regiones (nombre, slug) VALUES
  ('Antioquia',          'antioquia'),
  ('Atlántico',          'atlantico'),
  ('Bogotá',             'bogota'),
  ('Eje Cafetero',       'eje-cafetero'),
  ('Norte de Santander', 'norte-de-santander'),
  ('Santander',          'santander')
ON CONFLICT (nombre) DO NOTHING;

-- ── 2. CATEGORÍAS ─────────────────────────────────────────────
INSERT INTO public.categorias (nombre) VALUES
  ('Pollo'),
  ('Pollo Procesado'),
  ('Mariscos'),
  ('Pescado'),
  ('Pescado Procesado'),
  ('Carnes frias')
ON CONFLICT (nombre) DO NOTHING;

-- ── 3. PRODUCTOS (55 filas) ───────────────────────────────────
-- Formato: (sku, marca, nombre, descripcion,
--           categoria_id, region_id,
--           gramos, unidades, pers_min, pers_max,
--           metodos_preparacion, contenido_semantico)
--
-- Los subqueries (SELECT id FROM ...) resuelven las FK en tiempo
-- de inserción sin necesidad de conocer los IDs generados.

INSERT INTO public.productos
  (sku, marca, nombre, descripcion,
   categoria_id, region_id,
   gramos, unidades, pers_min, pers_max,
   metodos_preparacion, contenido_semantico)
VALUES

-- ── ANTIOQUIA (9 productos) ─────────────────────────────────

  ('FRIK-002','FRIKO','Alitas picantes','Alitas marinadas picantes',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   900,12,4,6,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Alitas picantes de la marca FRIKO. Descripción: Alitas marinadas picantes. Categoría: Pollo. Región: Antioquia. Rinde para 4 a 6 personas. Métodos: Horno, Airfryer. Ocasiones: Almuerzo del día, Reunión familiar, Asado o parrillada, Cena rápida. Peso: 900g. SKU: FRIK-002. 12 unidades.'),

  ('FRIK-003','FRIKO','Bombones BBQ','Pollo apanado precocido',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   500,10,2,3,
   ARRAY['Sarten','Horno']::text[],
   'Producto: Bombones BBQ de la marca FRIKO. Descripción: Pollo apanado precocido. Categoría: Pollo Procesado. Región: Antioquia. Rinde para 2 a 3 personas. Métodos: Sartén, Horno. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 500g. SKU: FRIK-003. 10 unidades.'),

  ('ANTI-001','ANTILLANA','Brochetas de langostino','Langostino en pincho',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   600,6,4,6,
   ARRAY['Parrilla']::text[],
   'Producto: Brochetas de langostino de la marca ANTILLANA. Descripción: Langostino en pincho. Categoría: Mariscos. Región: Antioquia. Rinde para 4 a 6 personas. Métodos: Parrilla. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 600g. SKU: ANTI-001. 6 unidades.'),

  ('ANTI-002','ANTILLANA','Camaron titi','Camaron precocido',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   700,NULL,4,7,
   ARRAY['Sarten','Salteado']::text[],
   'Producto: Camaron titi de la marca ANTILLANA. Descripción: Camaron precocido. Categoría: Mariscos. Región: Antioquia. Rinde para 4 a 7 personas. Métodos: Sartén, Salteado. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 700g. SKU: ANTI-002.'),

  ('FRIK-005','FRIKO','Chuzos de contramuslo','Contramuslo marinado',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   1900,10,9,12,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chuzos de contramuslo de la marca FRIKO. Descripción: Contramuslo marinado. Categoría: Pollo. Región: Antioquia. Rinde para 9 a 12 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Almuerzo del día. Peso: 1900g. SKU: FRIK-005. 10 unidades.'),

  ('ANTI-003','ANTILLANA','Dedos de merluza','Merluza apanada',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   800,20,5,8,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Dedos de merluza de la marca ANTILLANA. Descripción: Merluza apanada. Categoría: Pescado Procesado. Región: Antioquia. Rinde para 5 a 8 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 800g. SKU: ANTI-003. 20 unidades.'),

  ('FRIK-006','FRIKO','Filete de pechuga','Pechuga sin piel',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   900,NULL,4,6,
   ARRAY['Sarten','Plancha']::text[],
   'Producto: Filete de pechuga de la marca FRIKO. Descripción: Pechuga sin piel porcionada y lista para cocinar. Categoría: Pollo. Región: Antioquia. Rinde para 4 a 6 personas. Métodos: Sartén, Plancha. Ocasiones: Cena rápida, Almuerzo del día, Reunión familiar. Peso: 900g. SKU: FRIK-006.'),

  ('FRIK-007','FRIKO','Lomitos de pechuga','Lomitos congelados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   2000,NULL,10,13,
   ARRAY['Sarten','Wok']::text[],
   'Producto: Lomitos de pechuga de la marca FRIKO. Descripción: Lomitos congelados listos para saltear. Categoría: Pollo. Región: Antioquia. Rinde para 10 a 13 personas. Métodos: Sartén, Wok. Ocasiones: Reunión familiar, Almuerzo del día, Cena rápida. Peso: 2000g. SKU: FRIK-007.'),

  ('FRIK-009','FRIKO','Nuggets de pollo','Nuggets apanados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Antioquia'),
   520,24,2,3,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Nuggets de pollo de la marca FRIKO. Descripción: Nuggets apanados crujientes. Categoría: Pollo Procesado. Región: Antioquia. Rinde para 2 a 3 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 520g. SKU: FRIK-009. 24 unidades.'),

-- ── ATLÁNTICO (11 productos) ─────────────────────────────────

  ('FRIK-001','FRIKO','Alitas BBQ','Alitas marinadas BBQ',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   900,12,4,6,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Alitas BBQ de la marca FRIKO. Descripción: Alitas marinadas BBQ listas para el horno. Categoría: Pollo. Región: Atlántico. Rinde para 4 a 6 personas. Métodos: Horno, Airfryer. Ocasiones: Reunión familiar, Picada o rumba, Almuerzo del día. Peso: 900g. SKU: FRIK-001. 12 unidades.'),

  ('FRIK-002','FRIKO','Alitas picantes','Alitas marinadas picantes',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   900,12,4,6,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Alitas picantes de la marca FRIKO. Descripción: Alitas marinadas picantes. Categoría: Pollo. Región: Atlántico. Rinde para 4 a 6 personas. Métodos: Horno, Airfryer. Ocasiones: Almuerzo del día, Reunión familiar, Asado o parrillada, Cena rápida. Peso: 900g. SKU: FRIK-002. 12 unidades.'),

  ('ANTI-001','ANTILLANA','Brochetas de langostino','Langostino en pincho',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   600,6,4,6,
   ARRAY['Parrilla']::text[],
   'Producto: Brochetas de langostino de la marca ANTILLANA. Descripción: Langostino en pincho. Categoría: Mariscos. Región: Atlántico. Rinde para 4 a 6 personas. Métodos: Parrilla. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 600g. SKU: ANTI-001. 6 unidades.'),

  ('ANTI-002','ANTILLANA','Camaron titi','Camaron precocido',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   700,NULL,4,7,
   ARRAY['Sarten','Salteado']::text[],
   'Producto: Camaron titi de la marca ANTILLANA. Descripción: Camaron precocido. Categoría: Mariscos. Región: Atlántico. Rinde para 4 a 7 personas. Métodos: Sartén, Salteado. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 700g. SKU: ANTI-002.'),

  ('FRIK-004','FRIKO','Chorizo de pollo','Chorizo tipo parrillero',
   (SELECT id FROM public.categorias WHERE nombre='Carnes frias'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   2000,20,10,13,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chorizo de pollo de la marca FRIKO. Descripción: Chorizo tipo parrillero de pollo. Categoría: Carnes frías. Región: Atlántico. Rinde para 10 a 13 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Picada o rumba. Peso: 2000g. SKU: FRIK-004. 20 unidades.'),

  ('FRIK-005','FRIKO','Chuzos de contramuslo','Contramuslo marinado',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   1900,10,9,12,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chuzos de contramuslo de la marca FRIKO. Descripción: Contramuslo marinado. Categoría: Pollo. Región: Atlántico. Rinde para 9 a 12 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Almuerzo del día. Peso: 1900g. SKU: FRIK-005. 10 unidades.'),

  ('ANTI-003','ANTILLANA','Dedos de merluza','Merluza apanada',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   800,20,5,8,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Dedos de merluza de la marca ANTILLANA. Descripción: Merluza apanada. Categoría: Pescado Procesado. Región: Atlántico. Rinde para 5 a 8 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 800g. SKU: ANTI-003. 20 unidades.'),

  ('ANTI-004','ANTILLANA','Filete de salmon premium','Salmon importado',
   (SELECT id FROM public.categorias WHERE nombre='Pescado'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   450,NULL,3,4,
   ARRAY['Plancha','Horno']::text[],
   'Producto: Filete de salmon premium de la marca ANTILLANA. Descripción: Salmón importado porcionado. Categoría: Pescado. Región: Atlántico. Rinde para 3 a 4 personas. Métodos: Plancha, Horno. Ocasiones: Cena rápida, Almuerzo del día, Reunión familiar. Peso: 450g. SKU: ANTI-004.'),

  ('ANTI-005','ANTILLANA','Hamburguesa de salmon','Hamburguesa gourmet',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   454,6,3,4,
   ARRAY['Sarten','Parrilla']::text[],
   'Producto: Hamburguesa de salmon de la marca ANTILLANA. Descripción: Hamburguesa gourmet de salmón. Categoría: Pescado Procesado. Región: Atlántico. Rinde para 3 a 4 personas. Métodos: Sartén, Parrilla. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 454g. SKU: ANTI-005. 6 unidades.'),

  ('FRIK-007','FRIKO','Lomitos de pechuga','Lomitos congelados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   2000,NULL,10,13,
   ARRAY['Sarten','Wok']::text[],
   'Producto: Lomitos de pechuga de la marca FRIKO. Descripción: Lomitos congelados listos para saltear. Categoría: Pollo. Región: Atlántico. Rinde para 10 a 13 personas. Métodos: Sartén, Wok. Ocasiones: Reunión familiar, Almuerzo del día, Cena rápida. Peso: 2000g. SKU: FRIK-007.'),

  ('FRIK-009','FRIKO','Nuggets de pollo','Nuggets apanados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Atlántico'),
   520,24,2,3,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Nuggets de pollo de la marca FRIKO. Descripción: Nuggets apanados crujientes. Categoría: Pollo Procesado. Región: Atlántico. Rinde para 2 a 3 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 520g. SKU: FRIK-009. 24 unidades.'),

-- ── BOGOTÁ (9 productos) ─────────────────────────────────────

  ('FRIK-003','FRIKO','Bombones BBQ','Pollo apanado precocido',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   500,10,2,3,
   ARRAY['Sarten','Horno']::text[],
   'Producto: Bombones BBQ de la marca FRIKO. Descripción: Pollo apanado precocido con salsa BBQ. Categoría: Pollo Procesado. Región: Bogotá. Rinde para 2 a 3 personas. Métodos: Sartén, Horno. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 500g. SKU: FRIK-003. 10 unidades.'),

  ('FRIK-004','FRIKO','Chorizo de pollo','Chorizo tipo parrillero',
   (SELECT id FROM public.categorias WHERE nombre='Carnes frias'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   2000,20,10,13,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chorizo de pollo de la marca FRIKO. Descripción: Chorizo tipo parrillero de pollo. Categoría: Carnes frías. Región: Bogotá. Rinde para 10 a 13 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Picada o rumba. Peso: 2000g. SKU: FRIK-004. 20 unidades.'),

  ('FRIK-005','FRIKO','Chuzos de contramuslo','Contramuslo marinado',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   1900,10,9,12,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chuzos de contramuslo de la marca FRIKO. Descripción: Contramuslo marinado en pincho. Categoría: Pollo. Región: Bogotá. Rinde para 9 a 12 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Almuerzo del día. Peso: 1900g. SKU: FRIK-005. 10 unidades.'),

  ('FRIK-006','FRIKO','Filete de pechuga','Pechuga sin piel',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   900,NULL,4,6,
   ARRAY['Sarten','Plancha']::text[],
   'Producto: Filete de pechuga de la marca FRIKO. Descripción: Pechuga sin piel porcionada y lista. Categoría: Pollo. Región: Bogotá. Rinde para 4 a 6 personas. Métodos: Sartén, Plancha. Ocasiones: Cena rápida, Almuerzo del día, Reunión familiar. Peso: 900g. SKU: FRIK-006.'),

  ('ANTI-004','ANTILLANA','Filete de salmon premium','Salmon importado',
   (SELECT id FROM public.categorias WHERE nombre='Pescado'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   450,NULL,3,4,
   ARRAY['Plancha','Horno']::text[],
   'Producto: Filete de salmon premium de la marca ANTILLANA. Descripción: Salmón importado porcionado. Categoría: Pescado. Región: Bogotá. Rinde para 3 a 4 personas. Métodos: Plancha, Horno. Ocasiones: Cena rápida, Almuerzo del día, Reunión familiar. Peso: 450g. SKU: ANTI-004.'),

  ('FRIK-007','FRIKO','Lomitos de pechuga','Lomitos congelados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   2000,NULL,10,13,
   ARRAY['Sarten','Wok']::text[],
   'Producto: Lomitos de pechuga de la marca FRIKO. Descripción: Lomitos congelados listos para saltear. Categoría: Pollo. Región: Bogotá. Rinde para 10 a 13 personas. Métodos: Sartén, Wok. Ocasiones: Reunión familiar, Almuerzo del día, Cena rápida. Peso: 2000g. SKU: FRIK-007.'),

  ('ANTI-006','ANTILLANA','Medallones de pescado','Pescado blanco porcionado',
   (SELECT id FROM public.categorias WHERE nombre='Pescado'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   1200,12,8,12,
   ARRAY['Horno','Sarten']::text[],
   'Producto: Medallones de pescado de la marca ANTILLANA. Descripción: Pescado blanco porcionado en medallones. Categoría: Pescado. Región: Bogotá. Rinde para 8 a 12 personas. Métodos: Horno, Sartén. Ocasiones: Reunión familiar, Almuerzo del día, Cena rápida. Peso: 1200g. SKU: ANTI-006. 12 unidades.'),

  ('FRIK-008','FRIKO','Mini chuzos','Contramuslo marinado pequeno',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   540,6,2,3,
   ARRAY['Sarten','Airfryer']::text[],
   'Producto: Mini chuzos de la marca FRIKO. Descripción: Contramuslo marinado pequeño en pincho. Categoría: Pollo. Región: Bogotá. Rinde para 2 a 3 personas. Métodos: Sartén, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 540g. SKU: FRIK-008. 6 unidades.'),

  ('FRIK-009','FRIKO','Nuggets de pollo','Nuggets apanados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Bogotá'),
   520,24,2,3,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Nuggets de pollo de la marca FRIKO. Descripción: Nuggets apanados crujientes. Categoría: Pollo Procesado. Región: Bogotá. Rinde para 2 a 3 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 520g. SKU: FRIK-009. 24 unidades.'),

-- ── EJE CAFETERO (10 productos) ──────────────────────────────

  ('FRIK-002','FRIKO','Alitas picantes','Alitas marinadas picantes',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   900,12,4,6,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Alitas picantes de la marca FRIKO. Descripción: Alitas marinadas picantes. Categoría: Pollo. Región: Eje Cafetero. Rinde para 4 a 6 personas. Métodos: Horno, Airfryer. Ocasiones: Almuerzo del día, Reunión familiar, Asado o parrillada, Cena rápida. Peso: 900g. SKU: FRIK-002. 12 unidades.'),

  ('FRIK-003','FRIKO','Bombones BBQ','Pollo apanado precocido',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   500,10,2,3,
   ARRAY['Sarten','Horno']::text[],
   'Producto: Bombones BBQ de la marca FRIKO. Descripción: Pollo apanado precocido con salsa BBQ. Categoría: Pollo Procesado. Región: Eje Cafetero. Rinde para 2 a 3 personas. Métodos: Sartén, Horno. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 500g. SKU: FRIK-003. 10 unidades.'),

  ('ANTI-001','ANTILLANA','Brochetas de langostino','Langostino en pincho',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   600,6,4,6,
   ARRAY['Parrilla']::text[],
   'Producto: Brochetas de langostino de la marca ANTILLANA. Descripción: Langostino en pincho. Categoría: Mariscos. Región: Eje Cafetero. Rinde para 4 a 6 personas. Métodos: Parrilla. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 600g. SKU: ANTI-001. 6 unidades.'),

  ('FRIK-004','FRIKO','Chorizo de pollo','Chorizo tipo parrillero',
   (SELECT id FROM public.categorias WHERE nombre='Carnes frias'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   2000,20,10,13,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chorizo de pollo de la marca FRIKO. Descripción: Chorizo tipo parrillero de pollo. Categoría: Carnes frías. Región: Eje Cafetero. Rinde para 10 a 13 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Picada o rumba. Peso: 2000g. SKU: FRIK-004. 20 unidades.'),

  ('FRIK-005','FRIKO','Chuzos de contramuslo','Contramuslo marinado',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   1900,10,9,12,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chuzos de contramuslo de la marca FRIKO. Descripción: Contramuslo marinado en pincho. Categoría: Pollo. Región: Eje Cafetero. Rinde para 9 a 12 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Almuerzo del día. Peso: 1900g. SKU: FRIK-005. 10 unidades.'),

  ('ANTI-003','ANTILLANA','Dedos de merluza','Merluza apanada',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   800,20,5,8,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Dedos de merluza de la marca ANTILLANA. Descripción: Merluza apanada crujiente. Categoría: Pescado Procesado. Región: Eje Cafetero. Rinde para 5 a 8 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 800g. SKU: ANTI-003. 20 unidades.'),

  ('ANTI-004','ANTILLANA','Filete de salmon premium','Salmon importado',
   (SELECT id FROM public.categorias WHERE nombre='Pescado'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   450,NULL,3,4,
   ARRAY['Plancha','Horno']::text[],
   'Producto: Filete de salmon premium de la marca ANTILLANA. Descripción: Salmón importado porcionado. Categoría: Pescado. Región: Eje Cafetero. Rinde para 3 a 4 personas. Métodos: Plancha, Horno. Ocasiones: Cena rápida, Almuerzo del día, Reunión familiar. Peso: 450g. SKU: ANTI-004.'),

  ('ANTI-005','ANTILLANA','Hamburguesa de salmon','Hamburguesa gourmet',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   454,6,3,4,
   ARRAY['Sarten','Parrilla']::text[],
   'Producto: Hamburguesa de salmon de la marca ANTILLANA. Descripción: Hamburguesa gourmet de salmón. Categoría: Pescado Procesado. Región: Eje Cafetero. Rinde para 3 a 4 personas. Métodos: Sartén, Parrilla. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 454g. SKU: ANTI-005. 6 unidades.'),

  ('FRIK-008','FRIKO','Mini chuzos','Contramuslo marinado pequeno',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   540,6,2,3,
   ARRAY['Sarten','Airfryer']::text[],
   'Producto: Mini chuzos de la marca FRIKO. Descripción: Contramuslo marinado pequeño en pincho. Categoría: Pollo. Región: Eje Cafetero. Rinde para 2 a 3 personas. Métodos: Sartén, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 540g. SKU: FRIK-008. 6 unidades.'),

  ('FRIK-009','FRIKO','Nuggets de pollo','Nuggets apanados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Eje Cafetero'),
   520,24,2,3,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Nuggets de pollo de la marca FRIKO. Descripción: Nuggets apanados crujientes. Categoría: Pollo Procesado. Región: Eje Cafetero. Rinde para 2 a 3 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 520g. SKU: FRIK-009. 24 unidades.'),

-- ── NORTE DE SANTANDER (9 productos) ─────────────────────────

  ('FRIK-001','FRIKO','Alitas BBQ','Alitas marinadas BBQ',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   900,12,4,6,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Alitas BBQ de la marca FRIKO. Descripción: Alitas marinadas BBQ. Categoría: Pollo. Región: Norte de Santander. Rinde para 4 a 6 personas. Métodos: Horno, Airfryer. Ocasiones: Reunión familiar, Picada o rumba, Almuerzo del día. Peso: 900g. SKU: FRIK-001. 12 unidades.'),

  ('ANTI-001','ANTILLANA','Brochetas de langostino','Langostino en pincho',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   600,6,4,6,
   ARRAY['Parrilla']::text[],
   'Producto: Brochetas de langostino de la marca ANTILLANA. Descripción: Langostino en pincho. Categoría: Mariscos. Región: Norte de Santander. Rinde para 4 a 6 personas. Métodos: Parrilla. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 600g. SKU: ANTI-001. 6 unidades.'),

  ('ANTI-002','ANTILLANA','Camaron titi','Camaron precocido',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   700,NULL,4,7,
   ARRAY['Sarten','Salteado']::text[],
   'Producto: Camaron titi de la marca ANTILLANA. Descripción: Camaron precocido. Categoría: Mariscos. Región: Norte de Santander. Rinde para 4 a 7 personas. Métodos: Sartén, Salteado. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 700g. SKU: ANTI-002.'),

  ('FRIK-004','FRIKO','Chorizo de pollo','Chorizo tipo parrillero',
   (SELECT id FROM public.categorias WHERE nombre='Carnes frias'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   2000,20,10,13,
   ARRAY['Parrilla','Sarten']::text[],
   'Producto: Chorizo de pollo de la marca FRIKO. Descripción: Chorizo tipo parrillero de pollo. Categoría: Carnes frías. Región: Norte de Santander. Rinde para 10 a 13 personas. Métodos: Parrilla, Sartén. Ocasiones: Asado o parrillada, Reunión familiar, Picada o rumba. Peso: 2000g. SKU: FRIK-004. 20 unidades.'),

  ('ANTI-003','ANTILLANA','Dedos de merluza','Merluza apanada',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   800,20,5,8,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Dedos de merluza de la marca ANTILLANA. Descripción: Merluza apanada crujiente. Categoría: Pescado Procesado. Región: Norte de Santander. Rinde para 5 a 8 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 800g. SKU: ANTI-003. 20 unidades.'),

  ('FRIK-006','FRIKO','Filete de pechuga','Pechuga sin piel',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   900,NULL,4,6,
   ARRAY['Sarten','Plancha']::text[],
   'Producto: Filete de pechuga de la marca FRIKO. Descripción: Pechuga sin piel porcionada y lista. Categoría: Pollo. Región: Norte de Santander. Rinde para 4 a 6 personas. Métodos: Sartén, Plancha. Ocasiones: Cena rápida, Almuerzo del día, Reunión familiar. Peso: 900g. SKU: FRIK-006.'),

  ('ANTI-005','ANTILLANA','Hamburguesa de salmon','Hamburguesa gourmet',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   454,6,3,4,
   ARRAY['Sarten','Parrilla']::text[],
   'Producto: Hamburguesa de salmon de la marca ANTILLANA. Descripción: Hamburguesa gourmet de salmón. Categoría: Pescado Procesado. Región: Norte de Santander. Rinde para 3 a 4 personas. Métodos: Sartén, Parrilla. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 454g. SKU: ANTI-005. 6 unidades.'),

  ('FRIK-007','FRIKO','Lomitos de pechuga','Lomitos congelados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   2000,NULL,10,13,
   ARRAY['Sarten','Wok']::text[],
   'Producto: Lomitos de pechuga de la marca FRIKO. Descripción: Lomitos congelados listos para saltear. Categoría: Pollo. Región: Norte de Santander. Rinde para 10 a 13 personas. Métodos: Sartén, Wok. Ocasiones: Reunión familiar, Almuerzo del día, Cena rápida. Peso: 2000g. SKU: FRIK-007.'),

  ('ANTI-006','ANTILLANA','Medallones de pescado','Pescado blanco porcionado',
   (SELECT id FROM public.categorias WHERE nombre='Pescado'),
   (SELECT id FROM public.regiones   WHERE nombre='Norte de Santander'),
   1200,12,8,12,
   ARRAY['Horno','Sarten']::text[],
   'Producto: Medallones de pescado de la marca ANTILLANA. Descripción: Pescado blanco porcionado en medallones. Categoría: Pescado. Región: Norte de Santander. Rinde para 8 a 12 personas. Métodos: Horno, Sartén. Ocasiones: Reunión familiar, Almuerzo del día, Cena rápida. Peso: 1200g. SKU: ANTI-006. 12 unidades.'),

-- ── SANTANDER (7 productos) ──────────────────────────────────

  ('FRIK-001','FRIKO','Alitas BBQ','Alitas marinadas BBQ',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   900,12,4,6,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Alitas BBQ de la marca FRIKO. Descripción: Alitas marinadas BBQ. Categoría: Pollo. Región: Santander. Rinde para 4 a 6 personas. Métodos: Horno, Airfryer. Ocasiones: Reunión familiar, Picada o rumba, Almuerzo del día. Peso: 900g. SKU: FRIK-001. 12 unidades.'),

  ('ANTI-001','ANTILLANA','Brochetas de langostino','Langostino en pincho',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   600,6,4,6,
   ARRAY['Parrilla']::text[],
   'Producto: Brochetas de langostino de la marca ANTILLANA. Descripción: Langostino en pincho. Categoría: Mariscos. Región: Santander. Rinde para 4 a 6 personas. Métodos: Parrilla. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 600g. SKU: ANTI-001. 6 unidades.'),

  ('ANTI-002','ANTILLANA','Camaron titi','Camaron precocido',
   (SELECT id FROM public.categorias WHERE nombre='Mariscos'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   700,NULL,4,7,
   ARRAY['Sarten','Salteado']::text[],
   'Producto: Camaron titi de la marca ANTILLANA. Descripción: Camaron precocido. Categoría: Mariscos. Región: Santander. Rinde para 4 a 7 personas. Métodos: Sartén, Salteado. Ocasiones: Reunión familiar, Asado o parrillada, Picada o rumba. Peso: 700g. SKU: ANTI-002.'),

  ('ANTI-003','ANTILLANA','Dedos de merluza','Merluza apanada',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   800,20,5,8,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Dedos de merluza de la marca ANTILLANA. Descripción: Merluza apanada crujiente. Categoría: Pescado Procesado. Región: Santander. Rinde para 5 a 8 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 800g. SKU: ANTI-003. 20 unidades.'),

  ('ANTI-005','ANTILLANA','Hamburguesa de salmon','Hamburguesa gourmet',
   (SELECT id FROM public.categorias WHERE nombre='Pescado Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   454,6,3,4,
   ARRAY['Sarten','Parrilla']::text[],
   'Producto: Hamburguesa de salmon de la marca ANTILLANA. Descripción: Hamburguesa gourmet de salmón. Categoría: Pescado Procesado. Región: Santander. Rinde para 3 a 4 personas. Métodos: Sartén, Parrilla. Ocasiones: Cena rápida, Almuerzo del día, Picada o rumba. Peso: 454g. SKU: ANTI-005. 6 unidades.'),

  ('FRIK-008','FRIKO','Mini chuzos','Contramuslo marinado pequeno',
   (SELECT id FROM public.categorias WHERE nombre='Pollo'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   540,6,2,3,
   ARRAY['Sarten','Airfryer']::text[],
   'Producto: Mini chuzos de la marca FRIKO. Descripción: Contramuslo marinado pequeño en pincho. Categoría: Pollo. Región: Santander. Rinde para 2 a 3 personas. Métodos: Sartén, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 540g. SKU: FRIK-008. 6 unidades.'),

  ('FRIK-009','FRIKO','Nuggets de pollo','Nuggets apanados',
   (SELECT id FROM public.categorias WHERE nombre='Pollo Procesado'),
   (SELECT id FROM public.regiones   WHERE nombre='Santander'),
   520,24,2,3,
   ARRAY['Horno','Airfryer']::text[],
   'Producto: Nuggets de pollo de la marca FRIKO. Descripción: Nuggets apanados crujientes. Categoría: Pollo Procesado. Región: Santander. Rinde para 2 a 3 personas. Métodos: Horno, Airfryer. Ocasiones: Cena rápida, Picada o rumba, Almuerzo del día. Peso: 520g. SKU: FRIK-009. 24 unidades.');

-- ── 4. RECETAS (15 recetas colombianas auténticas) ────────────
-- Una receta representativa por SKU único
-- ingredientes y pasos en formato JSONB

INSERT INTO public.recetas
  (titulo, tiempo_preparacion, porciones, ingredientes, pasos, contenido_semantico, activo)
VALUES

-- R01: FRIK-001 Alitas BBQ
('Alitas BBQ Friko al horno crujientes',
 '40 minutos', '4 a 6 personas',
 '[
   {"item": "Alitas BBQ Friko",          "cantidad": "1 paquete (900g)"},
   {"item": "Aceite de oliva",            "cantidad": "2 cucharadas"},
   {"item": "Ajo en polvo",               "cantidad": "1 cucharadita"},
   {"item": "Pimienta negra",             "cantidad": "al gusto"},
   {"item": "Salsa BBQ adicional",        "cantidad": "4 cucharadas (opcional)"},
   {"item": "Cebolla cabezona roja",      "cantidad": "½ unidad, en aros"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta el horno a 200 °C. Forra una bandeja con papel aluminio."},
   {"paso": 2, "descripcion": "Saca las alitas del empaque y pásalas a un tazón. Rocía con aceite de oliva, ajo en polvo y pimienta. Mezcla bien."},
   {"paso": 3, "descripcion": "Acomoda las alitas en la bandeja sin amontonarlas. Hornea 20 minutos."},
   {"paso": 4, "descripcion": "Voltea las alitas y hornea 15 minutos más hasta que estén doradas y crujientes."},
   {"paso": 5, "descripcion": "Si quieres más glaseado, pinta con salsa BBQ adicional y hornea 5 minutos más."},
   {"paso": 6, "descripcion": "Sirve con aros de cebolla roja y papas fritas o yuca frita."}
 ]'::jsonb,
 'Receta de Alitas BBQ Friko al horno. Crujientes por fuera, jugosas por dentro. Ideal para reuniones familiares y picadas. Tiempo: 40 minutos. Porciones: 4 a 6 personas.',
 true),

-- R02: FRIK-002 Alitas picantes
('Alitas picantes Friko en Airfryer con guacamole',
 '30 minutos', '4 a 6 personas',
 '[
   {"item": "Alitas picantes Friko",       "cantidad": "1 paquete (900g)"},
   {"item": "Aguacate maduro",             "cantidad": "2 unidades"},
   {"item": "Tomate chonto",               "cantidad": "1 unidad, picado fino"},
   {"item": "Cilantro fresco",             "cantidad": "¼ taza picada"},
   {"item": "Limón",                       "cantidad": "2 unidades"},
   {"item": "Sal",                         "cantidad": "al gusto"},
   {"item": "Chile o salsa picante",       "cantidad": "al gusto"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta el Airfryer a 190 °C por 3 minutos."},
   {"paso": 2, "descripcion": "Coloca las alitas directamente desde el congelador en la canasta del Airfryer sin encimar."},
   {"paso": 3, "descripcion": "Cocina 20 minutos, sacudiendo la canasta a la mitad del tiempo para cocción pareja."},
   {"paso": 4, "descripcion": "Mientras se cocinan, prepara el guacamole: aplasta el aguacate y mezcla con tomate, cilantro, jugo de limón y sal."},
   {"paso": 5, "descripcion": "Sirve las alitas calientes sobre el guacamole o acompañadas en un tazón aparte."}
 ]'::jsonb,
 'Receta de Alitas picantes Friko en Airfryer con guacamole colombiano. Rápida y crujiente. Tiempo: 30 minutos. Porciones: 4 a 6 personas.',
 true),

-- R03: FRIK-003 Bombones BBQ
('Bombones BBQ Friko en sartén con arroz con coco',
 '25 minutos', '2 a 3 personas',
 '[
   {"item": "Bombones BBQ Friko",          "cantidad": "1 paquete (500g)"},
   {"item": "Aceite vegetal",              "cantidad": "3 cucharadas"},
   {"item": "Arroz blanco",               "cantidad": "1 taza"},
   {"item": "Leche de coco",              "cantidad": "200 ml"},
   {"item": "Sal",                        "cantidad": "al gusto"},
   {"item": "Ensalada de repollo",        "cantidad": "al gusto"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Prepara el arroz con coco: cocina el arroz reemplazando la mitad del agua por leche de coco y una pizca de sal."},
   {"paso": 2, "descripcion": "Calienta el aceite en un sartén a fuego medio-alto."},
   {"paso": 3, "descripcion": "Agrega los bombones congelados al sartén. Cocina 5 minutos por cada lado hasta dorar."},
   {"paso": 4, "descripcion": "Reduce el fuego a medio y tapa el sartén. Cocina 5 minutos más para que el centro quede bien caliente."},
   {"paso": 5, "descripcion": "Sirve los bombones sobre el arroz con coco y acompaña con ensalada de repollo."}
 ]'::jsonb,
 'Receta de Bombones BBQ Friko con arroz con coco. Cena rápida y sabrosa. Tiempo: 25 minutos. Porciones: 2 a 3 personas.',
 true),

-- R04: FRIK-004 Chorizo de pollo
('Chorizo de pollo Friko a la parrilla con ají de maní',
 '35 minutos', '10 a 13 personas',
 '[
   {"item": "Chorizo de pollo Friko",       "cantidad": "1 paquete (2000g / 20 und)"},
   {"item": "Maní tostado sin sal",          "cantidad": "1 taza"},
   {"item": "Hogao (cebolla y tomate)",       "cantidad": "½ taza"},
   {"item": "Caldo de pollo",                "cantidad": "½ taza"},
   {"item": "Ají amarillo o color",          "cantidad": "1 cucharadita"},
   {"item": "Sal y pimienta",                "cantidad": "al gusto"},
   {"item": "Papa criolla cocida",           "cantidad": "1 kg"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta la parrilla a fuego medio-alto."},
   {"paso": 2, "descripcion": "Pincha cada chorizo con un palillo para evitar que exploten al asarse."},
   {"paso": 3, "descripcion": "Cocina los chorizos en la parrilla 10-12 minutos, girándolos cada 3 minutos para dorar parejo."},
   {"paso": 4, "descripcion": "Prepara el ají de maní: licúa el maní con el hogao, el caldo y el ají. Sazona con sal y pimienta."},
   {"paso": 5, "descripcion": "Sirve los chorizos con papa criolla cocida y bañados con el ají de maní caliente."}
 ]'::jsonb,
 'Receta de Chorizo de pollo Friko a la parrilla con ají de maní. Perfecto para asados y reuniones grandes. Tiempo: 35 minutos. Porciones: 10 a 13 personas.',
 true),

-- R05: FRIK-005 Chuzos de contramuslo
('Chuzos de contramuslo Friko a la parrilla con chimichurri',
 '35 minutos', '9 a 12 personas',
 '[
   {"item": "Chuzos de contramuslo Friko",   "cantidad": "1 paquete (1900g / 10 und)"},
   {"item": "Perejil liso fresco",            "cantidad": "1 taza"},
   {"item": "Ajo",                            "cantidad": "4 dientes"},
   {"item": "Aceite de oliva",                "cantidad": "½ taza"},
   {"item": "Vinagre de vino blanco",         "cantidad": "2 cucharadas"},
   {"item": "Ají seco triturado",             "cantidad": "1 cucharadita"},
   {"item": "Sal y pimienta",                 "cantidad": "al gusto"},
   {"item": "Limón",                          "cantidad": "2 unidades"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Prepara el chimichurri: pica finamente el perejil y el ajo. Mezcla con aceite, vinagre, ají seco, sal y pimienta. Reserva 30 min para que los sabores se integren."},
   {"paso": 2, "descripcion": "Precalienta la parrilla a fuego fuerte."},
   {"paso": 3, "descripcion": "Coloca los chuzos directamente desde el congelador sobre la parrilla caliente."},
   {"paso": 4, "descripcion": "Cocina 12-15 minutos por lado hasta que estén dorados y bien cocidos en el centro."},
   {"paso": 5, "descripcion": "Sirve con el chimichurri encima y rodajas de limón al lado."}
 ]'::jsonb,
 'Receta de Chuzos de contramuslo Friko a la parrilla con chimichurri colombiano. Ideal para asados y reuniones de 9 a 12 personas. Tiempo: 35 minutos.',
 true),

-- R06: FRIK-006 Filete de pechuga
('Filete de pechuga Friko a la plancha con hogao y arroz',
 '25 minutos', '4 a 6 personas',
 '[
   {"item": "Filete de pechuga Friko",   "cantidad": "1 paquete (900g)"},
   {"item": "Tomate chonto maduro",      "cantidad": "2 unidades, picados"},
   {"item": "Cebolla cabezona blanca",   "cantidad": "1 unidad, picada fina"},
   {"item": "Ajo",                       "cantidad": "2 dientes picados"},
   {"item": "Aceite vegetal",            "cantidad": "3 cucharadas"},
   {"item": "Comino en polvo",           "cantidad": "½ cucharadita"},
   {"item": "Sal y pimienta",            "cantidad": "al gusto"},
   {"item": "Arroz blanco cocido",       "cantidad": "para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Prepara el hogao: sofríe la cebolla y el ajo en 2 cucharadas de aceite hasta transparentar. Agrega el tomate, comino, sal y cocina 10 min a fuego medio hasta reducir."},
   {"paso": 2, "descripcion": "Sazona los filetes con sal y pimienta."},
   {"paso": 3, "descripcion": "Calienta la plancha o sartén antiadherente a fuego alto con 1 cucharada de aceite."},
   {"paso": 4, "descripcion": "Cocina los filetes 5-6 minutos por cada lado hasta dorar y alcanzar temperatura interna de 74 °C."},
   {"paso": 5, "descripcion": "Sirve el filete sobre el arroz blanco y cubre con el hogao caliente."}
 ]'::jsonb,
 'Receta de Filete de pechuga Friko a la plancha con hogao colombiano. Almuerzo rápido y nutritivo. Tiempo: 25 minutos. Porciones: 4 a 6 personas.',
 true),

-- R07: FRIK-007 Lomitos de pechuga
('Lomitos de pechuga Friko al wok con verduras',
 '20 minutos', '10 a 13 personas',
 '[
   {"item": "Lomitos de pechuga Friko",    "cantidad": "1 paquete (2000g)"},
   {"item": "Pimentón rojo",               "cantidad": "2 unidades, en julianas"},
   {"item": "Cebolla junca",               "cantidad": "1 atado, en trozos"},
   {"item": "Zanahoria",                   "cantidad": "2 unidades, en bastones"},
   {"item": "Salsa de soya",               "cantidad": "4 cucharadas"},
   {"item": "Jengibre fresco rallado",     "cantidad": "1 cucharada"},
   {"item": "Aceite de ajonjolí",          "cantidad": "2 cucharadas"},
   {"item": "Maicena",                     "cantidad": "1 cucharada disuelta en agua"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Calienta el wok a fuego muy alto con el aceite de ajonjolí."},
   {"paso": 2, "descripcion": "Agrega los lomitos directamente desde el congelador. Saltea 4-5 minutos moviéndolos constantemente hasta sellar."},
   {"paso": 3, "descripcion": "Incorpora la zanahoria y el pimentón. Saltea 3 minutos más."},
   {"paso": 4, "descripcion": "Agrega la salsa de soya, el jengibre y la cebolla junca. Mezcla bien."},
   {"paso": 5, "descripcion": "Añade la maicena disuelta para espesar la salsa. Cocina 2 minutos más."},
   {"paso": 6, "descripcion": "Sirve sobre arroz blanco o fideos de arroz."}
 ]'::jsonb,
 'Receta de Lomitos de pechuga Friko al wok con verduras. Plato rápido y nutritivo para grupos grandes. Tiempo: 20 minutos. Porciones: 10 a 13 personas.',
 true),

-- R08: FRIK-008 Mini chuzos
('Mini chuzos Friko en Airfryer con chimichurri de aguacate',
 '20 minutos', '2 a 3 personas',
 '[
   {"item": "Mini chuzos Friko",        "cantidad": "1 paquete (540g / 6 und)"},
   {"item": "Aguacate maduro",          "cantidad": "1 unidad"},
   {"item": "Limón",                    "cantidad": "1 unidad"},
   {"item": "Cilantro fresco",          "cantidad": "3 cucharadas picadas"},
   {"item": "Ajo",                      "cantidad": "1 diente"},
   {"item": "Sal y pimienta",           "cantidad": "al gusto"},
   {"item": "Tostadas o pita",          "cantidad": "para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta el Airfryer a 195 °C por 3 minutos."},
   {"paso": 2, "descripcion": "Coloca los mini chuzos en la canasta sin amontonar. Cocina 12-14 minutos, girando a la mitad."},
   {"paso": 3, "descripcion": "Prepara el chimichurri de aguacate: aplasta el aguacate con limón, cilantro, ajo rallado, sal y pimienta hasta obtener una crema."},
   {"paso": 4, "descripcion": "Sirve los mini chuzos sobre las tostadas con el chimichurri de aguacate encima."}
 ]'::jsonb,
 'Receta de Mini chuzos Friko en Airfryer con chimichurri de aguacate. Cena rápida para 2 a 3 personas. Tiempo: 20 minutos.',
 true),

-- R09: FRIK-009 Nuggets de pollo
('Nuggets de pollo Friko al horno con salsa rosada',
 '20 minutos', '2 a 3 personas',
 '[
   {"item": "Nuggets de pollo Friko",    "cantidad": "1 paquete (520g / 24 und)"},
   {"item": "Mayonesa",                  "cantidad": "3 cucharadas"},
   {"item": "Kétchup",                   "cantidad": "2 cucharadas"},
   {"item": "Mostaza",                   "cantidad": "1 cucharadita"},
   {"item": "Limón",                     "cantidad": "unas gotas"},
   {"item": "Papas fritas",              "cantidad": "para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta el horno a 200 °C. Forra una bandeja con papel encerado."},
   {"paso": 2, "descripcion": "Coloca los nuggets en la bandeja sin amontonar. Hornea 15 minutos volteando a la mitad."},
   {"paso": 3, "descripcion": "Prepara la salsa rosada: mezcla la mayonesa, kétchup, mostaza y unas gotas de limón."},
   {"paso": 4, "descripcion": "Sirve los nuggets calientes con la salsa rosada y papas fritas."}
 ]'::jsonb,
 'Receta de Nuggets de pollo Friko al horno con salsa rosada casera. Ideal para cenas rápidas y niños. Tiempo: 20 minutos. Porciones: 2 a 3 personas.',
 true),

-- R10: ANTI-001 Brochetas de langostino
('Brochetas de langostino Antillana a la parrilla con mantequilla de ajo',
 '25 minutos', '4 a 6 personas',
 '[
   {"item": "Brochetas de langostino Antillana", "cantidad": "1 paquete (600g / 6 und)"},
   {"item": "Mantequilla sin sal",               "cantidad": "4 cucharadas"},
   {"item": "Ajo",                               "cantidad": "4 dientes picados"},
   {"item": "Perejil fresco",                    "cantidad": "¼ taza picada"},
   {"item": "Limón",                             "cantidad": "2 unidades"},
   {"item": "Sal y pimienta blanca",             "cantidad": "al gusto"},
   {"item": "Pan artesanal o tostadas",          "cantidad": "para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta la parrilla a fuego medio-alto."},
   {"paso": 2, "descripcion": "Derrite la mantequilla en una sartén pequeña y sofríe el ajo 2 minutos a fuego bajo hasta dorar ligeramente."},
   {"paso": 3, "descripcion": "Coloca las brochetas en la parrilla. Cocina 3-4 minutos por lado pintando con la mantequilla de ajo."},
   {"paso": 4, "descripcion": "Finaliza con perejil picado y jugo de limón fresco."},
   {"paso": 5, "descripcion": "Sirve inmediatamente con pan artesanal para recoger los jugos."}
 ]'::jsonb,
 'Receta de Brochetas de langostino Antillana a la parrilla con mantequilla de ajo. Mariscos gourmet en minutos. Tiempo: 25 minutos. Porciones: 4 a 6 personas.',
 true),

-- R11: ANTI-002 Camaron titi
('Camarón titi Antillana salteado con coco y ají dulce',
 '20 minutos', '4 a 7 personas',
 '[
   {"item": "Camaron titi Antillana",      "cantidad": "1 paquete (700g)"},
   {"item": "Leche de coco",              "cantidad": "200 ml"},
   {"item": "Ají dulce",                  "cantidad": "4 unidades picados"},
   {"item": "Cebolla cabezona",           "cantidad": "1 unidad en julianas"},
   {"item": "Ajo",                        "cantidad": "3 dientes"},
   {"item": "Aceite de coco o vegetal",   "cantidad": "2 cucharadas"},
   {"item": "Cilantro",                   "cantidad": "¼ taza"},
   {"item": "Arroz blanco",              "cantidad": "para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Calienta el aceite en un sartén a fuego alto. Sofríe el ajo y el ají dulce 2 minutos."},
   {"paso": 2, "descripcion": "Agrega la cebolla y saltea 2 minutos más hasta transparentar."},
   {"paso": 3, "descripcion": "Incorpora los camarones directamente desde el congelador. Saltea 4-5 minutos."},
   {"paso": 4, "descripcion": "Vierte la leche de coco y cocina 3 minutos más a fuego medio hasta que la salsa espese."},
   {"paso": 5, "descripcion": "Finaliza con cilantro fresco y sirve sobre arroz blanco."}
 ]'::jsonb,
 'Receta de Camarón titi Antillana salteado con coco y ají dulce. Sabor caribeño colombiano. Tiempo: 20 minutos. Porciones: 4 a 7 personas.',
 true),

-- R12: ANTI-003 Dedos de merluza
('Dedos de merluza Antillana al Airfryer con salsa tártara',
 '20 minutos', '5 a 8 personas',
 '[
   {"item": "Dedos de merluza Antillana",  "cantidad": "1 paquete (800g / 20 und)"},
   {"item": "Mayonesa",                    "cantidad": "4 cucharadas"},
   {"item": "Pepinillo encurtido",         "cantidad": "2 cucharadas picadas finas"},
   {"item": "Alcaparras",                  "cantidad": "1 cucharada picadas"},
   {"item": "Mostaza",                     "cantidad": "1 cucharadita"},
   {"item": "Limón",                       "cantidad": "unas gotas"},
   {"item": "Ensalada verde",              "cantidad": "para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta el Airfryer a 200 °C por 3 minutos."},
   {"paso": 2, "descripcion": "Coloca los dedos de merluza en la canasta en una sola capa. Cocina 12 minutos volteando a la mitad."},
   {"paso": 3, "descripcion": "Prepara la salsa tártara: mezcla la mayonesa con pepinillo, alcaparras, mostaza y limón."},
   {"paso": 4, "descripcion": "Sirve los dedos bien dorados y crujientes con la salsa tártara y ensalada verde."}
 ]'::jsonb,
 'Receta de Dedos de merluza Antillana en Airfryer con salsa tártara casera. Crujientes y sin aceite. Tiempo: 20 minutos. Porciones: 5 a 8 personas.',
 true),

-- R13: ANTI-004 Filete de salmón premium
('Filete de salmón premium Antillana a la plancha con salsa de maracuyá',
 '20 minutos', '3 a 4 personas',
 '[
   {"item": "Filete de salmon premium Antillana","cantidad": "1 paquete (450g)"},
   {"item": "Pulpa de maracuyá",                  "cantidad": "4 cucharadas"},
   {"item": "Miel de abejas",                     "cantidad": "2 cucharadas"},
   {"item": "Mantequilla",                        "cantidad": "2 cucharadas"},
   {"item": "Sal y pimienta",                     "cantidad": "al gusto"},
   {"item": "Espárragos o judías verdes",         "cantidad": "200g para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Saca los filetes del congelador y descongélalos 30 min en nevera si el tiempo lo permite (o cocina directo)."},
   {"paso": 2, "descripcion": "Sazona los filetes con sal y pimienta por ambos lados."},
   {"paso": 3, "descripcion": "Calienta la plancha o sartén con mantequilla a fuego medio-alto."},
   {"paso": 4, "descripcion": "Cocina el salmón 4-5 minutos por cada lado hasta que el centro esté ligeramente rosado."},
   {"paso": 5, "descripcion": "Prepara la salsa: en la misma sartén mezcla el maracuyá y la miel, cocina 2 minutos revolviendo."},
   {"paso": 6, "descripcion": "Sirve el salmón bañado con la salsa de maracuyá y acompaña con espárragos salteados."}
 ]'::jsonb,
 'Receta de Filete de salmón premium Antillana a la plancha con salsa de maracuyá. Elegante y fácil. Tiempo: 20 minutos. Porciones: 3 a 4 personas.',
 true),

-- R14: ANTI-005 Hamburguesa de salmón
('Hamburguesa de salmón Antillana gourmet con aguacate',
 '20 minutos', '3 a 4 personas',
 '[
   {"item": "Hamburguesa de salmon Antillana", "cantidad": "1 paquete (454g / 6 und)"},
   {"item": "Pan de hamburguesa",              "cantidad": "4 unidades"},
   {"item": "Aguacate",                        "cantidad": "1 unidad, en láminas"},
   {"item": "Lechuga romana",                  "cantidad": "4 hojas"},
   {"item": "Tomate",                          "cantidad": "1 unidad, en rodajas"},
   {"item": "Mayonesa con limón",              "cantidad": "4 cucharadas"},
   {"item": "Sal y pimienta",                  "cantidad": "al gusto"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Calienta el sartén antiadherente a fuego medio-alto con un poco de aceite."},
   {"paso": 2, "descripcion": "Cocina las hamburguesas 4-5 minutos por lado hasta dorar bien por fuera."},
   {"paso": 3, "descripcion": "Tuesta los panes en la misma sartén 1 minuto por lado."},
   {"paso": 4, "descripcion": "Arma la hamburguesa: pan, mayonesa con limón, lechuga, hamburguesa de salmón, aguacate y tomate."},
   {"paso": 5, "descripcion": "Sirve inmediatamente con ensalada o papas."}
 ]'::jsonb,
 'Receta de Hamburguesa de salmón Antillana gourmet con aguacate. Versión colombiana sofisticada. Tiempo: 20 minutos. Porciones: 3 a 4 personas.',
 true),

-- R15: ANTI-006 Medallones de pescado
('Medallones de pescado Antillana al horno con salsa verde',
 '30 minutos', '8 a 12 personas',
 '[
   {"item": "Medallones de pescado Antillana",  "cantidad": "1 paquete (1200g / 12 und)"},
   {"item": "Cilantro fresco",                  "cantidad": "1 taza"},
   {"item": "Espinaca fresca",                  "cantidad": "1 taza"},
   {"item": "Ajo",                              "cantidad": "3 dientes"},
   {"item": "Aceite de oliva",                  "cantidad": "¼ taza"},
   {"item": "Limón",                            "cantidad": "2 unidades"},
   {"item": "Sal y pimienta",                   "cantidad": "al gusto"},
   {"item": "Papa pastusa cocida",              "cantidad": "1 kg para acompañar"}
 ]'::jsonb,
 '[
   {"paso": 1, "descripcion": "Precalienta el horno a 200 °C. Engrasa una bandeja con aceite."},
   {"paso": 2, "descripcion": "Acomoda los medallones en la bandeja. Sazona con sal, pimienta y jugo de ½ limón."},
   {"paso": 3, "descripcion": "Hornea 20-22 minutos hasta que el pescado esté bien cocido y ligeramente dorado."},
   {"paso": 4, "descripcion": "Prepara la salsa verde: licúa cilantro, espinaca, ajo, aceite de oliva, jugo de 1 limón, sal y pimienta hasta obtener una salsa cremosa."},
   {"paso": 5, "descripcion": "Sirve los medallones bañados con la salsa verde y acompañados de papa pastusa cocida."}
 ]'::jsonb,
 'Receta de Medallones de pescado Antillana al horno con salsa verde de cilantro. Ideal para reuniones grandes. Tiempo: 30 minutos. Porciones: 8 a 12 personas.',
 true);


-- ── 5. PRODUCTO_RECETA (55 relaciones) ───────────────────────
-- Vincula cada fila de productos con su receta correspondiente por SKU
-- relevancia: 1=principal, 2=alternativa, 3=complementaria

INSERT INTO public.producto_receta (producto_id, receta_id, relevancia)
SELECT p.id, r.id, 1
FROM public.productos p
JOIN public.recetas   r ON (
  (p.sku = 'FRIK-001' AND r.titulo ILIKE '%Alitas BBQ%')      OR
  (p.sku = 'FRIK-002' AND r.titulo ILIKE '%Alitas picantes%') OR
  (p.sku = 'FRIK-003' AND r.titulo ILIKE '%Bombones BBQ%')    OR
  (p.sku = 'FRIK-004' AND r.titulo ILIKE '%Chorizo de pollo%')OR
  (p.sku = 'FRIK-005' AND r.titulo ILIKE '%contramuslo%')     OR
  (p.sku = 'FRIK-006' AND r.titulo ILIKE '%pechuga%' AND r.titulo ILIKE '%plancha%') OR
  (p.sku = 'FRIK-007' AND r.titulo ILIKE '%Lomitos%')         OR
  (p.sku = 'FRIK-008' AND r.titulo ILIKE '%Mini chuzos%')     OR
  (p.sku = 'FRIK-009' AND r.titulo ILIKE '%Nuggets%')         OR
  (p.sku = 'ANTI-001' AND r.titulo ILIKE '%langostino%')      OR
  (p.sku = 'ANTI-002' AND r.titulo ILIKE '%amaron%')          OR
  (p.sku = 'ANTI-003' AND r.titulo ILIKE '%merluza%')         OR
  (p.sku = 'ANTI-004' AND r.titulo ILIKE '%salm%' AND r.titulo ILIKE '%plancha%') OR
  (p.sku = 'ANTI-005' AND r.titulo ILIKE '%Hamburguesa de salm%') OR
  (p.sku = 'ANTI-006' AND r.titulo ILIKE '%Medallones%')
)
ON CONFLICT (producto_id, receta_id) DO NOTHING;


-- ── 6. VERIFICACIÓN FINAL ────────────────────────────────────
-- Ejecuta estas queries para confirmar que el seed fue exitoso:
--
-- SELECT COUNT(*) FROM public.productos;       -- debe ser 55
-- SELECT COUNT(*) FROM public.recetas;         -- debe ser 15
-- SELECT COUNT(*) FROM public.producto_receta; -- debe ser 55
-- SELECT COUNT(*) FROM public.regiones;        -- debe ser 6
-- SELECT COUNT(*) FROM public.categorias;      -- debe ser 6
--
-- Distribución por región:
-- SELECT r.nombre, COUNT(p.id) AS productos
-- FROM public.regiones r
-- LEFT JOIN public.productos p ON p.region_id = r.id
-- GROUP BY r.nombre ORDER BY r.nombre;
--
-- Relaciones producto-receta:
-- SELECT p.sku, p.nombre, p.marca, re.nombre AS region, rec.titulo
-- FROM public.productos p
-- JOIN public.regiones re        ON re.id = p.region_id
-- JOIN public.producto_receta pr ON pr.producto_id = p.id
-- JOIN public.recetas rec        ON rec.id = pr.receta_id
-- ORDER BY p.sku, re.nombre
-- LIMIT 20;

COMMIT;