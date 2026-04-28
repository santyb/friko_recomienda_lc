# 🍗 Friko Recomienda — README Técnico

> Asistente conversacional con IA para recomendación de productos y recetas de las marcas **Friko** y **Antillana** del Grupo BIOS, disponible en dos canales: web y Telegram.

**Link Landing Page:** [https://frikorecomienda.netlify.app](https://frikorecomienda.netlify.app)

**Bot de Telegram:** [@friko_recomienda_bot](https://t.me/friko_recomienda_bot)

---
 
## Índice
 
1. [Descripción general](#1-descripción-general)
2. [Arquitectura del sistema](#2-arquitectura-del-sistema)
3. [Stack tecnológico](#3-stack-tecnológico)
4. [Componentes y repositorios](#4-componentes-y-repositorios)
5. [Requisitos previos](#5-requisitos-previos)
6. [Cómo acceder al sistema](#6-cómo-acceder-al-sistema)
7. [Uso del sistema](#7-uso-del-sistema)
8. [Flujo de datos](#8-flujo-de-datos)
9. [Comportamiento y límites del sistema](#9-comportamiento-y-límites-del-sistema)
10. [Preguntas frecuentes](#10-preguntas-frecuentes)
---

## 1. Descripción general

**Friko Recomienda** es un sistema de inteligencia artificial conversacional que guía al usuario en la elección del producto Friko o Antillana ideal y le entrega la receta completa para prepararlo.

El sistema recopila **4 datos del usuario** de forma conversacional:

| Dato | Descripción | Ejemplo |
|---|---|---|
| Región o ciudad | Determina qué productos están disponibles | Medellín → Antioquia |
| Número de personas | Valida el rendimiento del producto | 4 personas |
| Método de preparación | Filtra por técnica de cocción | Airfryer |
| Ocasión | Adapta la recomendación al contexto | Cena rápida |

Con esos 4 datos, el motor RAG busca semánticamente en el catálogo de productos, aplica un scoring interno y entrega la recomendación con receta.

**Canales disponibles:**

```
┌─────────────────────────────────────────────────┐
│  Canal Web   → frikorecomienda.netlify.app      │
│  Telegram    → @friko_recomienda_bot            │
│                                                 │
│  Ambos comparten el mismo motor RAG (Flowise)   │
└─────────────────────────────────────────────────┘
```

---

## 2. Arquitectura del sistema

```
┌──────────────────────────────────────────────────────────────────┐
│                        CANALES DE ENTRADA                        │
│                                                                  │
│   🌐 Landing Page (Netlify)        📱 Telegram Bot.               │
│   Flowise Embed SDK                n8n Workflow                  │
│   (HTML estático)                  (22 nodos)                    │
└────────────────┬────────────────────────┬────────────────────────┘
                 │                        │
                 │  HTTP POST             │  HTTP POST
                 │  Prediction API        │  + overrideConfig
                 │                        │  + sessionId
                 ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MOTOR RAG — Flowise Cloud                    │
│                                                                 │
│  ConversationalRetrievalQAChain                                 │
│  ┌─────────────┐  ┌──────────────────┐  ┌───────────────────┐   │
│  │ Rephrase    │  │ OpenAI Embeddings│  │  Supabase         │   │
│  │ Prompt      │→ │ text-embed-3-    │→ │  pgvector         │   │
│  │(openAI LLM) │  │ small            │  │  tabla: documents │   │
│  └─────────────┘  └──────────────────┘  │  topK: 10         │   │
│                                         └─────────┬─────────┘   │
│  ┌─────────────────────────────────────────────── ▼ ──────────┐ │
│  │  Response Prompt (openAI LLM)                              │ │
│  │  Scoring: +50 región · +25 método · +15 personas · +10 ocas│ │
│  │  Genera: producto recomendado + receta paso a paso         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                       Buffer Memory (chat_history)              │
└─────────────────────────────────────────────────────────────────┘

                    Componente exclusivo del canal Telegram:
┌──────────────────────────────────────────────────────────────────┐
│                    n8n — Gestión de Sesiones                     │
│  Telegram Trigger → Groq NLP → Supabase Sessions → Switch(6) →   │
│  [bienvenida | sin cobertura | rate limit | pedir campo |        │
│   confirmación | llamar RAG]                                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Stack tecnológico

| Capa | Tecnología | Detalle |
|---|---|---|
| **Frontend** | HTML / CSS / JS vanilla | Landing page estática |
| **Deploy web** | Netlify | `frikorecomienda.netlify.app` |
| **Chat web** | Flowise Embed SDK | `cdn.jsdelivr.net/npm/flowise-embed` |
| **Bot Telegram** | Telegram Bot API v6 | Webhook hacia n8n |
| **Orquestación bot** | n8n Cloud | Workflow de 22 nodos |
| **NLP extracción** | Groq API | `gpt-4.1-mini`, temp 0 |
| **Generación LLM** | OpenAI + Flowise | `gpt-4.1-mini`, temp 0.55 |
| **Embeddings** | OpenAI API | `text-embedding-3-small` |
| **Vector store** | Supabase pgvector | Tabla `documents`, RPC `match_documents` |
| **Sesiones bot** | Supabase REST | Tabla `bot_sessions`, TTL 30 min |
| **Motor RAG** | Flowise Cloud | ChatflowV3, `610c56f2-d7b9-43ea-8c48-b62f18570416` |

---

## 4. Componentes y repositorios

El sistema está compuesto por **3 artefactos desplegables**:

```
friko-recomienda/
│
├── 📄 index.html                    # Landing page completa (un solo archivo)
│   └── Deploy: Netlify
│
├── 🤖 FrikoRAGPipeline_ChatflowV3   # Motor RAG exportado desde Flowise
│   └── Deploy: Flowise Cloud
│   └── Archivo: FrikoRAGPipeline_ChatflowV3_Chatflow.json
│
└── ⚙️  Friko_Chef_Bot_v6            # Workflow del bot de Telegram
    └── Deploy: n8n Cloud
    └── Archivo: Friko_Chef_Bot_v6_Telegram_Groq_NLP_Supabase_Sessions_Flowise_RAG.json
```

---
 
## 5. Requisitos previos
 
Para usar el sistema no se requiere instalación ni registro. El acceso está disponible de forma inmediata a través de los dos canales:
 
| Canal | Requisito |
|---|---|
| **Web** | Navegador moderno con conexión a internet |
| **Telegram** | App de Telegram instalada (iOS, Android o escritorio) |
 
---

## 6. Cómo acceder al sistema
 
### Canal Web
 
Accede directamente desde el navegador:
 
**[https://frikorecomienda.netlify.app](https://frikorecomienda.netlify.app)**
 
1. Haz clic en **"Hablar en la web"** — el chat se abre como widget flotante en la misma página.
2. Escribe tu mensaje en el campo de texto y presiona enviar.
3. El asistente guiará la conversación solicitando los datos necesarios de a uno.
> No se requiere crear cuenta ni iniciar sesión.
 
### Canal Telegram
 
Accede desde cualquier dispositivo con Telegram instalado:
 
**[https://t.me/friko_recomienda_bot](https://t.me/friko_recomienda_bot)**
 
1. Abre el enlace o busca `@friko_recomienda_bot` en Telegram.
2. Presiona **Iniciar** o envía `/start` para comenzar.
3. Sigue el flujo conversacional — el bot pedirá un dato a la vez.
### Comparación de canales
 
| Aspecto | Web | Telegram |
|---|---|---|
| Acceso | Navegador, sin instalar | App Telegram instalada |
| Ideal para | Computador o tablet | Celular |
| Historial | Solo durante la sesión abierta | Guardado en tu app de Telegram |
| Iniciar de nuevo | Recargar la página | Enviar `/nuevo` |
 
---

## 7. Uso del sistema

### Canal Web

1. Abrir [https://frikorecomienda.netlify.app](https://frikorecomienda.netlify.app).
2. Hacer clic en **"Hablar en la web"** para abrir el widget de chat.
3. Escribir el mensaje — el asistente pedirá los 4 datos necesarios.

### Canal Telegram

1. Abrir [@friko_recomienda_bot](https://t.me/friko_recomienda_bot) en Telegram.
2. Enviar `/start` o `/nuevo` para iniciar una conversación.
3. Seguir el flujo conversacional guiado.

### Comandos disponibles en Telegram

| Comando | Acción |
|---|---|
| `/start` | Inicia o reinicia el asistente |
| `/nuevo` | Reinicia la sesión actual |
| `/reset` | Limpia todos los datos y vuelve al inicio |
| `/iniciar` | Alias de `/start` |
| `/reiniciar` | Alias de `/reset` |

### Ejemplo de conversación

```
Usuario:  "Medellín, somos 5, tengo sartén"

Bot:      Medellín → Antioquia ✅
          ¿Cuál es la ocasión?
          Almuerzo · Reunión familiar · Cena rápida · Picada · Asado

Usuario:  "Cena rápida entre semana"

Bot:      🏆 Filete de pechuga — Friko
          📍 Antioquia · 👥 4–6 personas · 🍳 Sartén, Plancha

          📖 Pechuga al limón con ajo y cilantro · ⏱️ 20 min · 🍽️ 5 porciones
          [receta completa paso a paso...]

          💡 Sazónala 10 min antes con limón para más sabor.
          🤖 Receta sugerida por IA
```

---

## 8. Flujo de datos

### Canal Web (simplificado)

```
Usuario escribe → Flowise Embed SDK → Prediction API → RAG → Respuesta
```

El widget de Flowise maneja el flujo completo internamente: rephrase, embeddings, búsqueda vectorial, scoring y generación.

### Canal Telegram (completo)

```
1. Usuario escribe en Telegram
2. Telegram → n8n webhook
3. n8n: Parse mensaje + construir body Groq
4. ¿Es comando? → Sí: skip Groq | No: Groq extrae 4 entidades (temp=0, json_object)
5. Supabase: recuperar sesión (TTL 30 min)
6. Merge State: normalizar región + rate limit + merge + calcular step
7. Supabase: guardar sesión actualizada
8. Switch(6 ramas):
   ├── welcome          → Mensaje de bienvenida
   ├── no_coverage      → Ciudad sin cobertura
   ├── rate_limited     → Límite de velocidad
   ├── ask_question     → Pedir campo faltante (con progreso)
   ├── show_confirmation→ Mostrar resumen para confirmar
   └── send_to_rag      →
        9. Telegram: sendChatAction = typing
       10. Build Flowise query + supabaseMetadataFilter{region}
       11. Flowise Prediction API (timeout 90s)
       12. Markdown → Telegram HTML
       13. Enviar respuesta
```

### Scoring interno del RAG

El LLM aplica el siguiente scoring a cada producto recuperado (nunca visible al usuario):

```
+50  Región del producto coincide con la del usuario
+25  El método de preparación solicitado está disponible
+15  El número de personas está dentro del rango del producto
+10  La categoría del producto es adecuada para la ocasión
────
100  Puntaje máximo posible
```

---
 
## 9. Comportamiento y límites del sistema
 
### Cobertura regional
 
El asistente opera en **6 regiones de Colombia**. Cuando el usuario menciona su ciudad, el sistema la mapea automáticamente a la región correspondiente. Si la ciudad no tiene cobertura, el bot lo informa de inmediato sin hacer una recomendación.
 
| Región | Ciudades principales |
|---|---|
| Antioquia | Medellín, Bello, Itagüí, Envigado, Rionegro |
| Atlántico | Barranquilla, Soledad, Malambo |
| Bogotá | Bogotá D.C., Soacha, Chía, Zipaquirá |
| Eje Cafetero | Pereira, Armenia, Manizales, Dosquebradas |
| Norte de Santander | Cúcuta, Villa del Rosario, Ocaña |
| Santander | Bucaramanga, Floridablanca, Girón, Piedecuesta |
 
### Sesiones en Telegram
 
La conversación en Telegram mantiene el progreso del usuario entre mensajes durante **30 minutos** de inactividad. Pasado ese tiempo, el bot comienza una sesión nueva. Para reiniciar manualmente en cualquier momento, basta con enviar `/nuevo`.
 
### Velocidad de respuesta
 
El asistente responde en segundos para preguntas de recolección de datos. La recomendación final (que consulta el catálogo completo y genera la receta) puede tardar hasta **30 segundos** dependiendo del estado del servicio.
 
### Correcciones durante la conversación
 
Si el usuario quiere cambiar un dato que ya proporcionó, puede indicarlo con expresiones como:
 
> *"en realidad estoy en Bogotá"*, *"mejor para 6 personas"*, *"cambia el método a horno"*
 
El asistente detecta la intención de corrección y actualiza el dato sin necesidad de reiniciar la conversación.
 
### Límite de velocidad (Telegram)
 
El bot acepta máximo **2 mensajes en 5 segundos** por usuario. Si se supera ese límite, responde con un aviso para esperar unos segundos antes de continuar.
 
---
 
## 10. Preguntas frecuentes
 
**¿Necesito crear una cuenta para usar el asistente?**
No. El acceso es inmediato tanto en la web como en Telegram, sin registro ni datos personales.
 
**¿Puedo pedir varios datos en un solo mensaje?**
Sí. Si escribes por ejemplo *"Medellín, somos 5, tengo airfryer"*, el asistente extrae los tres datos de una vez y solo pregunta lo que falte.
 
**¿Qué pasa si mi ciudad no tiene cobertura?**
El asistente te informa cuáles son las 6 regiones disponibles y te invita a intentar con otra ubicación o a visitar [momentosfriko.com](https://www.momentosfriko.com).
 
**¿Las recetas son oficiales de Friko?**
El asistente prioriza recetas oficiales de [momentosfriko.com](https://www.momentosfriko.com). Si no encuentra una receta oficial para el producto recomendado, genera una con IA e indica claramente el origen con el texto *🤖 Receta sugerida por IA*.
 
**¿Puedo pedir otra recomendación después de recibir una?**
Sí. Después de cada respuesta puedes escribir *"dame otra opción"* o *"quiero otra receta"* para recibir una alternativa diferente. También puedes iniciar una consulta completamente nueva con `/nuevo` en Telegram o recargando la página en la web.
 
**¿El asistente recuerda conversaciones anteriores?**
En Telegram, el historial se conserva visualmente en la app pero la sesión activa se reinicia tras 30 minutos de inactividad. En la web, el historial solo persiste mientras el widget de chat esté abierto en la misma pestaña del navegador.
 
---
*Proyecto desarrollado para Friko y Antillana — Grupo BIOS · Colombia 🇨🇴*
