# 📚 DOCUMENTACIÓN TÉCNICA — FRIKO RAG SYSTEM V2

> Sistema conversacional de recomendación de productos y recetas para Friko/Antillana
> Stack: Supabase + pgvector · Flowise · Groq (Llama 3.3 70B) · OpenAI Embeddings

---

## 1. DISEÑO DE ARQUITECTURA

### Diagrama lógico del sistema

```
Usuario (Telegram / Web)
        │
        ▼
┌─────────────────────────┐
│   Flowise API Endpoint  │  ← Punto de entrada del chatbot
│  (chat/conversational)  │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│         ConversationalRetrievalQAChain                       │
│                                                              │
│  ┌─────────────────┐    ┌──────────────────────────────┐    │
│  │  Buffer Memory  │    │     Rephrase Prompt          │    │
│  │  (8 mensajes)   │───▶│  (contexto multi-turno)      │    │
│  └─────────────────┘    └──────────┬───────────────────┘    │
│                                    │                         │
│                          ┌─────────▼──────────┐             │
│                          │  OpenAI Embeddings  │             │
│                          │  (ada-002, 1536d)   │             │
│                          └─────────┬──────────┘             │
│                                    │                         │
│                          ┌─────────▼──────────┐             │
│                          │  Supabase pgvector  │             │
│                          │   tabla: documents   │             │
│                          │  (productos+recetas)│             │
│                          │   TOP-K = 8         │             │
│                          └─────────┬──────────┘             │
│                                    │ contexto recuperado     │
│                          ┌─────────▼──────────┐             │
│                          │  System Prompt V2   │             │
│                          │  (8 reglas negocio) │             │
│                          └─────────┬──────────┘             │
│                                    │                         │
│                          ┌─────────▼──────────┐             │
│                          │  Groq / Llama 3.3   │             │
│                          │    70B (T=0.3)       │             │
│                          └─────────┬──────────┘             │
└────────────────────────────────────┼────────────────────────┘
                                     │
                                     ▼
                            Respuesta al usuario
                   (Producto recomendado + Receta + Tips)
```

### Arquitectura de base de datos

```
regiones (6) ←──────── ciudades (N)
     │
     └──────────────── productos (55)
                            │
categorias (6) ─────────────┘
                            │
                producto_receta (N:M)
                            │
                       recetas (200)
                            │
                            ▼
                       documents ◄── Vector Store Flowise
                     (productos + recetas embeddados)
```

---

## 2. BASE DE DATOS (SUPABASE)

### Tablas y su rol

| Tabla | Filas | Propósito |
|-------|-------|-----------|
| `regiones` | 6 | Regiones de cobertura válidas |
| ~~ciudades~~ | — | **Eliminada.** El LLM valida ciudad → región con conocimiento geográfico embebido en el system prompt |
| `categorias` | 6 | Clasificación de productos |
| `productos` | 55 | Catálogo Friko/Antillana con todos sus atributos |
| `recetas` | 200 | Recetas reales de momentosfriko.com |
| `producto_receta` | N:M | Asociación producto ↔ receta |
| `documents` | ~255 | Vector store unificado para Flowise (productos + recetas) |
| `bot_sessions` | dinámica | Estado conversacional por usuario |

### Columna `contenido_semantico` en `productos`

```
"Producto Friko: Alitas BBQ. Marca: FRIKO. Descripción: Alitas marinadas BBQ.
Categoría: Pollo. Región disponible: Antioquia. Gramaje: 900g.
Rinde para 4 a 6 personas. Métodos de preparación: Horno, Airfryer."
```

Este texto concatenado es el que se embeddea. Incluye todos los campos relevantes para que la búsqueda semántica funcione incluso con queries naturales del usuario como "algo para hacer al horno para 5 personas en Medellín".

### Metadata en `documents`

```jsonc
// Para productos:
{
  "type": "producto",
  "sku": "FRIK-001",
  "nombre": "Alitas BBQ",
  "marca": "FRIKO",
  "region": "Antioquia",
  "categoria": "Pollo",
  "pers_min": 4,
  "pers_max": 6,
  "metodos": ["Horno", "Airfryer"],
  "tiene_receta_real": true,
  "score_base": 50
}

// Para recetas:
{
  "type": "receta",
  "receta_id": 12,
  "titulo": "Alitas BBQ al horno con miel",
  "url": "https://momentosfriko.com/...",
  "tipo_receta": "receta_real",
  "productos_mencionados": ["alitas"]
}
```

### ¿Cómo soporta el RAG?

1. **Búsqueda semántica**: La función `match_documents()` hace búsqueda coseno sobre los embeddings
2. **Filtrado por metadata**: Se puede filtrar `{"type": "producto", "region": "Antioquia"}` directamente
3. **Recuperación combinada**: Con `topK=8`, se recuperan ~4 productos + ~4 recetas relevantes en una sola consulta
4. **El LLM hace el scoring**: Con el contexto recuperado + el system prompt, Llama 3.3 aplica las 8 reglas

---

## 3. CONFIGURACIÓN DEL RAG (FLOWISE)

### Flujo de la cadena

```
1. Usuario envía mensaje
         │
2. Buffer Memory recupera historial (últimos 8 mensajes)
         │
3. Rephrase Prompt reformula la query incluyendo:
   - región detectada en el historial
   - personas mencionadas
   - método de preparación
   - ocasión de consumo
         │
4. OpenAI Embeddings convierte la query reformulada → vector (1536d)
         │
5. Supabase pgvector hace búsqueda coseno → top 8 documentos
   (mezcla de productos + recetas más relevantes)
         │
6. System Prompt V2 + contexto recuperado + historial → prompt final
         │
7. Groq Llama 3.3 70B genera respuesta estructurada aplicando las 8 reglas
         │
8. Respuesta entregada al usuario
```

### Nodos del chatflow

| Nodo | Tipo | Parámetros clave |
|------|------|-----------------|
| `groqChat_0` | GroqChat | Llama 3.3 70B, T=0.3, maxTokens=3000 |
| `openAIEmbeddings_0` | OpenAIEmbeddings | ada-002, 1536 dims |
| `supabase_0` | Supabase VectorStore | tabla=documents, func=match_documents, topK=8 |
| `bufferMemory_0` | BufferMemory | memoryKey=chat_history, TTL=30min |
| `conversationalRetrievalQAChain_0` | ConvRetrievalQA | System prompt V2 con 8 reglas |

### Por qué Temperature = 0.3

- **Alto** (>0.7): respuestas creativas pero inconsistentes en datos de productos
- **Bajo** (0.3): respuestas fieles al catálogo, estructuradas, con scoring coherente
- Las recetas sí necesitan algo de variación → 0.3 es el balance óptimo

---

## 4. LÓGICA DE VALIDACIÓN

### Captura de inputs obligatorios

El sistema valida 4 inputs en orden de prioridad:

```
1. REGIÓN/CIUDAD (obligatorio)
   ├── Si es región válida → OK, filtrar catálogo
   ├── Si es ciudad → mapear a región vía tabla ciudades
   └── Si ciudad desconocida → "Lo siento, no tenemos cobertura en [ciudad]. 
       Nuestros productos están disponibles en: Antioquia, Atlántico, Bogotá, 
       Eje Cafetero, Norte de Santander y Santander." → TERMINAR FLUJO

2. NÚMERO DE PERSONAS (obligatorio para Regla 3)
   └── Si no indicado → "¿Para cuántas personas estás preparando?"

3. MÉTODO DE PREPARACIÓN (obligatorio para Regla 2)
   └── Si no indicado → "¿Cómo lo vas a preparar? ¿Horno, parrilla, sartén...?"

4. OCASIÓN (opcional, enriquece Regla 4)
   └── Si no indicado → el sistema puede inferir del contexto o preguntar
```

### Lógica de ciudad → región

El LLM recibe en su system prompt un mapa explícito ciudad → departamento → región válida.
Cuando el usuario menciona una ciudad:
1. El LLM aplica su conocimiento geográfico para identificar el departamento.
2. Verifica si ese departamento corresponde a una de las 6 regiones con cobertura.
3. Si hay cobertura → extrae la región y filtra el catálogo de productos.
4. Si NO hay cobertura → responde con el mensaje de sin cobertura y **termina el flujo**.
5. Si la ciudad es ambigua → pregunta por el departamento antes de continuar.

No se requiere ninguna consulta a la base de datos para esta validación.

### Manejo de inputs incompletos

El sistema pregunta de forma conversacional, **de a un dato a la vez**:

```
Usuario: "Quiero algo para cocinar"
Bot: "¡Claro! 😊 Para recomendarte el producto perfecto, ¿en qué ciudad o región estás?"

Usuario: "Estoy en Bucaramanga"
Bot: "¡Perfecto! Bucaramanga está en Santander. ¿Para cuántas personas vas a cocinar?"

Usuario: "Para 5"
Bot: "¿Cómo lo vas a preparar? ¿Tienes horno, parrilla, sartén...?"

Usuario: "En sartén"
Bot: [Ahora aplica todas las reglas y recomienda]
```

---

## 5. TABLA DE SCORING (Reglas 1-4)

```
PRODUCTO: Nuggets de pollo FRIKO — Bogotá
Consulta: "Bogotá, 2 personas, horno, merienda"

Regla 1 - Región Bogotá ✅           → +50
Regla 2 - Compatible con Horno ✅    → +25
Regla 3 - Cubre 2 personas (2-3) ✅  → +15
Regla 4 - Adecuado para merienda ✅  → +10
                              TOTAL  = 100 ⭐⭐⭐⭐

vs.

PRODUCTO: Lomitos de pechuga FRIKO — Bogotá
Regla 1 - Región Bogotá ✅           → +50
Regla 2 - Sartén/Wok (no horno) ❌   → +0
Regla 3 - Requiere 10-13 personas ❌ → +0
Regla 4 - Puede servir para merienda → +10
                              TOTAL  = 60

→ Recomendado: Nuggets de pollo (100 puntos)
→ Alternativa: Mini chuzos o Bombones BBQ
```

---

## 6. DESPLIEGUE PASO A PASO

### Prerrequisitos

| Servicio | Tier gratuito | Notas |
|----------|--------------|-------|
| Supabase | ✅ Free tier | 500MB, pgvector incluido |
| Flowise | ✅ Self-hosted | Docker o Railway |
| Groq | ✅ Free tier | 14,400 req/día, muy rápido |
| OpenAI | 💲 Paid | Solo para embeddings (~$0.001/1000 tokens) |

### Paso 1: Configurar Supabase

```bash
# 1.1 Crear proyecto en supabase.com
# 1.2 En el SQL Editor, ejecutar en orden:

-- Ejecutar: sql/01_schema_v2.sql
-- Ejecutar: sql/02_seed_data.sql
-- Ejecutar: sql/03_seed_recetas.sql
-- Ejecutar: sql/04_populate_documents.sql (sin embeddings aún)
```

### Paso 2: Generar embeddings

```bash
# Instalar dependencias
pip install openai supabase python-dotenv

# Crear archivo .env
cat > .env << EOF
OPENAI_API_KEY=sk-...
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJ...
EOF

# Ejecutar script de embeddings
python docs/populate_embeddings.py
# Tiempo estimado: ~3-5 minutos para 255 documentos
# Costo estimado: < $0.01 USD
```

### Paso 3: Configurar Flowise

```bash
# Opción A: Docker (recomendado para producción)
docker run -d \
  -p 3000:3000 \
  -v flowise_data:/root/.flowise \
  --name flowise \
  flowiseai/flowise

# Opción B: npm local
npx flowise start --PORT=3000

# Opción C: Railway.app (sin servidor)
# Fork el repo de Flowise y deploya en Railway
```

### Paso 4: Importar chatflow en Flowise

```
1. Abrir http://localhost:3000
2. Ir a "Chatflows"
3. Clic en botón "+" o "Import"
4. Subir: flowise/FrikoRAGPipeline_ChatflowV2.json
5. Configurar credenciales:
   - Groq API Key (groqApi)
   - OpenAI API Key (openAIApi)
   - Supabase URL + Service Key (supabaseApi)
6. Guardar el chatflow
7. Hacer clic en el botón "Share" para obtener el Embed ID
```

### Paso 5: Conectar con Telegram (opcional)

```
1. Crear bot en @BotFather → obtener TOKEN
2. En Flowise: Settings → Chatbots → Telegram
3. Ingresar Token y configurar webhook
4. O usar n8n con el nodo Telegram + HTTP Request a Flowise API
```

### Variables de entorno para producción

```env
# Flowise
FLOWISE_USERNAME=admin
FLOWISE_PASSWORD=tu_password_seguro
PORT=3000
CORS_ORIGINS=https://tudominio.com

# Supabase (en Flowise Credentials)
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGci...

# APIs (en Flowise Credentials)
OPENAI_API_KEY=sk-...
GROQ_API_KEY=gsk_...
```

---

## 7. BUENAS PRÁCTICAS

### Escalabilidad

- **Índice IVFFlat**: Configurado con `lists=100` en `documents`. Para >1M documentos, aumentar a `lists=1000`.
- **Batch embeddings**: El script usa batches de 50 para respetar rate limits de OpenAI.
- **TTL en sesiones**: Las `bot_sessions` expiran en 30 min. Añadir un job periódico de limpieza:
  ```sql
  DELETE FROM public.bot_sessions WHERE expires_at < now();
  ```
- **Caché de embeddings**: Flowise soporta InMemory Cache. Activarlo para queries repetidas.

### Seguridad

- Usar `SUPABASE_SERVICE_KEY` solo en el backend (Flowise server-side). NUNCA en el frontend.
- Habilitar Row Level Security (RLS) en Supabase para `documents` si hay múltiples clientes.
- Rotar API keys cada 90 días.

### Monitoreo

```sql
-- Consultas lentas en vector store
SELECT pid, query, state, query_start 
FROM pg_stat_activity 
WHERE state = 'active' AND query LIKE '%embedding%';

-- Distribución de documentos
SELECT metadata->>'type' AS tipo, COUNT(*) 
FROM documents GROUP BY 1;

-- Sesiones activas
SELECT COUNT(*) FROM bot_sessions WHERE expires_at > now();
```

---

## 8. POSIBLES MEJORAS (Roadmap)

### Corto plazo
- [ ] **RLS por empresa**: Si se añaden más marcas, usar Row Level Security con `tenant_id`
- [ ] **Evaluación de respuestas**: Tabla `feedback` para guardar rating del usuario (👍/👎)
- [ ] **Sincronización automática**: Webhook desde el CMS de Friko que actualiza `productos` + regenera embeddings

### Mediano plazo
- [ ] **Filtrado dinámico por región en Flowise**: Pasar el `session_id` del usuario al retriever para aplicar filtro de región automáticamente
- [ ] **Segunda cadena para recetas**: Retriever separado solo para recetas con filtro por `metadata.productos_mencionados`
- [ ] **A/B testing de prompts**: Guardar variante de prompt usada en `bot_sessions` para medir conversión

### Largo plazo
- [ ] **Fine-tuning del modelo**: Con datos de conversaciones exitosas, afinar un modelo más pequeño
- [ ] **Multi-idioma**: Soporte para inglés para distribución en el Caribe
- [ ] **Análisis de popularidad**: Tabla de clicks/consultas por producto para ordenar alternativas

---

## 9. EJEMPLO DE EJECUCIÓN REAL

```
Usuario: Hola, quiero cocinar algo rico para esta noche

Bot: ¡Hola! 👋 Con gusto te ayudo a encontrar el producto Friko perfecto.
     ¿En qué ciudad o región estás?

Usuario: Estoy en Pereira

Bot: ¡Excelente! Pereira está en el Eje Cafetero. 
     ¿Para cuántas personas vas a cocinar esta noche?

Usuario: Para 4 personas

Bot: Perfecto. ¿Cómo lo vas a preparar? 
     ¿Tienes horno, parrilla, sartén u otro método disponible?

Usuario: En el horno

Bot: Una última pregunta: ¿es una cena informal, una reunión especial 
     o algo más rápido?

Usuario: Es una cena informal con familia

Bot: 🏆 PRODUCTO RECOMENDADO
     ──────────────────────
     **Alitas Picantes FRIKO**
     • 📍 Disponible en Eje Cafetero
     • 👥 Rinde para 4 a 6 personas — ideal para tu grupo
     • 🍳 Perfecto para: Horno, Airfryer
     • ⭐ ¿Por qué este? Las alitas marinadas picantes son perfectas 
       para una cena informal con familia: se preparan solas en el horno, 
       liberan tiempo para compartir, y el sabor picante las convierte 
       en el centro de la mesa.

     🔄 ALTERNATIVAS: Bombones BBQ (para quienes prefieren menos picante),
        Mini chuzos FRIKO (opción más pequeña para acompañar)

     ──────────────────────
     📖 RECETA: Alitas Picantes al Horno con Miel y Limón
     ⏱️ Tiempo: 40 min | 🍽️ Porciones: 4 personas

     🛒 INGREDIENTES:
     • 1 paquete Alitas Picantes FRIKO (900g)
     • 3 cucharadas de miel
     • Jugo de 1 limón
     • 2 dientes de ajo machacado
     • 1 cucharadita de paprika
     • Sal y pimienta al gusto
     • Aceite de oliva

     👨‍🍳 PREPARACIÓN:
     1. Precalienta el horno a 200°C.
     2. En un bowl, mezcla la miel, el jugo de limón, el ajo, 
        la paprika, sal y pimienta.
     3. Cubre las alitas con la mezcla y deja marinar 10 minutos.
     4. Coloca en una bandeja con papel aluminio y hornea 25 minutos.
     5. Voltea las alitas y hornea 10 minutos más hasta dorar.
     6. Sirve con hogao o ají al gusto.

     💡 TIP: Si quieres que queden más crocantes, los últimos 5 minutos
        activa el grill del horno.

     ──────────────────────
     🤖 Receta sugerida por el asistente Friko
     ¿Te gustaría ver más opciones o ajustar la receta?
```

---

## 10. ARQUITECTURA DE ARCHIVOS ENTREGADOS

```
friko_solution/
├── sql/
│   ├── 01_schema_v2.sql          ← Crear tablas, índices, funciones
│   ├── 02_seed_data.sql          ← Regiones, ciudades, categorías, productos (55)
│   ├── 03_seed_recetas.sql       ← Recetas reales (200)
│   └── 04_populate_documents.sql ← Vector store documents (sin embeddings)
├── flowise/
│   └── FrikoRAGPipeline_ChatflowV2.json ← Importar en Flowise directamente
└── docs/
    ├── populate_embeddings.py    ← Genera embeddings OpenAI para documents
    └── DOCUMENTACION_TECNICA.md  ← Este archivo
```
