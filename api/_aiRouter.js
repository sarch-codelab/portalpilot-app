// api/_aiRouter.js
// Respaldo multi-proveedor para el stack serverless de la app.
//
// OJO sobre el orden: este módulo se invoca DESPUÉS de que el llamador ya haya
// agotado su propia cadena de Groq (ver api/ai/chat.js, api/ai/vision.js y
// api/[...slug].js). Por eso Groq va el último aquí: reintentar el provider que
// acaba de fallar solo añade un timeout antes de llegar a otro.
//
// Variables de entorno en Vercel (todas opcionales; se omiten las que falten):
//   MISTRAL_API_KEY
//   CLOUDFLARE_API_KEY + CLOUDFLARE_ACCOUNT_ID   (ambos, siempre juntos)
//   ZAI_API_KEY
//   HUGGINGFACE_API_KEY (o HF_TOKEN)

const VISION_IMAGES_LIMIT = 4; // evita payloads enormes en visión

// Groq va el último porque el llamador ya agotó su propia cadena de Groq; reintentarlo
// solo añadiría un timeout de 10s antes de llegar a otro provider.
const FALLBACK_ORDER = ['mistral', 'zai', 'huggingface', 'cloudflare', 'groq'];

const FALLBACK_PROVIDERS = {
  mistral: {
    name: 'Mistral',
    env: ['MISTRAL_API_KEY'],
    chatUrl: () => 'https://api.mistral.ai/v1/chat/completions',
    modelsUrl: () => 'https://api.mistral.ai/v1/models',
    auth: 'bearer',
    supportsVision: false,
    models: { chat: 'mistral-small-latest', fast: 'ministral-3b-latest' },
  },
  zai: {
    name: 'Z.AI',
    env: ['ZAI_API_KEY'],
    chatUrl: () => 'https://api.z.ai/api/paas/v4/chat/completions',
    modelsUrl: null, // GLM no expone /models; catálogo según docs.z.ai
    auth: 'bearer',
    supportsVision: true,
    // IDs del enum oficial de docs.z.ai (chat: glm-5.2|5.1|5|5-turbo|4.7|
    // 4.7-flash|4.7-flashx|4.6|4.5*|4-32b-0414-128k; visión: glm-5v-turbo|
    // 4.6v|4.6v-flash|4.6v-flashx|4.5v). OJO: no existe 'glm-4-flash'.
    models: {
      chat: 'glm-4.7',
      fast: 'glm-4.7-flash',
      vision: 'glm-4.6v-flash',
    },
    // GLM viene con thinking ACTIVADO por defecto: gasta max_tokens en razonar
    // antes de responder, y con presupuestos de 800-1500 tokens no queda casi
    // nada para la respuesta real.
    bodyExtra: { thinking: { type: 'disabled' } },
  },
  huggingface: {
    name: 'Hugging Face',
    env: ['HUGGINGFACE_API_KEY', 'HF_TOKEN'],
    chatUrl: () => 'https://router.huggingface.co/v1/chat/completions',
    modelsUrl: () => 'https://router.huggingface.co/v1/models',
    auth: 'bearer',
    supportsVision: true,
    models: {
      chat: 'meta-llama/Llama-3.3-70B-Instruct:fastest',
      fast: 'meta-llama/Llama-3.1-8B-Instruct:fastest',
      vision: 'meta-llama/Llama-3.2-11B-Vision-Instruct',
    },
  },
  cloudflare: {
    name: 'Cloudflare Workers AI',
    env: ['CLOUDFLARE_API_KEY', 'CLOUDFLARE_ACCOUNT_ID'],
    // El account_id va en la ruta: sin él no hay a dónde llamar.
    chatUrl: () => {
      const account = process.env.CLOUDFLARE_ACCOUNT_ID;
      return account
        ? `https://api.cloudflare.com/client/v4/accounts/${account}/ai/v1/chat/completions`
        : null;
    },
    modelsUrl: () => {
      const account = process.env.CLOUDFLARE_ACCOUNT_ID;
      return account ? `https://api.cloudflare.com/client/v4/accounts/${account}/ai/models/search` : null;
    },
    auth: 'bearer',
    supportsVision: false,
    models: {
      chat: '@cf/meta/llama-3.1-8b-instruct-fp8',
      fast: '@cf/meta/llama-3.1-8b-instruct-fp8',
    },
  },
  // OVH se retiró de la cadena (2026-10): su pool anónimo son 2 req/min por IP y no
  // escala con el número de usuarios. Como no necesita clave, `alwaysAvailable` lo
  // hacía pasar siempre el filtro providerConfigured() y cada request se gastaba un
  // 429 real para ganar cero capacidad. El código queda en git por si acaso.
  //
  groq: {
    name: 'Groq',
    env: ['GROQ_API_KEY'],
    chatUrl: () => 'https://api.groq.com/openai/v1/chat/completions',
    modelsUrl: () => 'https://api.groq.com/openai/v1/models',
    auth: 'bearer',
    supportsVision: true,
    models: {
      chat: 'openai/gpt-oss-20b',
      fast: 'openai/gpt-oss-20b',
      vision: 'meta-llama/llama-4-scout-17b-16e-instruct',
    },
  },
};

const DISCOVERY_TTL_MS = 5 * 60 * 1000;
const DEAD_MODEL_TTL_MS = 30 * 60 * 1000;
// Tope del /models: cabe dentro del presupuesto total de la petición.
const DISCOVERY_TIMEOUT_MS = 5_000;
// Un rate limit (429) no se recupera en 15s: la ventana del proveedor es de un
// minuto. Arrancar el cooldown corto solo garantiza reintentar y volver a fallar.
const BREAKER_COOLDOWN_RATE_LIMIT_MS = 60_000;
const BREAKER_COOLDOWN_ERROR_MS = 15_000;
const BREAKER_MAX_COOLDOWN_MS = 300_000;

// Estado a nivel de módulo: vive mientras la instancia lambda esté caliente. En
// Vercel es best-effort (un cold start lo reinicia); en el peor caso se pierde el
// castigo y se vuelve al comportamiento anterior, nunca peor.
const liveModelCache = new Map(); // provKey -> { ids:Set, at:number }
const deadModels = new Map();    // provKey -> { ids:Set, at:number }
const breakers = new Map();      // provKey -> { until:number, fails:number, reason:string }

function getKey(prov) {
  for (const name of prov.env || []) {
    const v = process.env[name];
    if (v) return v;
  }
  return null;
}

function providerConfigured(provKey) {
  const prov = FALLBACK_PROVIDERS[provKey];
  if (!prov) return false;
  if (!prov.alwaysAvailable && !getKey(prov)) return false;
  return !!prov.chatUrl();
}

function breakerOpen(provKey) {
  const b = breakers.get(provKey);
  return !!(b && b.until > Date.now());
}

function breakerFail(provKey, reason, isRateLimit) {
  const now = Date.now();
  const b = breakers.get(provKey) || { until: 0, fails: 0, reason: '' };
  b.fails += 1;
  const base = isRateLimit ? BREAKER_COOLDOWN_RATE_LIMIT_MS : BREAKER_COOLDOWN_ERROR_MS;
  b.until = now + Math.min(BREAKER_MAX_COOLDOWN_MS, base * 2 ** (b.fails - 1));
  b.reason = reason || '';
  breakers.set(provKey, b);
}

function breakerReset(provKey) {
  const b = breakers.get(provKey);
  if (b) {
    b.fails = 0;
    b.until = 0;
    b.reason = '';
  }
}

function deadModelsFor(provKey) {
  const rec = deadModels.get(provKey);
  if (!rec) return null;
  if (Date.now() - rec.at > DEAD_MODEL_TTL_MS) {
    deadModels.delete(provKey);
    return null;
  }
  return rec.ids;
}

function markModelDead(provKey, modelId) {
  const now = Date.now();
  let rec = deadModels.get(provKey);
  if (!rec || now - rec.at > DEAD_MODEL_TTL_MS) {
    rec = { ids: new Set(), at: now };
    deadModels.set(provKey, rec);
  }
  rec.ids.add(modelId);
}

async function discoverModels(provKey, deadline) {
  const prov = FALLBACK_PROVIDERS[provKey];
  const url = typeof prov.modelsUrl === 'function' ? prov.modelsUrl() : prov.modelsUrl;
  if (!url) return null;

  const now = Date.now();
  const cached = liveModelCache.get(provKey);
  if (cached && now - cached.at < DISCOVERY_TTL_MS) return cached.ids;

  const headers = { 'Content-Type': 'application/json' };
  if (prov.auth === 'bearer') {
    const k = getKey(prov);
    if (!k) return null;
    headers.Authorization = `Bearer ${k}`;
  }

  // El discovery nunca puede sobrevivir al deadline de la petición: se acota a lo
  // que quede del presupuesto global.
  const budget = deadline ? Math.min(DISCOVERY_TIMEOUT_MS, deadline - Date.now()) : DISCOVERY_TIMEOUT_MS;
  if (budget <= 0) return null;

  try {
    // El discovery es una optimización, no un requisito: si el /models no responde
    // no puede quedarse colgado arrastrando la petición. Sin este timeout, un
    // provider que acepta la conexión y nunca contesta se comía el presupuesto entero.
    const r = await fetch(url, { headers, signal: AbortSignal.timeout(budget) });
    if (!r.ok) return null;
    const data = await r.json();
    const raw = data?.data || data?.models || [];
    const ids = (Array.isArray(raw) ? raw : [])
      .map((m) => (typeof m === 'string' ? m : m && (m.id || m.name)))
      .filter(Boolean);
    if (!ids.length) return null;
    const set = new Set(ids);
    liveModelCache.set(provKey, { ids: set, at: now });
    return set;
  } catch {
    // El descubrimiento es una optimización: si falla, se usa la lista estática.
    return null;
  }
}

// Modelos que no responden nunca a /chat/completions (audio, embeddings, guardas).
const EXCLUDE_MODEL_RE = /whisper|guard|compound|sarif|safety|embed|bge|m3-|tts|moderation|rerank|translat/i;

// Presupuesto de tiempo de UNA petición de IA, de principio a fin. El cliente
// espera segundos; encadenar providers con 30s cada uno convertía un simple corte
// de cuota en una petición de minutos que el usuario ya había abandonado.
const AI_GATEWAY_ATTEMPT_TIMEOUT_MS = 10_000; // por intento a un provider
const AI_GATEWAY_DEADLINE_MS = 25_000;       // presupuesto total de la cadena

async function buildModelChain(provKey, role, requested, deadline) {
  const prov = FALLBACK_PROVIDERS[provKey];
  if (!prov) return [];
  if (role === 'vision' && !prov.supportsVision) return [];

  const live = await discoverModels(provKey, deadline);
  const dead = deadModelsFor(provKey);
  const chain = [];
  const push = (id) => {
    if (!id) return;
    id = String(id).trim();
    if (!id || chain.includes(id)) return;
    if (dead && dead.has(id) && id !== requested) return;
    if (live && !live.has(id) && id !== requested) return;
    if (EXCLUDE_MODEL_RE.test(id)) return;
    chain.push(id);
  };

  push(requested);
  push(prov.models && prov.models[role]);
  push(prov.models && prov.models.chat);
  if (live && chain.length < 3) {
    for (const id of live) {
      if (chain.length >= 4) break;
      push(id);
    }
  }
  return chain;
}

function buildHeaders(prov) {
  const headers = { 'Content-Type': 'application/json' };
  if (prov.auth === 'bearer') {
    const k = getKey(prov);
    if (k) headers.Authorization = `Bearer ${k}`;
  }
  return headers;
}

function parseError(status, data) {
  const msg = data?.error?.message || data?.message || data?.errors?.[0]?.message || '';
  return { status, msg: String(msg || `HTTP ${status}`) };
}

function isModelGone(status, msg) {
  const l = msg.toLowerCase();
  return status === 404
    || /does not exist|model_not_found|decommissioned|not found|no such model/.test(l);
}

// varios modelos de razonamiento (GLM, gpt-oss, Qwen) dejan el análisis dentro
// del content con etiquetas <think>, o en un campo aparte.
function stripReasoning(content) {
  return String(content)
    .replace(/<(think|thinking|reasoning)>[\s\S]*?<\/\1>/gi, '')
    .replace(/<\/?(?:think|thinking|reasoning)>/gi, '')
    .trim();
}

// Core: recorre la cadena y devuelve la primera respuesta buena.
async function runChain({ role, requested, payload, temperature, maxTokens }) {
  // El reloj arranca ANTES del discovery a propósito: el presupuesto es de la
  // petición completa, no solo de los intentos. Si el discovery se come 5 s, los
  // intentos heredan lo que queda.
  const deadline = Date.now() + AI_GATEWAY_DEADLINE_MS;

  const order = FALLBACK_ORDER.filter((k) => {
    const p = FALLBACK_PROVIDERS[k];
    return p && (role !== 'vision' || p.supportsVision);
  });

  const chains = await Promise.all(order.map((k) => buildModelChain(k, role, requested || '', deadline)));
  const chainByProvider = new Map(order.map((k, i) => [k, chains[i]]));

  const attempted = [];
  let lastErr = null;

  // Deadline global: el cliente móvil espera segundos, no minutos. Encadenar varios
  // providers con su timeout cada uno daba un peor caso de minutos, con el usuario
  // ya habiéndose ido y la cuota del tenant gastándose para nada.

  for (const provKey of order) {
    const prov = FALLBACK_PROVIDERS[provKey];
    if (!providerConfigured(provKey)) continue;

    // Provider castigado: no gastamos un timeout en algo que ya sabemos caído.
    if (breakerOpen(provKey)) {
      attempted.push(`${prov.name}=cooldown`);
      continue;
    }

    if (Date.now() >= deadline) {
      attempted.push('deadline');
      break;
    }

    const url = prov.chatUrl();
    const modelChain = chainByProvider.get(provKey) || [];
    if (!url || !modelChain.length) {
      attempted.push(`${prov.name}=sin-modelos`);
      continue;
    }

    let hardFailure = false;

    for (const modelId of modelChain) {
      try {
        // El timeout se acota además con lo que queda de deadline, para que el
        // último provider de la cadena no pueda pasarse.
        const timeoutMs = Math.max(2000, Math.min(AI_GATEWAY_ATTEMPT_TIMEOUT_MS, deadline - Date.now()));
        const r = await fetch(url, {
          method: 'POST',
          headers: buildHeaders(prov),
          signal: AbortSignal.timeout(timeoutMs),
          body: JSON.stringify({
            model: modelId,
            messages: payload,
            max_tokens: maxTokens || 1500,
            temperature: temperature ?? 0.7,
            ...(prov.bodyExtra || {}),
          }),
        });
        const data = await r.json().catch(() => ({}));
        const choice = data?.choices?.[0]?.message;
        const content = choice?.content;

        if (r.ok) {
          if (typeof content === 'string' && content.trim()) {
            breakerReset(provKey);
            return {
              // GLM separa el razonamiento en reasoning_content; el cliente solo
              // quiere la respuesta.
              reply: stripReasoning(content),
              model: data.model || modelId,
              provider: provKey,
              usage: data.usage || {},
            };
          }
          // HTTP 200 pero sin texto utilizable. Suele ser un modelo de
          // razonamiento que se come el max_tokens antes de emitir respuesta:
          // es un problema del MODELO, no del provider, así que probamos el
          // siguiente de la cadena sin abrir el breaker.
          lastErr = `respuesta vacía (${modelId})`;
          markModelDead(provKey, modelId);
          continue;
        }

        const { status, msg } = parseError(r.status, data);
        lastErr = msg;

        if (isModelGone(status, msg)) {
          // Problema del modelo, no del provider: probar el siguiente.
          markModelDead(provKey, modelId);
          continue;
        }
        // Cloudflare Free responde 403/5035 a los modelos grandes.
        if (status === 403 && /5035|upgrade|paid plan/i.test(msg)) {
          markModelDead(provKey, modelId);
          continue;
        }

        // Cuota agotada, provider caído o key inválida: castigamos y cambiamos.
        // El 429 se distingue porque su cooldown debe ser largo: la ventana de
        // rate limit del proveedor es de ~1 min, no de 15s.
        breakerFail(provKey, `HTTP ${status}`, status === 429);
        hardFailure = true;
        break;
      } catch (e) {
        // Fallo de red o timeout (AbortSignal): mismo tratamiento que un 5xx.
        lastErr = e.message;
        breakerFail(provKey, e.message, false);
        hardFailure = true;
        break;
      }
    }

    if (!hardFailure) breakerReset(provKey);
    attempted.push(prov.name);
  }

  throw new Error(
    `Sin proveedor de IA disponible: ${lastErr || 'ninguno configurado'} `
    + `(probados: ${attempted.join(', ') || 'ninguno'})`
  );
}

// Respaldo de chat (respuestas de texto).
async function aiFallbackComplete({ messages, model, maxTokens, temperature }) {
  return runChain({
    role: 'chat',
    requested: model || '',
    payload: messages,
    temperature,
    maxTokens: maxTokens || 1500,
  });
}

// Respaldo de visión (imágenes + texto).
async function aiFallbackVision({ prompt, image, maxTokens }) {
  if (!image) throw new Error('aiFallbackVision requiere una imagen');
  return runChain({
    role: 'vision',
    requested: '',
    temperature: 0.2,
    maxTokens: maxTokens || 800,
    payload: [
      {
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: image } },
        ],
      },
    ],
  });
}

module.exports = {
  aiFallbackComplete,
  aiFallbackVision,
  FALLBACK_ORDER,
  VISION_IMAGES_LIMIT,
  // Alias obsoletos: se mantienen una temporada para no romper despliegues que
  // aún importen los nombres antiguos. Quitar cuando no quede ninguna referencia.
  openRouterComplete: aiFallbackComplete,
  openRouterVision: aiFallbackVision,
};