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
  // Probar modelos de visión en orden de preferencia (Groq deprecó 11b/90b, usar Llama 4)
  const visionModels = [
    body.model || null,
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'meta-llama/llama-4-maverick-17b-128e-instruct',
    'llama-3.2-11b-vision-preview',
    'llama-3.2-90b-vision-preview',
  ].filter(Boolean);
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
        const reply = data.choices?.[0]?.message?.content || '';
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
