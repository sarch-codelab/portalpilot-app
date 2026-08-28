module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  let body = {};
  try { body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {}; } catch {}
  const message = body.message || body.prompt || body.query || '';
  const systemPrompt = body.systemPrompt || 'Eres un asistente Ãºtil de Portal Pilot.';
  if (!message) return res.status(400).json({ error: 'Falta message', reply: null });
  // Modelos de chat disponibles en Free/Dev plan de Groq (2026)
  const chatModels = [
    body.model || body.modelId || 'openai/gpt-oss-20b',
    'openai/gpt-oss-120b',
  ].filter((m, i, a) => m && a.indexOf(m) === i);
  let lastError = null;
  for (const model of chatModels) {
    try {
      const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model,
          messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: message }],
          max_tokens: body.maxTokens || 1500,
          temperature: body.temperature ?? 0.7,
        }),
      });
      const data = await r.json();
      if (r.ok && data.choices) {
        const reply = data.choices?.[0]?.message?.content || '';
        return res.status(200).json({ reply, model: data.model || model, provider: 'groq', usage: data.usage });
      }
      const msg = data.error?.message || '';
      if (msg.includes('does not exist') || msg.includes('model_not_found') || msg.includes('decommissioned') || r.status === 404) {
        lastError = msg;
        continue;
      }
      return res.status(r.status || 502).json({ error: msg || 'Error Groq', reply: null, details: data });
    } catch (err) {
      lastError = err.message;
      continue;
    }
  }
  return res.status(502).json({ error: lastError || 'Todos los modelos de chat fallaron', reply: null });
};
