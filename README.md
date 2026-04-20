# 📚 Friko Recomienda v2 — Documentación Completa
> Sistema de recomendación de productos y recetas colombianas con IA

---

## 🏗️ ARQUITECTURA COMPLETA

```
┌─────────────────────────────────────────────────────────────────┐
│  USUARIO (Web / Telegram)                                        │
│  "Hola, estoy en Medellín, somos 6, tengo airfryer, es almuerzo" │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  FLOWISE CLOUD                                                   │
│                                                                  │
│  ┌──────────────┐   rephrasePrompt   ┌─────────────────────┐   │
│  │  Buffer      │◄──[{chat_history}]─│                     │   │
│  │  Memory      │   [{question}]     │  Conversational     │   │
│  └──────────────┘                   │  Retrieval QA Chain  │   │
│                                     │                      │   │
│  ┌──────────────┐  responsePrompt   │                      │   │
│  │  Groq        │◄──[{context}]─────│                      │   │
│  │  LLaMA 3.3   │                   └──────────────────────┘   │
│  │  70B         │                             ▲                 │
│  └──────────────┘                             │                 │
│                                               │ retriever       │
│  ┌──────────────┐  embedding query            │                 │
│  │  OpenAI      │──────────────────►┌─────────────────────┐   │
│  │  Embeddings  │                   │  Supabase Vector     │   │
│  │  (3-small)   │                   │  Store               │   │
│  └──────────────┘                   │  topK=10             │   │
│                                     └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                           │ match_documents RPC
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  SUPABASE (PostgreSQL + pgvector)                               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  public.documents                                        │  │
│  │  content: "Producto: Chuzos de contramuslo (FRIKO)..."  │  │
│  │  embedding: vector(1536)  [HNSW index]                  │  │
│  │  metadata: {sku, region, marca, pers_min, pers_max, ...}│  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  public.productos  public.recetas  public.categorias    │  │
│  │  public.regiones   public.producto_receta               │  │
│  │  public.bot_sessions                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 COMPONENTES DEL SISTEMA

### 1. Supabase (Base de datos + Vector Store)
**Qué hace:** Almacena el catálogo de productos, recetas y los vectores semánticos para búsqueda por similaridad.

**Tablas clave:**
- `documents` — Tabla principal del RAG. Cada producto tiene un documento con su contenido semántico enriquecido y su embedding vectorial.
- `productos` — Catálogo estructurado con región, método, personas min/max.
- `recetas` — Recetas oficiales de momentosfriko.com.
- `producto_receta` — Relación muchos-a-muchos entre productos y recetas.
- `bot_sessions` — Sesiones de Telegram para contexto conversacional.

**Función RPC crítica:**
```sql
match_documents(query_embedding, match_count, filter)
```
Esta es la función que llama Flowise para buscar documentos similares. Sin ella el RAG no funciona.

---

### 2. OpenAI Embeddings (text-embedding-3-small)
**Qué hace:** Convierte el texto del usuario y el contenido de los documentos en vectores numéricos para permitir búsqueda semántica.

**⚠️ CRÍTICO:** El modelo de embedding usado para **poblar** la base de datos DEBE ser el mismo que usa Flowise para **consultar**. Ambos son `text-embedding-3-small`. Si cambias uno, debes re-embeddear todos los documentos.

---

### 3. Flowise Cloud (Orquestador del RAG)
**Qué hace:** Maneja el flujo conversacional completo:
1. Recibe el mensaje del usuario
2. Reformula la pregunta usando el historial (rephrasePrompt)
3. Hace búsqueda semántica en Supabase
4. Pasa el contexto recuperado al LLM
5. El LLM genera la respuesta final

**Archivos:** `FrikoRAGPipeline_ChatflowV2.json`

---

### 4. Groq / LLaMA 3.3 70B (LLM)
**Qué hace:** Genera las respuestas del chatbot. Analiza el contexto de productos recuperado y produce:
- Validación de región
- Scoring interno de productos
- Recomendación con justificación
- Receta completa (oficial o generada)

**Modelo:** `llama-3.3-70b-versatile`
**Temperature:** 0.55 (equilibrio entre creatividad para recetas y precisión para datos)

---

### 5. Landing Page
**Qué hace:** Interfaz web que:
- Muestra el consent modal de datos personales
- Explica al usuario qué hace el bot y qué esperar
- Carga el widget de Flowise después del consent
- Incluye la sección legal permanente

**Archivo:** `friko_recomienda_landing_v2.html`

---

## 🚀 GUÍA DE DESPLIEGUE PASO A PASO

### Paso 1: Configurar Supabase

```sql
-- 1.a Ejecuta schema_v2.sql en el SQL Editor de Supabase
-- Crea tablas, funciones RPC, índices HNSW y datos iniciales

-- 1.b Verifica que la extensión vector esté activa
SELECT * FROM pg_extension WHERE extname = 'vector';

-- 1.c Verifica la función match_documents
SELECT proname FROM pg_proc WHERE proname = 'match_documents';
```

### Paso 2: Poblar la tabla documents

```bash
# Instala dependencias
pip install openai supabase openpyxl

# Ejecuta el script de seed
export OPENAI_API_KEY="sk-..."
export SUPABASE_URL="https://xydwqnaljpgwqrlievwj.supabase.co"
export SUPABASE_KEY="tu-service-role-key"  # NO la anon key

python seed_documents.py
```

**Verificación:**
```sql
-- Debe retornar 99 filas
SELECT COUNT(*) FROM documents;

-- Verifica que los embeddings no son null
SELECT COUNT(*) FROM documents WHERE embedding IS NULL;
-- Debe ser 0
```

### Paso 3: Configurar Flowise

```bash
# Opción A: Flowise Cloud
# 1. Ve a https://cloud.flowiseai.com
# 2. Create → Import Chatflow
# 3. Sube FrikoRAGPipeline_ChatflowV2.json
# 4. Configura credenciales:
#    - Groq API Key (de console.groq.com)
#    - OpenAI API Key (de platform.openai.com)
#    - Supabase API (URL + anon key)

# Opción B: Flowise self-hosted
npm install -g flowise
flowise start --PORT=3000
# Luego importa el JSON desde la UI
```

### Paso 4: Verificar el chatbot en Flowise

Prueba estas consultas en el chat interno de Flowise:

1. `"Hola, estoy en Medellín"` → debe pedir más datos
2. `"Somos 5 personas"` → debe pedir método
3. `"Tengo airfryer"` → debe pedir ocasión
4. `"Es almuerzo familiar"` → debe recomendar producto con receta
5. `"Estoy en Cali"` → debe indicar sin cobertura y terminar

### Paso 5: Actualizar el chatflowid en la landing

En `friko_recomienda_landing_v2.html`, línea con `chatflowid`, reemplaza el UUID por el ID real de tu chatflow en Flowise Cloud:

```javascript
chatflowid: "TU-CHATFLOW-ID-REAL",
apiHost: "https://cloud.flowiseai.com",  // o tu URL self-hosted
```

### Paso 6: Deploy de la landing

La landing es un archivo HTML estático. Puedes hospedarla en:
- **Vercel:** `vercel --prod` o drag-and-drop en vercel.com
- **Netlify:** Drag-and-drop del archivo en netlify.com
- **Cloudflare Pages:** Git-connected o direct upload
- **Supabase Storage:** Como asset público con URL custom

---

## 🔧 CONFIGURACIÓN DE VARIABLES DE ENTORNO

| Variable | Dónde configurar | Valor |
|---|---|---|
| `OPENAI_API_KEY` | Flowise Credentials + seed_documents.py | `sk-...` |
| `GROQ_API_KEY` | Flowise Credentials | `gsk_...` |
| `SUPABASE_URL` | Flowise Credentials + seed_documents.py | `https://xxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Flowise Credentials | `eyJ...` (anon) |
| `SUPABASE_SERVICE_KEY` | seed_documents.py ÚNICAMENTE | `eyJ...` (service_role) |

**⚠️ NUNCA expongas la `service_role` key en el frontend.**

---

## 🧪 EJEMPLO REAL DE CONVERSACIÓN

```
Bot: ¡Hola! Soy Friko Recomienda 🍗
     Te ayudo a encontrar el producto Friko o Antillana perfecto y te doy la receta.
     ¿En qué región o ciudad estás?

User: Bucaramanga

Bot: Bucaramanga está en Santander ✅
     ¿Cuántas personas van a comer?

User: Somos 4

Bot: ¿Cómo prefieres preparar la comida?
     Sartén · Horno · Parrilla · Airfryer · Plancha · Wok · Salteado

User: Sartén, es una cena rápida

Bot: 🏆 **Mini chuzos** — Friko
     📍 Santander · 👥 2–3 personas · 🍳 Sartén, Airfryer
     _El más práctico para cena rápida entre semana — va directo al sartén sin descongelar._

     📖 **Mini chuzos en salsa de ajo y cilantro** · ⏱️ 20 min · 🍽️ 4 personas

     **Ingredientes:**
     - 2 paquetes Mini chuzos Friko (540g)
     - 3 dientes de ajo picado
     - 1/4 taza cilantro fresco
     - 2 cdas mantequilla
     - Sal y pimienta al gusto

     **Preparación:**
     1. Calienta el sartén a fuego medio-alto con la mantequilla.
     2. Agrega los mini chuzos congelados directo, cocina 5 min por lado.
     3. Añade el ajo picado y sofríe 2 min hasta dorar.
     4. Finaliza con cilantro fresco y ajusta sal.
     5. Sirve inmediatamente con arroz blanco.

     💡 _Con 4 personas y 2 paquetes, calcular 2-3 chuzos por persona._
     🔄 Alternativa: **Nuggets de pollo Friko** si prefieres algo más clásico para los niños

     🤖 Receta sugerida por IA

     ---
     ¿Qué quieres hacer ahora?
     👉 1. Ver otra receta con este producto
     👉 2. Recomendar otro producto Friko
```

---

## ✅ CHECKLIST DE VALIDACIÓN ANTES DE PRODUCCIÓN

- [ ] `match_documents` RPC existe y retorna resultados en Supabase
- [ ] Índice HNSW creado en tabla `documents`
- [ ] `seed_documents.py` ejecutado con éxito (99 docs sin embedding null)
- [ ] Chatflow importado en Flowise con credenciales configuradas
- [ ] Prueba multi-turno: el chain no rompe en el 2do mensaje
- [ ] Prueba región inválida (Cali): bot responde correctamente y cierra
- [ ] Prueba ciudad desconocida: bot pregunta el departamento
- [ ] Prueba "sorpréndeme": bot recomienda sin pedir más datos (usa los ya dados)
- [ ] `chatflowid` real reemplazado en la landing
- [ ] Consent modal funciona y checkbox no tiene double-toggle bug
- [ ] Landing carga el chatbot SOLO después del consent

---

## 📊 CAMBIOS v1 → v2 (RESUMEN)

| Componente | Cambio | Razón |
|---|---|---|
| **rephrasePrompt** | Añadidos `{chat_history}` y `{question}` | BUG-01: chain roto en follow-ups |
| **SQL** | Añadida función `match_documents` | BUG-02: pgvector no funcionaba |
| **SQL** | Índices HNSW en columnas embedding | BUG-03: búsquedas O(n) |
| **Prompt** | Añadido "Salteado" a métodos válidos | BUG-04: ANTI-002 nunca se recomendaba |
| **Flowise topK** | 5 → 10 | BUG-06: perdía productos relevantes |
| **Flowise temp** | 0.3 → 0.55 | BUG-13: recetas repetitivas |
| **Landing** | Features falsas eliminadas y reemplazadas | BUG-07: inconsistencia promesa/realidad |
| **Landing** | Sección legal HTML añadida | BUG-08: CSS definido sin HTML |
| **Landing** | CTAs abren el chatbot | BUG-09: botón iba a demo estático |
| **Landing** | Double-toggle del checkbox corregido | BUG-10: checkbox no cambiaba |
| **Schema** | `Bogota` → `Bogotá` (con tilde) | BUG-12: filtros fallaban |
| **seed_documents.py** | Script de seed del catálogo | Nuevo: proceso de carga del RAG |
