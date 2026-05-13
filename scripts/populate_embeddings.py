"""
populate_embeddings.py
======================
Genera embeddings OpenAI (text-embedding-3-small) para todos los documentos
en la tabla `documents` de Supabase y actualiza los registros.

Dependencias:
    pip install openai supabase python-dotenv

Variables de entorno (.env):
    OPENAI_API_KEY="OPENAI_API_KEY"
    SUPABASE_URL=https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY=eyJ...
    
"""

import os, time
from dotenv import load_dotenv
from openai import OpenAI
from supabase import create_client

load_dotenv()

openai   = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])

EMBEDDING_MODEL = "text-embedding-3-small"
BATCH_SIZE = 50       # OpenAI permite hasta 2048 inputs por batch
SLEEP_SECS = 0.5      # Throttle para respetar rate limits

def get_embedding(texts: list[str]) -> list[list[float]]:
    """Obtiene embeddings para una lista de textos."""
    response = openai.embeddings.create(
        model=EMBEDDING_MODEL,
        input=texts
    )
    return [item.embedding for item in response.data]

def main():
    # 1. Obtener todos los documentos sin embedding
    print("Consultando documentos sin embedding...")
    result = supabase.table("documents").select("id, content").is_("embedding", "null").execute()
    docs = result.data

    if not docs:
        print("✅ Todos los documentos ya tienen embedding.")
        return

    print(f"📄 {len(docs)} documentos por procesar...")

    # 2. Procesar en batches
    total_procesados = 0
    for i in range(0, len(docs), BATCH_SIZE):
        batch = docs[i:i + BATCH_SIZE]
        ids   = [d["id"] for d in batch]
        texts = [d["content"] for d in batch]

        print(f"  Batch {i//BATCH_SIZE + 1}: docs {i+1}–{i+len(batch)}...")

        try:
            embeddings = get_embedding(texts)
        except Exception as e:
            print(f"  ❌ Error generando embeddings: {e}")
            time.sleep(5)
            continue

        # 3. Actualizar cada documento con su embedding
        for doc_id, embedding in zip(ids, embeddings):
            supabase.table("documents").update({
                "embedding": embedding
            }).eq("id", doc_id).execute()

        total_procesados += len(batch)
        print(f"  ✅ {total_procesados}/{len(docs)} procesados")
        time.sleep(SLEEP_SECS)

    print(f"\n🎉 Completado. {total_procesados} documentos actualizados.")

if __name__ == "__main__":
    main()