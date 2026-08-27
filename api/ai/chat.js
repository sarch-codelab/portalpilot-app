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
  const message = body.message || body.prompt || body.query || '';
  const systemPrompt = body.systemPrompt || 'Eres un asistente útil de Portal Pilot.';
  if (!message) return res.status(400).json({ error: 'Falta message', reply: null });
  try {
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: body.model || body.modelId || 'llama-3.3-70b-versatile',
        messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: message }],
        max_tokens: body.maxTokens || 1500,
        temperature: body.temperature ?? 0.7,
      }),
    });
    const data = await r.json();
    if (!r.ok || !data.choices) return res.status(r.status || 502).json({ error: data.error?.message || 'Error Groq', reply: null, details: data });
    const reply = data.choices?.[0]?.message?.content || '';
    return res.status(200).json({ reply, model: data.model, provider: 'groq', usage: data.usage });
  } catch (err) {
    return res.status(500).json({ error: err.message, reply: null });
  }
};
