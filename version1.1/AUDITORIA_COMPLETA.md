# 🔍 AUDITORÍA COMPLETA — Friko Recomienda v1
> Fecha: 2026-04-18 | Auditor: Claude Sonnet 4.6

---

## RESUMEN EJECUTIVO

| Componente | Estado | Bugs Críticos |
|---|---|---|
| Schema SQL | ⚠️ Incompleto | Falta `match_documents` RPC, sin índices vectoriales |
| Flowise RAG | 🔴 Roto | `rephrasePrompt` sin variables requeridas |
| Prompt del Bot | ⚠️ Parcial | Método "Salteado" ausente, scoring imposible de ejecutar |
| Landing Page | ⚠️ Inconsistente | Features prometidas no implementadas, HTML legal faltante |
| Arquitectura | ⚠️ Frágil | Sin filtro de metadata por región, topK insuficiente |

---

## 1. 🔴 BUGS CRÍTICOS (rompen la funcionalidad)

### BUG-01 — rephrasePrompt sin variables requeridas [CRÍTICO]
**Componente:** Flowise → ConversationalRetrievalQAChain
**Impacto:** El chain FALLA en cualquier pregunta de seguimiento

El `rephrasePrompt` configurado no incluye los placeholders obligatorios `{chat_history}` y `{question}`. El chain lanza error y deja de funcionar después del primer mensaje. Solo el primer turno funciona; a partir del segundo la conversación se rompe.

**Evidencia en el JSON:**
```
"rephrasePrompt": "Dado el historial de conversación y la nueva pregunta del usuario, reformula..."
```
Esta cadena describe el comportamiento pero no contiene `{chat_history}` ni `{question}`.

**Fix:** Ver `FrikoRAGPipeline_ChatflowV2.json`

---

### BUG-02 — Función `match_documents` no existe en Supabase [CRÍTICO]
**Componente:** Supabase (schema.sql)
**Impacto:** pgvector no puede ejecutar búsquedas de similitud; el RAG retorna vacío

El Flowise apunta a `queryName: "match_documents"` pero esta función RPC no está definida en el schema. Sin ella, Flowise no puede hacer búsquedas semánticas.

**Fix:** Ver `schema_v2.sql`

---

### BUG-03 — Sin índices vectoriales en columnas `embedding` [CRÍTICO]
**Componente:** Supabase (schema.sql)
**Impacto:** Búsquedas O(n) completas — con 99 documentos es lento; con 10.000 es inutilizable

Las tablas `documents`, `productos` y `recetas` tienen columna `embedding` pero sin índice HNSW o IVFFlat.

**Fix:** Ver `schema_v2.sql`

---

## 2. 🟠 BUGS ALTOS (degradan severamente la experiencia)

### BUG-04 — Método "Salteado" ausente del prompt [ALTO]
**Componente:** Prompt del bot
**Impacto:** Camaron titi (ANTI-002) tiene como preparación "Sarten, Salteado" en el catálogo. El prompt solo acepta: Horno · Airfryer · Sartén · Parrilla · Plancha · Wok. El bot nunca podrá recomendar correctamente este producto para su uso principal.

---

### BUG-05 — Sin filtro de metadata por región en Supabase [ALTO]
**Componente:** Flowise → Supabase vector store
**Impacto:** Un usuario de Bogotá puede recibir productos exclusivos de Atlántico

El campo `supabaseMetadataFilter` está vacío. El vector store hace búsqueda semántica en TODOS los documentos sin filtrar por región. El prompt instrucciona al LLM a respetar regiones, pero si el contexto recuperado incluye productos de otras regiones, el LLM puede confundirse.

**Fix:** El metadata de cada documento debe incluir `{"region": "Antioquia"}` y el prompt debe incluir instrucciones para ignorar productos de otras regiones en el contexto.

---

### BUG-06 — topK=5 insuficiente para el catálogo [ALTO]
**Componente:** Flowise → Supabase vector store
**Impacto:** Con 9-11 productos por región, topK=5 puede omitir hasta 6 productos relevantes

La búsqueda semántica con topK=5 solo recupera 5 documentos. Dado que hay regiones con 11 productos, el bot puede ignorar opciones relevantes.

**Fix:** topK=10 (o crear documentos de contexto regional agregados)

---

### BUG-07 — Features prometidas en landing no implementadas [ALTO]
**Componente:** Landing page
**Impacto:** Expectativas del usuario no coinciden con el bot real

| Feature en landing | Realidad |
|---|---|
| "Habla como tú" (dialecto regional) | El prompt NO adapta el dialecto según región |
| "Modo Sorpréndeme" (botón) | No existe como botón en el widget real |
| "Sin descongelar / tecnología 1 en 1" | Nunca mencionado en el prompt |
| Botones de respuesta rápida en demo | El widget real no tiene quick-reply buttons |

---

## 3. 🟡 BUGS MEDIOS (afectan UX o mantenibilidad)

### BUG-08 — Sección legal definida en CSS pero HTML faltante [MEDIO]
El CSS tiene `.legal-section`, `.legal-inner`, `.legal-card`, etc., pero no hay HTML correspondiente en el `<body>`. La política de datos se muestra solo en el modal de consentimiento, sin sección permanente.

### BUG-09 — CTA "Empezar a cocinar" no abre el chatbot [MEDIO]
El botón primario hace scroll a la sección demo estática. Debería abrir el widget del chatbot o hacer scroll al widget flotante.

### BUG-10 — Double-toggle bug en checkbox de consentimiento [MEDIO]
Hay dos event listeners en el checkbox: `onclick` en el `div` padre que llama `toggleCheck()`, y `onchange` en el `input` que también llama `toggleCheck()`. Al hacer click directo en el checkbox, ambos se disparan y se cancelan mutuamente → el checkbox no cambia de estado.

### BUG-11 — BufferMemory sin sessionId = sesiones no persistentes [MEDIO]
El BufferMemory usa un ID aleatorio por sesión. Si Flowise se reinicia o el usuario cambia de dispositivo, pierde el historial. Para Telegram esto es especialmente crítico.

### BUG-12 — `Bogota` sin tilde en catálogo y metadata [MEDIO]
El catálogo usa "Bogota" (sin tilde). El prompt usa "Bogotá" con tilde. Esta inconsistencia puede causar que el filtro por región falle si se hace match exacto.

---

## 4. 🟢 BUGS BAJOS / MEJORAS

### BUG-13 — Temperature 0.3 muy baja para recetas creativas [BAJO]
0.3 produce respuestas repetitivas. Para recetas generadas por IA se recomienda 0.5-0.6.

### BUG-14 — returnSourceDocuments=false dificulta debugging [BAJO]
En producción está correcto, pero para validar que el RAG recupera los documentos correctos, debe activarse durante pruebas.

### BUG-15 — Widget trigger button comentado con JS inválido [BAJO]
```html
<!-- onclick="import Chatbot from flowise-embed;..." -->
```
El `import` dinámico en un onclick inline no funciona. Este código comentado es inválido.

### BUG-16 — Regla 7 ("sin IA externa") contradice la implementación [BAJO]
La Tabla de Reglas dice "genera receta sin IA externa" pero el sistema usa Groq (LLaMA 3.3 70B) para generar todo. La regla debería decir "genera receta usando el LLM del sistema cuando no haya receta real disponible".

---

## 5. 🏗️ ARQUITECTURA — PROBLEMAS DE DISEÑO

```
FLUJO ACTUAL (problemático):
Usuario → Flowise → [rephrasePrompt ROTO] → búsqueda semántica SIN FILTRO de región
        → LLM Groq → respuesta (puede incluir productos de regiones equivocadas)

FLUJO MEJORADO:
Usuario → Flowise → [rephrasePrompt CORREGIDO con {chat_history} y {question}]
        → búsqueda semántica con metadata incluida en contenido_semantico
        → LLM Groq → respuesta filtrada por instrucciones en el responsePrompt
```

**Limitación arquitectónica de fondo:** ConversationalRetrievalQAChain no soporta filtros dinámicos por metadata en tiempo de ejecución. La solución correcta a largo plazo sería:
- Opción A: Tool Calling Agent con una herramienta `buscar_productos(region, metodo, personas)` que haga query directo a Supabase
- Opción B (implementada en v2): Enriquecer el `contenido_semantico` de cada documento con texto explícito de región/método/personas, y aumentar topK para recuperar todo el portafolio de una región

Para el alcance del reto, se implementa **Opción B** por ser compatible con el stack actual.

---
