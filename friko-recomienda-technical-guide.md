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

**Friko Recomienda** es un sistema de inteligencia artificial conversacional que guía al usuario colombiano en la elección del producto Friko o Antillana ideal y le entrega la receta completa para prepararlo.

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
│   🌐 Landing Page (Netlify)        📱 Telegram Bot                │
│   Flowise Embed SDK                n8n Workflow                  │
│   (HTML estático)                  (14 nodos)                    │
└────────────────┬────────────────────────┬────────────────────────┘
                 │                        │                        
                 │  Flowise Embed SDK     │  HTTP POST             
                 │  (directo)             │  Prediction API        
                 │                        │  + sessionId           
                 ▼                        ▼                        
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
| **Motor RAG** | Flowise Cloud | ChatflowV3, `610c56f2-d7b9-43ea-8c48-b62f18570416` |

---

## 4. Componentes y repositorios

El sistema está compuesto por **3 artefactos desplegables**:

```
friko-recomienda/
│
├── 📄 index.html                          # Landing page (un solo archivo)
│   └── Deploy: Netlify
│
├── 🤖 FrikoRAGPipeline_ChatflowV3         # Motor RAG exportado desde Flowise
│   └── Deploy: Flowise Cloud
│   └── Archivo: FrikoRAGPipeline_ChatflowV3_Chatflow.json
│
└── ⚙️  Friko_Chef_Bot n8n               # Workflow del bot de Telegram (versión actual)
    └── Deploy: n8n Cloud
    └── Archivo: Friko Recomienda Bot - Telegram + Flowise RAG.json
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

**[https://frikorecomienda.netlify.app](https://frikorecomienda.netlify.app)**
 
1. Haz clic en **"Hablar en la web"** — el chat se abre como widget flotante en la misma página.
2. Escribe tu mensaje en el campo de texto y presiona enviar.
3. El asistente guiará la conversación solicitando los datos necesarios de a uno.
> No se requiere crear cuenta ni iniciar sesión.
 
### Canal Telegram

**[https://t.me/friko_recomienda_bot](https://t.me/friko_recomienda_bot)**

1. Abre el enlace o busca `@friko_recomienda_bot` en Telegram.
2. Presiona **Iniciar** o envía `/start` para comenzar.
3. Sigue el flujo conversacional — el bot pedirá un dato a la vez.
### Comparación de canales

| Aspecto | Web | Telegram |
|---|---|---|
| Acceso | Navegador, sin instalar | App Telegram instalada |
| Ideal para | Computador o tablet | Celular |
| Historial | Durante la sesión abierta | Visible en Telegram (in-memory en Flowise) |
| Reiniciar | Recargar la página | Enviar `/nuevo` |

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
| `/start` | Muestra el mensaje de bienvenida |
| `/nuevo` | Reinicia con mensaje de bienvenida |
| `/reset` | Alias de `/nuevo` |
| `/iniciar` | Alias de `/start` |
| `/reiniciar` | Alias de `/reset` |

> Los comandos muestran la bienvenida sin llamar al RAG. El historial de conversación en Flowise no se limpia con estos comandos — para eso el usuario debe iniciar una nueva sesión.

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

### Canal Web

```
Usuario escribe → Flowise Embed SDK → Prediction API → RAG → Respuesta
```

El widget de Flowise maneja el flujo completo internamente: rephrase, embeddings, búsqueda vectorial, scoring y generación.

### Canal Telegram — Workflow 

```
1. Usuario escribe en Telegram
2. Telegram → n8n webhook  (event: message)
3. Code: Parse Message
      · Extrae: chatId, firstName, msgText, isText, isCommand
      · El mensaje se pasa tal cual al RAG — sin Groq NLP intermedio
4. IF: Valid Text?
      · false → Telegram: Solo Texto → FIN
      · true  → continúa
5. IF: Is Command? (/start /nuevo /reset /iniciar /reiniciar)
      · true  → Switch: Router [bienvenida] → Telegram: Bienvenida → FIN
      · false → Switch: Router [RAG]
6. HTTP: Telegram Typing  (sendChatAction = "typing")
7. Code: Build Flowise Query
      · Payload: { question: msgText, sessionId: "tg_{chatId}" }
8. HTTP: Call Flowise RAG  (timeout 90s)
      · POST /api/v1/prediction/{chatflowId}
      · El RAG gestiona: slot-filling, región, validación, scoring y receta
9. Code: Process Response
      · Markdown → Telegram HTML
      · Detecta errores por status >= 400 o respuesta vacía
10. IF: Success?
      · true  → Telegram: Enviar Receta  (HTML, parse_mode: HTML)
      · false → Telegram: Enviar Error   (aviso + instrucción /nuevo)
```

### Nodos del workflow v9.1

| # | Nodo | Tipo | Función |
|---|---|---|---|
| 1 | Telegram Trigger | telegramTrigger | Punto de entrada — webhook de Telegram |
| 2 | Code: Parse Message | code | Extrae chatId, msgText, isCommand |
| 3 | IF: Valid Text? | if | Filtra mensajes que no son texto |
| 4 | Telegram: Solo Texto | telegram | Aviso cuando el mensaje no es texto |
| 5 | IF: Is Command? | if | Detecta comandos de reset |
| 6 | Switch: Router | switch | 2 ramas: bienvenida o RAG |
| 7 | Telegram: Bienvenida | telegram | Mensaje de bienvenida |
| 8 | HTTP: Telegram Typing | httpRequest | Indicador "escribiendo..." |
| 9 | Code: Build Flowise Query | code | Construye el payload para Flowise |
| 10 | HTTP: Call Flowise RAG | httpRequest | Llama a la Prediction API (90s timeout) |
| 11 | Code: Process Response | code | Markdown → Telegram HTML, detecta errores |
| 12 | IF: Success? | if | Bifurca éxito vs error |
| 13 | Telegram: Enviar Receta | telegram | Entrega la receta al usuario |
| 14 | Telegram: Enviar Error | telegram | Aviso de error con instrucción /nuevo |

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

### Gestión de sesiones en Telegram

Las sesiones son gestionadas por el **Buffer Memory de Flowise** mediante el `sessionId = "tg_{chatId}"`. El historial persiste en memoria RAM mientras el servicio esté activo. Los comandos de reset muestran la bienvenida pero no limpian el historial de Flowise.

### Velocidad de respuesta

Preguntas de recolección de datos responden en segundos. La recomendación final puede tardar hasta **30 segundos** dependiendo del estado del servicio de Flowise.

### Correcciones durante la conversación

El usuario puede corregir un dato ya proporcionado escribiendo naturalmente:

> *"en realidad estoy en Bogotá"*, *"mejor para 6 personas"*, *"cambia a horno"*

El RAG detecta la corrección usando el historial del Buffer Memory.

---

## 10. Preguntas frecuentes

**¿Necesito crear una cuenta?**
No. Sin registro en ambos canales.

**¿Puedo dar todos los datos en un solo mensaje?**
Sí. *"Medellín, somos 5, airfryer, cena rápida"* → el RAG extrae los cuatro datos y recomienda directamente.

**¿Qué pasa si mi ciudad no tiene cobertura?**
El RAG informa que la ciudad no está cubierta, lista las 6 regiones disponibles y sugiere visitar [momentosfriko.com](https://www.momentosfriko.com).

**¿Las recetas son oficiales de Friko?**
El asistente prioriza recetas de [momentosfriko.com](https://www.momentosfriko.com). Si no hay una receta oficial, genera una con IA e indica el origen con *🤖 Receta sugerida por IA*.

**¿Puedo pedir otra recomendación?**
Sí. Escribe *"dame otra opción"* o *"recomiéndame otro producto"* y el RAG entrega una alternativa usando el historial de conversación.

**¿El asistente recuerda conversaciones anteriores?**
Solo dentro de la sesión activa (Buffer Memory de Flowise). Si el servidor se reinicia, el historial se pierde.

*Proyecto desarrollado para Friko y Antillana — Grupo BIOS · Colombia 🇨🇴*