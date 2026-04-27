#!/usr/bin/env python3
"""
seed_documents.py — Friko Recomienda v2
Pobla la tabla public.documents en Supabase con el catálogo de productos.
Genera contenido_semantico enriquecido y calcula embeddings con OpenAI.

Uso:
  pip install openai supabase openpyxl
  OPENAI_API_KEY=sk-... SUPABASE_URL=https://... SUPABASE_KEY=... python seed_documents.py
"""

import os, json, time
from dotenv import load_dotenv
from openpyxl import load_workbook
from openai import OpenAI
from supabase import create_client

load_dotenv()

# ── CONFIG ────────────────────────────────────────────────────
OPENAI_API_KEY  = os.environ["OPENAI_API_KEY"]
SUPABASE_URL    = os.environ["SUPABASE_URL_DB"]
SUPABASE_KEY    = os.environ["SUPABASE_SERVICE_KEY_DB"]  # service_role key
EMBED_MODEL     = "text-embedding-3-small"    # DEBE coincidir con Flowise
CATALOG_PATH    = "Data_Limpia_Entrega_1_Catalogo_FRIKO_ANTILLANA.xlsx"
BATCH_SIZE      = 20  # docs por batch de embedding

openai_client  = OpenAI(api_key=OPENAI_API_KEY)
supabase       = create_client(SUPABASE_URL, SUPABASE_KEY)

# ── MAPEO OCASIONES POR CATEGORÍA ────────────────────────────
OCASIONES_MAP = {
    "Pollo":           "Almuerzo del día, Reunión familiar, Asado o parrillada, Cena rápida",
    "Pollo Procesado": "Cena rápida, Picada o rumba, Almuerzo del día",
    "Mariscos":        "Reunión familiar, Asado o parrillada, Picada o rumba",
    "Pescado":         "Almuerzo del día, Cena rápida, Reunión familiar",
    "Pescado Procesado": "Cena rápida, Almuerzo del día, Picada o rumba",
    "Carnes frias":    "Asado o parrillada, Reunión familiar, Picada o rumba",
}

# ── CORRECCIÓN NOMBRES DE REGIÓN ──────────────────────────────
REGION_FIX = {
    "Atlantico":  "Atlántico",
    "Bogota":     "Bogotá",
}

def fix_region(r):
    return REGION_FIX.get(r, r)

def build_semantic_content(row):
    """Construye el texto semántico enriquecido para embedding."""
    sku, marca, nombre, desc, cat, region, gramos, und, pmin, pmax, metodos = row
    region = fix_region(region)
    ocasiones = OCASIONES_MAP.get(cat, "Almuerzo del día, Reunión familiar")
    
    # Texto denso con múltiples perspectivas semánticas
    lines = [
        f"Producto: {nombre} de la marca {marca}.",
        f"Descripción: {desc}.",
        f"Categoría: {cat}.",
        f"Región de disponibilidad: {region}.",
        f"Rinde para {pmin} a {pmax} personas.",
        f"Métodos de preparación compatibles: {metodos}.",
        f"Ocasiones ideales: {ocasiones}.",
        f"Peso neto: {gramos}g.",
        f"SKU del producto: {sku}.",
        # Alias y variaciones para mejor recall semántico
        f"Si buscas algo para preparar en {metodos.split(',')[0].strip().lower()}, este producto es ideal.",
        f"Disponible en {region} para grupos de {pmin} a {pmax} personas.",
    ]
    if und and int(und) > 0:
        lines.append(f"Presentación de {und} unidades.")
    
    return " ".join(lines)

def build_metadata(row):
    sku, marca, nombre, desc, cat, region, gramos, und, pmin, pmax, metodos = row
    region = fix_region(region)
    metodos_list = [m.strip() for m in str(metodos).split(',')]
    return {
        "tipo":      "producto",
        "sku":       sku,
        "marca":     marca,
        "nombre":    nombre,
        "region":    region,
        "categoria": cat,
        "pers_min":  pmin,
        "pers_max":  pmax,
        "metodos":   metodos_list,
        "gramos":    gramos,
    }

def get_embeddings(texts):
    """Llama a OpenAI embeddings API con retry."""
    for attempt in range(3):
        try:
            resp = openai_client.embeddings.create(
                model=EMBED_MODEL,
                input=texts
            )
            return [item.embedding for item in resp.data]
        except Exception as e:
            print(f"  ⚠️  Retry {attempt+1}/3: {e}")
            time.sleep(2 ** attempt)
    raise RuntimeError("Embedding API falló 3 veces")

def main():
    print("📂 Cargando catálogo...")
    wb = load_workbook(CATALOG_PATH, read_only=True)
    ws = wb.active
    rows = [r for r in ws.iter_rows(values_only=True)][1:]  # skip header
    rows = [r for r in rows if r[0]]  # skip empty
    print(f"   {len(rows)} productos encontrados\n")

    # Verificar si ya hay docs (evitar duplicados)
    existing = supabase.table("documents").select("id", count="exact").execute()
    if existing.count and existing.count > 0:
        resp = input(f"⚠️  Ya existen {existing.count} docs en la tabla. ¿Limpiar y reinsertar? (s/N): ")
        if resp.lower() == 's':
            supabase.table("documents").delete().neq("id", 0).execute()
            print("   Tabla limpiada.\n")
        else:
            print("Abortado.")
            return

    # Preparar documentos en batches
    docs_to_insert = []
    for row in rows:
        content  = build_semantic_content(row)
        metadata = build_metadata(row)
        docs_to_insert.append({"content": content, "metadata": metadata})

    print(f"🧮 Generando embeddings en batches de {BATCH_SIZE}...")
    total = len(docs_to_insert)
    
    for i in range(0, total, BATCH_SIZE):
        batch    = docs_to_insert[i:i+BATCH_SIZE]
        texts    = [d["content"] for d in batch]
        print(f"   Batch {i//BATCH_SIZE + 1}/{-(-total//BATCH_SIZE)} ({len(texts)} docs)...")
        
        embeddings = get_embeddings(texts)
        
        records = []
        for doc, emb in zip(batch, embeddings):
            records.append({
                "content":   doc["content"],
                "embedding": emb,
                "metadata":  doc["metadata"],
            })
        
        supabase.table("documents").insert(records).execute()
        time.sleep(0.5)  # rate limit cortesía

    print(f"\n✅ {total} documentos insertados en public.documents")
    print(f"   Modelo usado: {EMBED_MODEL} (dim=1536)")
    print(f"   ⚠️  Asegúrate de usar el mismo modelo en Flowise!\n")

    # Verificación
    count = supabase.table("documents").select("id", count="exact").execute()
    print(f"📊 Total en DB: {count.count} documentos")

if __name__ == "__main__":
    main()
