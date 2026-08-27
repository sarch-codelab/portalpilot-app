module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel. Configúralo en Project Settings → Environment Variables.' });
  let body = {};
  try { body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {}; } catch {}
  try {
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: body.modelId || body.model || 'llama-3.3-70b-versatile',
        messages: [{ role: 'system', content: body.systemPrompt || 'Eres un asistente útil.' }, { role: 'user', content: body.prompt || body.message || '' }],
        max_tokens: body.maxTokens || 1500,
        temperature: body.temperature ?? 0.7,
      }),
    });
    const data = await r.json();
    if (!r.ok || !data.choices) return res.status(r.status || 502).json({ success: false, error: data.error?.message || 'Error Groq', details: data });
    const content = data.choices?.[0]?.message?.content || '';
    return res.status(200).json({ success: true, text: content, modelId: body.modelId || 'llama-3.3-70b-versatile', provider: 'groq', tokensUsed: data.usage?.total_tokens || 0 });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};
