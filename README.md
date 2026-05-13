# Friko Recomienda

Asistente conversacional con IA para recomendación de productos y recetas de **Friko** y **Antillana** (Grupo BIOS). Disponible como widget web y bot de Telegram.

**Web:** [frikorecomienda.netlify.app](https://frikorecomienda.netlify.app) · **Telegram:** [@friko_recomienda_bot](https://t.me/friko_recomienda_bot)

---

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | HTML/CSS/JS vanilla — deploy en Netlify |
| Chat widget | Flowise Embed SDK (CDN) |
| Bot Telegram | Telegram Bot API + n8n Cloud (22 nodos) |
| Motor RAG | Flowise Cloud (ChatflowV3) |
| Embeddings | OpenAI `text-embedding-3-small` |
| Vector store | Supabase pgvector (`documents` + RPC `match_documents`) |
| NLP extracción | Groq API (`gpt-4.1-mini`, temp 0) |
| Generación LLM | OpenAI via Flowise (`gpt-4.1-mini`, temp 0.55) |

---

## Cómo funciona

El asistente recopila 4 datos del usuario de forma conversacional — **región, personas, método de preparación y ocasión** — y con ellos lanza una búsqueda semántica en el catálogo de productos. El motor RAG aplica un scoring interno y entrega la recomendación con receta completa.

```
Usuario → [Web widget | Telegram bot]
              ↓
         Flowise RAG
    (embeddings + pgvector + LLM)
              ↓
     Recomendación + Receta
```

Para Telegram, n8n actúa como middleware: recibe el webhook, detecta comandos, llama a Flowise y formatea la respuesta en HTML para Telegram.

---

## Estructura del proyecto

```
friko_recomienta/
├── index.html              # Landing page + chat widget (Netlify)
├── netlify.toml            # Cabeceras de seguridad para Netlify
├── requirements.txt        # Dependencias Python
├── .env.example            # Template de variables de entorno
│
├── flows/
│   ├── flowise_chatflow.json   # Chatflow exportado de Flowise Cloud
│   └── n8n_workflow.json       # Workflow exportado de n8n Cloud
│
├── scripts/
│   ├── seed_documents.py       # Carga catálogo → genera embeddings → inserta en Supabase
│   ├── populate_embeddings.py  # Regenera embeddings para docs existentes sin embedding
│   └── db_schema.sql           # Schema de referencia (solo lectura, no ejecutar directo)
│
├── data/
│   ├── catalogo_productos.xlsx # Catálogo oficial Friko + Antillana
│   └── tabla_reglas.xlsx       # Reglas de negocio para el RAG
│
└── docs/
    ├── FrikoRAG_Documentacion_Tecnica.docx
    ├── Friko_Sistema_Completo_Doc_Tecnica.docx
    └── entregas/               # Entregables académicos por fase (fase0–fase4)
```

---

## Setup local

### Pre-requisitos

- Python 3.11+
- Cuenta activa en Supabase, Flowise Cloud, n8n Cloud y OpenAI

### Instalación

```bash
git clone https://github.com/<org>/friko-recomienta.git
cd friko-recomienta

python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# Edita .env con tus credenciales reales
```

### Variables de entorno

Copia `.env.example` a `.env` y completa los valores. Ver el archivo para descripción de cada variable.

| Variable | Descripción |
|---|---|
| `OPENAI_API_KEY` | API key de OpenAI |
| `SUPABASE_URL_DB` | URL del proyecto Supabase con los documentos |
| `SUPABASE_SERVICE_KEY_DB` | Service role key de ese proyecto |
| `FLOWISE_API_URL` | Endpoint de predicción del chatflow |
| `GROQ_API_KEY` | API key de Groq (usado en n8n) |

---

## Scripts principales

### Cargar catálogo y generar embeddings (setup inicial)

```bash
python scripts/seed_documents.py
```

Lee `data/catalogo_productos.xlsx`, genera embeddings con OpenAI y los inserta en la tabla `documents` de Supabase. Detecta si ya hay docs y pregunta antes de limpiar.

### Regenerar embeddings para docs existentes

```bash
python scripts/populate_embeddings.py
```

Útil si cambiaste el modelo de embeddings o si algunos docs quedaron sin embedding.

---

## Deploy

### Frontend (Netlify)

El archivo `index.html` se despliega directamente en Netlify. `netlify.toml` configura las cabeceras CSP necesarias para que el widget de Flowise funcione.

```bash
# Deploy manual vía Netlify CLI
npx netlify deploy --prod --dir .
```

### Motor RAG (Flowise)

1. En Flowise Cloud, ve a **Import Chatflow**.
2. Sube `flows/flowise_chatflow.json`.
3. Configura las credenciales (OpenAI, Supabase) en la UI de Flowise.
4. Copia el Chatflow ID y actualiza la variable en el widget de `index.html`.

### Bot Telegram (n8n)

1. En n8n Cloud, ve a **Import Workflow**.
2. Sube `flows/n8n_workflow.json`.
3. Configura las credenciales de Telegram y las variables de entorno en los nodos HTTP.
4. Activa el workflow.

---

## Cobertura regional

El sistema opera en **6 regiones de Colombia**: Antioquia, Atlántico, Bogotá, Eje Cafetero, Norte de Santander y Santander. Ciudades fuera de cobertura reciben una respuesta informativa.

---

*Proyecto desarrollado para Friko y Antillana — Grupo BIOS · Colombia*
