import json

# ================================================================
# FRIKO RAG - Flowise Chatflow V2
# Nodos:
#   1. groqChat_0         → Groq / Llama 3.3 70B
#   2. openAIEmbeddings_0 → OpenAI text-embedding-ada-002
#   3. supabase_0         → Supabase vector store (documents)
#   4. bufferMemory_0     → Buffer Memory (ventana 8 mensajes)
#   5. conversationalRetrievalQAChain_0 → Cadena principal
# ================================================================

SYSTEM_PROMPT = """Eres el asistente virtual de Friko, experto en productos cárnicos y recetas colombianas.
Tu misión es recomendar el producto Friko más adecuado y una receta personalizada según el contexto del usuario.

═══════════════════════════════════════════
REGLAS DE NEGOCIO (aplicar en este orden)
═══════════════════════════════════════════

REGLA 1 — REGIÓN (Dura, +50 puntos)
• SIEMPRE pregunta o confirma la región/ciudad del usuario.
• Regiones válidas: Antioquia, Atlántico, Bogotá, Eje Cafetero, Norte de Santander, Santander.
• Si el usuario menciona una CIUDAD, mapéala a su región usando tu conocimiento:
   - Medellín, Bello, Itagüí, Envigado → Antioquia
   - Barranquilla, Soledad → Atlántico  
   - Bogotá, Soacha, Chía → Bogotá
   - Pereira, Armenia, Manizales → Eje Cafetero
   - Cúcuta, Ocaña → Norte de Santander
   - Bucaramanga, Floridablanca, Girón → Santander
• Si la ciudad NO pertenece a ninguna región válida → informa claramente que no hay cobertura y TERMINA el flujo SIN recomendar producto ni receta.
• Solo evalúa productos disponibles en la región del usuario.

REGLA 2 — MÉTODO DE PREPARACIÓN (Compatibilidad, +25 puntos)
• El producto debe ser compatible con el método que el usuario tiene disponible.
• Métodos posibles: Horno, Airfryer, Sartén, Parrilla, Plancha, Wok, Salteado.
• Si el usuario no lo menciona, pregunta: "¿Cómo lo vas a preparar? Horno, parrilla, sartén u otro método?"

REGLA 3 — NÚMERO DE PERSONAS (Capacidad, +15 puntos)
• Verifica que el producto cubre el rango pers_min–pers_max del usuario.
• Si no lo menciona, pregunta: "¿Para cuántas personas estás preparando?"

REGLA 4 — OCASIÓN DE CONSUMO (Semántica, +10 puntos)  
• Analiza si el producto es adecuado para la ocasión (almuerzo familiar, fiesta, cena rápida, picnic, etc.).
• Si no lo menciona, puedes inferirlo del contexto o preguntar.

REGLA 5 — DIFERENCIADOR (Solo para el producto TOP)
• El producto más recomendado debe tener una razón diferenciadora clara y específica.

REGLA 6 — RECETA REAL FRIKO (RAG)
• Busca en el contexto recuperado si existe una receta real de momentosfriko.com asociada al producto.
• Si existe (metadata.tipo = "receta_real") → úsala como base.

REGLA 7 — RECETA GENERADA (Fallback)
• Si NO hay receta real → genera una receta colombiana completa usando el producto recomendado.
• Debe ser auténtica, paso a paso, con ingredientes locales.

REGLA 8 — TRANSPARENCIA
• Siempre indica si la receta es REAL (de momentosfriko.com) o GENERADA por el asistente.

═══════════════════════════════════════════
FLUJO CONVERSACIONAL
═══════════════════════════════════════════

PASO 1 — RECOLECCIÓN DE INFORMACIÓN
Antes de recomendar, necesitas confirmar:
✓ Región o ciudad
✓ Número de personas
✓ Método de preparación disponible
✓ Ocasión de consumo (opcional, enriquece la recomendación)

Si falta alguno, pregunta de forma conversacional y amigable (un dato a la vez).

PASO 2 — SCORING Y SELECCIÓN
Con el contexto recuperado, evalúa productos con la siguiente puntuación:
• +50 si está disponible en la región del usuario
• +25 si es compatible con el método indicado
• +15 si cubre el número de personas
• +10 si es apropiado para la ocasión
→ El producto con mayor puntaje es el recomendado. Menciona también 1-2 alternativas.

PASO 3 — FORMATO DE RESPUESTA
Presenta así:

🏆 PRODUCTO RECOMENDADO
**[Nombre del Producto]** — [Marca]
• 📍 Disponible en [Región]
• 👥 Rinde para [X] a [Y] personas
• 🍳 Ideal para: [métodos]
• ⭐ ¿Por qué este? [razón diferenciadora]

🔄 ALTERNATIVAS: [Producto 2], [Producto 3]

📖 RECETA: [Nombre de la receta]
⏱️ Tiempo: [X min] | 🍽️ Porciones: [N]

🛒 INGREDIENTES:
• [lista]

👨‍🍳 PREPARACIÓN:
1. [paso 1]
2. [paso 2]
...

💡 TIPS: [consejos opcionales]

---
[Si es receta real]: ✅ Receta oficial de momentosfriko.com
[Si es receta generada]: 🤖 Receta sugerida por el asistente

═══════════════════════════════════════════
RESTRICCIONES
═══════════════════════════════════════════
• Solo recomienda productos Friko o Antillana que aparezcan en el contexto recuperado.
• Si no hay productos para la región → informa sin inventar productos.
• Responde siempre en español colombiano, tono cálido y cercano.
• Usa los datos del contexto recuperado como fuente de verdad."""

QA_PROMPT = """Usa el siguiente contexto recuperado para responder la pregunta del usuario.
El contexto incluye información de PRODUCTOS Friko/Antillana y RECETAS colombianas.

CONTEXTO RECUPERADO:
{context}

PREGUNTA: {question}

Aplica todas las reglas de negocio del sistema. 
Si el contexto no tiene información suficiente sobre un producto en la región solicitada, informa que no hay disponibilidad en esa región."""

chatflow = {
    "nodes": [
        {
            "id": "groqChat_0",
            "position": {"x": 600, "y": -1780},
            "type": "customNode",
            "data": {
                "id": "groqChat_0",
                "label": "Groq - Llama 3.3 70B",
                "version": 4,
                "name": "groqChat",
                "type": "GroqChat",
                "baseClasses": ["GroqChat", "BaseChatModel", "BaseLanguageModel", "Runnable"],
                "category": "Chat Models",
                "description": "Groq API con Llama 3.3 70B - rápido y preciso para recomendaciones",
                "inputParams": [
                    {"label": "Connect Credential", "name": "credential", "type": "credential",
                     "credentialNames": ["groqApi"], "optional": True, "id": "groqChat_0-input-credential-credential"},
                    {"label": "Model Name", "name": "modelName", "type": "asyncOptions",
                     "loadMethod": "listModels", "id": "groqChat_0-input-modelName-asyncOptions"},
                    {"label": "Temperature", "name": "temperature", "type": "number",
                     "step": 0.1, "default": 0.3, "optional": True, "id": "groqChat_0-input-temperature-number"},
                    {"label": "Max Tokens", "name": "maxTokens", "type": "number",
                     "step": 1, "optional": True, "additionalParams": True, "id": "groqChat_0-input-maxTokens-number"},
                    {"label": "Streaming", "name": "streaming", "type": "boolean",
                     "default": True, "optional": True, "id": "groqChat_0-input-streaming-boolean"}
                ],
                "inputAnchors": [{"label": "Cache", "name": "cache", "type": "BaseCache",
                                   "optional": True, "id": "groqChat_0-input-cache-BaseCache"}],
                "inputs": {
                    "modelName": "llama-3.3-70b-versatile",
                    "temperature": "0.3",
                    "maxTokens": "3000",
                    "streaming": True
                },
                "outputAnchors": [{
                    "id": "groqChat_0-output-groqChat-GroqChat|BaseChatModel|BaseLanguageModel|Runnable",
                    "name": "groqChat",
                    "label": "GroqChat",
                    "type": "GroqChat | BaseChatModel | BaseLanguageModel | Runnable"
                }],
                "outputs": {},
                "selected": False
            },
            "width": 300,
            "height": 580,
            "selected": False,
            "dragging": False,
            "positionAbsolute": {"x": 600, "y": -1780}
        },
        {
            "id": "openAIEmbeddings_0",
            "position": {"x": -400, "y": -1730},
            "type": "customNode",
            "data": {
                "id": "openAIEmbeddings_0",
                "label": "OpenAI Embeddings - ada-002",
                "version": 4,
                "name": "openAIEmbeddings",
                "type": "OpenAIEmbeddings",
                "baseClasses": ["OpenAIEmbeddings", "Embeddings"],
                "category": "Embeddings",
                "description": "text-embedding-ada-002 (1536 dims) - mismo modelo usado al indexar",
                "inputParams": [
                    {"label": "Connect Credential", "name": "credential", "type": "credential",
                     "credentialNames": ["openAIApi"], "id": "openAIEmbeddings_0-input-credential-credential"},
                    {"label": "Model Name", "name": "modelName", "type": "asyncOptions",
                     "loadMethod": "listModels", "default": "text-embedding-ada-002",
                     "id": "openAIEmbeddings_0-input-modelName-asyncOptions"},
                    {"label": "Strip New Lines", "name": "stripNewLines", "type": "boolean",
                     "optional": True, "additionalParams": True, "id": "openAIEmbeddings_0-input-stripNewLines-boolean"},
                    {"label": "Batch Size", "name": "batchSize", "type": "number",
                     "optional": True, "additionalParams": True, "id": "openAIEmbeddings_0-input-batchSize-number"},
                    {"label": "Timeout", "name": "timeout", "type": "number",
                     "optional": True, "additionalParams": True, "id": "openAIEmbeddings_0-input-timeout-number"}
                ],
                "inputAnchors": [],
                "inputs": {
                    "modelName": "text-embedding-ada-002",
                    "stripNewLines": True,
                    "batchSize": 512,
                    "timeout": 60
                },
                "outputAnchors": [{
                    "id": "openAIEmbeddings_0-output-openAIEmbeddings-OpenAIEmbeddings|Embeddings",
                    "name": "openAIEmbeddings",
                    "label": "OpenAIEmbeddings",
                    "type": "OpenAIEmbeddings | Embeddings"
                }],
                "outputs": {},
                "selected": False
            },
            "width": 300,
            "height": 460,
            "selected": False,
            "dragging": False,
            "positionAbsolute": {"x": -400, "y": -1730}
        },
        {
            "id": "supabase_0",
            "position": {"x": 100, "y": -1730},
            "type": "customNode",
            "data": {
                "id": "supabase_0",
                "label": "Supabase - Vector Store (documents)",
                "version": 2,
                "name": "supabase",
                "type": "Supabase",
                "baseClasses": ["Supabase", "VectorStoreRetriever", "BaseRetriever"],
                "category": "Vector Stores",
                "description": "Vector store Supabase con tabla 'documents' (productos + recetas)",
                "inputParams": [
                    {"label": "Connect Credential", "name": "credential", "type": "credential",
                     "credentialNames": ["supabaseApi"], "id": "supabase_0-input-credential-credential"},
                    {"label": "Table Name", "name": "tableName", "type": "string",
                     "placeholder": "documents", "id": "supabase_0-input-tableName-string"},
                    {"label": "Query Name", "name": "queryName", "type": "string",
                     "placeholder": "match_documents", "id": "supabase_0-input-queryName-string"},
                    {"label": "Supabase URL", "name": "supabaseURL", "type": "string",
                     "id": "supabase_0-input-supabaseURL-string"},
                    {"label": "Top K", "name": "topK", "type": "number",
                     "default": 8, "optional": True, "additionalParams": True,
                     "id": "supabase_0-input-topK-number"},
                    {"label": "Metadata Filter", "name": "metadataFilter", "type": "json",
                     "optional": True, "additionalParams": True,
                     "id": "supabase_0-input-metadataFilter-json",
                     "description": "Filtrar por tipo/region. Ejemplo: {\"type\":\"producto\"}"}
                ],
                "inputAnchors": [
                    {"label": "Embeddings", "name": "embeddings", "type": "Embeddings",
                     "id": "supabase_0-input-embeddings-Embeddings"},
                    {"label": "Document", "name": "document", "type": "Document",
                     "list": True, "optional": True, "id": "supabase_0-input-document-Document"}
                ],
                "inputs": {
                    "tableName": "documents",
                    "queryName": "match_documents",
                    "supabaseURL": "{{SUPABASE_URL}}",
                    "topK": 8,
                    "embeddings": "{{openAIEmbeddings_0.data.instance}}"
                },
                "outputAnchors": [{
                    "id": "supabase_0-output-retriever-Supabase|VectorStoreRetriever|BaseRetriever",
                    "name": "retriever",
                    "label": "Supabase Retriever",
                    "type": "Supabase | VectorStoreRetriever | BaseRetriever"
                }],
                "outputs": {"output": "retriever"},
                "selected": False
            },
            "width": 300,
            "height": 680,
            "selected": False,
            "dragging": False,
            "positionAbsolute": {"x": 100, "y": -1730}
        },
        {
            "id": "bufferMemory_0",
            "position": {"x": 600, "y": -1050},
            "type": "customNode",
            "data": {
                "id": "bufferMemory_0",
                "label": "Buffer Memory (8 mensajes)",
                "version": 2,
                "name": "bufferMemory",
                "type": "BufferMemory",
                "baseClasses": ["BufferMemory", "BaseChatMemory", "BaseMemory"],
                "category": "Memory",
                "description": "Mantiene historial de conversación para contexto multi-turno",
                "inputParams": [
                    {"label": "Memory Key", "name": "memoryKey", "type": "string",
                     "default": "chat_history", "id": "bufferMemory_0-input-memoryKey-string"},
                    {"label": "Input Key", "name": "inputKey", "type": "string",
                     "default": "question", "id": "bufferMemory_0-input-inputKey-string"},
                    {"label": "Session Id", "name": "sessionId", "type": "string",
                     "description": "Separar sesiones por usuario. Dejar vacío para sesión global.",
                     "optional": True, "id": "bufferMemory_0-input-sessionId-string"},
                    {"label": "Session Timeouts (mins)", "name": "sessionTtl", "type": "number",
                     "default": 30, "optional": True, "additionalParams": True,
                     "id": "bufferMemory_0-input-sessionTtl-number"}
                ],
                "inputAnchors": [],
                "inputs": {
                    "memoryKey": "chat_history",
                    "inputKey": "question",
                    "sessionTtl": 30
                },
                "outputAnchors": [{
                    "id": "bufferMemory_0-output-bufferMemory-BufferMemory|BaseChatMemory|BaseMemory",
                    "name": "bufferMemory",
                    "label": "BufferMemory",
                    "type": "BufferMemory | BaseChatMemory | BaseMemory"
                }],
                "outputs": {},
                "selected": False
            },
            "width": 300,
            "height": 400,
            "selected": False,
            "dragging": False,
            "positionAbsolute": {"x": 600, "y": -1050}
        },
        {
            "id": "conversationalRetrievalQAChain_0",
            "position": {"x": 1050, "y": -1730},
            "type": "customNode",
            "data": {
                "id": "conversationalRetrievalQAChain_0",
                "label": "Conversational Retrieval QA Chain",
                "version": 3,
                "name": "conversationalRetrievalQAChain",
                "type": "ConversationalRetrievalQAChain",
                "baseClasses": ["ConversationalRetrievalQAChain", "BaseChain", "Runnable"],
                "category": "Chains",
                "description": "Cadena RAG conversacional con memoria y retrieval de productos/recetas Friko",
                "inputParams": [
                    {"label": "Return Source Documents", "name": "returnSourceDocuments",
                     "type": "boolean", "optional": True,
                     "id": "conversationalRetrievalQAChain_0-input-returnSourceDocuments-boolean"},
                    {"label": "Rephrase Prompt", "name": "rephrasePrompt", "type": "string",
                     "rows": 4, "default": "Dado el historial de conversación y la nueva pregunta del usuario, formula una pregunta independiente que capture toda la información necesaria para buscar productos o recetas Friko (región, personas, método, ocasión). Historial: {chat_history}\\nPregunta actual: {question}\\nPregunta reformulada:",
                     "id": "conversationalRetrievalQAChain_0-input-rephrasePrompt-string"},
                    {"label": "System Prompt", "name": "systemMessagePrompt",
                     "type": "string", "rows": 20,
                     "id": "conversationalRetrievalQAChain_0-input-systemMessagePrompt-string"},
                    {"label": "QA Chain Prompt", "name": "qaChainPrompt",
                     "type": "string", "rows": 10,
                     "id": "conversationalRetrievalQAChain_0-input-qaChainPrompt-string"}
                ],
                "inputAnchors": [
                    {"label": "Chat Model", "name": "model", "type": "BaseChatModel",
                     "id": "conversationalRetrievalQAChain_0-input-model-BaseChatModel"},
                    {"label": "Vector Store Retriever", "name": "vectorStoreRetriever",
                     "type": "BaseRetriever",
                     "id": "conversationalRetrievalQAChain_0-input-vectorStoreRetriever-BaseRetriever"},
                    {"label": "Memory", "name": "memory", "type": "BaseMemory",
                     "optional": True,
                     "id": "conversationalRetrievalQAChain_0-input-memory-BaseMemory"}
                ],
                "inputs": {
                    "model": "{{groqChat_0.data.instance}}",
                    "vectorStoreRetriever": "{{supabase_0.data.instance}}",
                    "memory": "{{bufferMemory_0.data.instance}}",
                    "returnSourceDocuments": False,
                    "rephrasePrompt": "Dado el historial de conversación y la nueva pregunta, reformula una consulta de búsqueda completa que incluya: región/ciudad del usuario, número de personas, método de preparación, y ocasión de consumo si están disponibles en el historial. Si es el primer mensaje, usa la pregunta tal cual.\n\nHistorial de conversación:\n{chat_history}\n\nPregunta actual del usuario:\n{question}\n\nConsulta de búsqueda optimizada:",
                    "systemMessagePrompt": SYSTEM_PROMPT,
                    "qaChainPrompt": QA_PROMPT
                },
                "outputAnchors": [{
                    "id": "conversationalRetrievalQAChain_0-output-conversationalRetrievalQAChain-ConversationalRetrievalQAChain|BaseChain|Runnable",
                    "name": "conversationalRetrievalQAChain",
                    "label": "ConversationalRetrievalQAChain",
                    "type": "ConversationalRetrievalQAChain | BaseChain | Runnable"
                }],
                "outputs": {},
                "selected": False
            },
            "width": 300,
            "height": 900,
            "selected": False,
            "dragging": False,
            "positionAbsolute": {"x": 1050, "y": -1730}
        }
    ],
    "edges": [
        {
            "source": "openAIEmbeddings_0",
            "sourceHandle": "openAIEmbeddings_0-output-openAIEmbeddings-OpenAIEmbeddings|Embeddings",
            "target": "supabase_0",
            "targetHandle": "supabase_0-input-embeddings-Embeddings",
            "type": "buttonedge",
            "id": "openAIEmbeddings_0-supabase_0"
        },
        {
            "source": "supabase_0",
            "sourceHandle": "supabase_0-output-retriever-Supabase|VectorStoreRetriever|BaseRetriever",
            "target": "conversationalRetrievalQAChain_0",
            "targetHandle": "conversationalRetrievalQAChain_0-input-vectorStoreRetriever-BaseRetriever",
            "type": "buttonedge",
            "id": "supabase_0-conversationalRetrievalQAChain_0"
        },
        {
            "source": "groqChat_0",
            "sourceHandle": "groqChat_0-output-groqChat-GroqChat|BaseChatModel|BaseLanguageModel|Runnable",
            "target": "conversationalRetrievalQAChain_0",
            "targetHandle": "conversationalRetrievalQAChain_0-input-model-BaseChatModel",
            "type": "buttonedge",
            "id": "groqChat_0-conversationalRetrievalQAChain_0"
        },
        {
            "source": "bufferMemory_0",
            "sourceHandle": "bufferMemory_0-output-bufferMemory-BufferMemory|BaseChatMemory|BaseMemory",
            "target": "conversationalRetrievalQAChain_0",
            "targetHandle": "conversationalRetrievalQAChain_0-input-memory-BaseMemory",
            "type": "buttonedge",
            "id": "bufferMemory_0-conversationalRetrievalQAChain_0"
        }
    ]
}

output_path = '/home/claude/friko_solution/flowise/FrikoRAGPipeline_ChatflowV2.json'
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(chatflow, f, ensure_ascii=False, indent=2)

print(f"Flowise JSON V2 generado: {output_path}")
print(f"  Nodos: {len(chatflow['nodes'])}")
print(f"  Edges: {len(chatflow['edges'])}")
