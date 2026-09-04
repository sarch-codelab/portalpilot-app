// api/_aiRouter.js
// Enrutador de IA con respaldo automático de proveedor.
// Flujo: Groq (primario) -> OpenRouter (fallback) cuando Groq falla.
// Variables de entorno requeridas en Vercel:
//   GROQ_API_KEY          (primario)
//   OPENROUTER_API_KEY    (respaldo, opcional: si no existe se omite el fallback)

const VISION_IMAGES_LIMIT = 4; // evita payloads enormes en visión

const OPENROUTER_MODELS = {
  chat: ['openai/gpt-4o-mini', 'openai/gpt-4o', 'meta-llama/llama-3.3-70b-instruct'],
  vision: ['openai/gpt-4o-mini', 'anthropic/claude-3-5-sonnet', 'google/gemini-2.0-flash'],
};

// Llama a un endpoint OpenAI-compatible y normaliza la respuesta.
async function callOpenAICompatible({ baseUrl, key, headers, model, messages, maxTokens, temperature }) {
  const r = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: Object.assign({ 'Content-Type': 'application/json', Authorization: `Bearer ${key}` }, headers || {}),
    body: JSON.stringify(Object.assign({
      model,
      messages,
      max_tokens: maxTokens,
      temperature,
    }, baseUrl.startsWith('https://openrouter') ? { max_tokens: maxTokens } : {})),
  });
  const data = await r.json();
  return { ok: r.ok, status: r.status, data };
}

// Respaldos OpenRouter para chat (respuestas de texto).
async function openRouterComplete({ messages, model, maxTokens, temperature }) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error('OPENROUTER_API_KEY no configurada');
  const candidates = (model ? [model] : []).concat(OPENROUTER_MODELS.chat);
  let lastErr = null;
  for (const m of candidates) {
    try {
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${key}`,
          'HTTP-Referer': (process.env.WEB_DOMAIN || 'https://portalpilot-app.vercel.app'),
          'X-Title': 'Portal Pilot',
        },
        body: JSON.stringify({ model: m, messages, max_tokens: maxTokens || 1500, temperature: temperature ?? 0.7 }),
      });
      const data = await r.json();
      if (r.ok && data.choices && data.choices[0]?.message?.content) {
        return {
          reply: data.choices[0].message.content,
          model: data.model || m,
          provider: 'openrouter',
          usage: data.usage,
        };
      }
      const msg = data.error?.message || '';
      if (r.status === 404 || msg.toLowerCase().includes('model')) { lastErr = msg; continue; }
      throw new Error(msg || 'Error OpenRouter');
    } catch (e) {
      lastErr = e.message;
      continue;
    }
  }
  throw new Error(lastErr || 'No hay modelo OpenRouter disponible');
}

// Respaldos OpenRouter para visión (imágenes + texto).
async function openRouterVision({ prompt, image, maxTokens }) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error('OPENROUTER_API_KEY no configurada');
  const content = [
    { type: 'text', text: prompt },
    { type: 'image_url', image_url: { url: image } },
  ];
  let lastErr = null;
  for (const m of OPENROUTER_MODELS.vision) {
    try {
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${key}`,
          'HTTP-Referer': (process.env.WEB_DOMAIN || 'https://portalpilot-app.vercel.app'),
          'X-Title': 'Portal Pilot',
        },
        body: JSON.stringify({ model: m, messages: [{ role: 'user', content }], max_tokens: maxTokens || 800, temperature: 0.2 }),
      });
      const data = await r.json();
      if (r.ok && data.choices) {
        let reply = data.choices[0]?.message?.content || '';
        reply = reply.replace(/ thinking[\s\S]*?<\/think>/gi, '').trim();
        return { reply, model: data.model || m, provider: 'openrouter', usage: data.usage };
      }
      const msg = data.error?.message || '';
      if (r.status === 404 || msg.toLowerCase().includes('model')) { lastErr = msg; continue; }
      throw new Error(msg || 'Error OpenRouter Visión');
    } catch (e) {
      lastErr = e.message;
      continue;
    }
  }
  throw new Error(lastErr || 'No hay modelo OpenRouter de visión disponible');
}

module.exports = { openRouterComplete, openRouterVision, VISION_IMAGES_LIMIT };
