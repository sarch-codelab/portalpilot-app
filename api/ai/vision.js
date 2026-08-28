module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  let body = {};
  try { body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {}; } catch {}
  let image = body.image || body.base64 || '';
  const prompt = body.prompt || 'Identifica este producto y devuelve un JSON con: nombre, marca, categoria, descripcion, presentacion, unidad_medida, confianza (0-1). Si no puedes determinar algo, deja el campo como null. Responde SOLO con el JSON.';
  if (!image) return res.status(400).json({ error: 'Falta image (base64)', reply: null });
  if (!image.startsWith('data:')) image = `data:image/jpeg;base64,${String(image).replace(/\s+/g, '')}`;
  // Auto-descubrimiento de modelos de visión vivos (Groq depreca modelos con frecuencia)
  const { pickModels } = require('../_modelPicker.js');
  const requestedModel = body.model || '';
  let visionModels;
  try {
    const live = await pickModels(key, requestedModel);
    visionModels = live.vision.length ? live.vision : [requestedModel || 'qwen/qwen3.6-27b', 'qwen/qwen3.8-27b'];
  } catch {
    visionModels = [requestedModel || 'qwen/qwen3.6-27b', 'qwen/qwen3.8-27b'];
  }
  let lastError = null;
  for (const model of visionModels) {
    try {
      const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model,
          messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, { type: 'image_url', image_url: { url: image } }] }],
          max_tokens: body.maxTokens || 800,
          temperature: 0.2,
        }),
      });
      const data = await r.json();
      if (r.ok && data.choices) {
        let reply = data.choices?.[0]?.message?.content || '';
        // Qwen devuelve <think>...</think> antes del JSON real - limpiar
        reply = reply.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
        return res.status(200).json({ reply, model: data.model || model, provider: 'groq', usage: data.usage });
      }
      // Si es error de modelo no encontrado, probar siguiente modelo
      const errMsg = (data.error?.message || '').toLowerCase();
      if (errMsg.includes('does not exist') || errMsg.includes('model_not_found') || errMsg.includes('decommissioned') || r.status === 404) {
        lastError = data;
        continue;
      }
      return res.status(r.status || 502).json({ error: data.error?.message || 'Error Groq Vision', reply: null, details: data });
    } catch (err) {
      lastError = { error: { message: err.message } };
      continue;
    }
  }
  return res.status(502).json({ error: lastError?.error?.message || 'No hay modelo de visión disponible', reply: null, details: lastError });
};
