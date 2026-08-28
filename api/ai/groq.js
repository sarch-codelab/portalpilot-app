module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido' });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel. ConfigÃºralo en Project Settings â†’ Environment Variables.' });
  let body = {};
  try { body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {}; } catch {}
  try {
    // Modelos de chat disponibles en Free/Dev plan de Groq (2026)
    const chatModels = [
      body.modelId || body.model || 'openai/gpt-oss-20b',
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
            messages: [{ role: 'system', content: body.systemPrompt || 'Eres un asistente Ãºtil.' }, { role: 'user', content: body.prompt || body.message || '' }],
            max_tokens: body.maxTokens || 1500,
            temperature: body.temperature ?? 0.7,
          }),
        });
        const data = await r.json();
        if (r.ok && data.choices) {
          const content = data.choices?.[0]?.message?.content || '';
          return res.status(200).json({ success: true, text: content, modelId: model, provider: 'groq', tokensUsed: data.usage?.total_tokens || 0 });
        }
        const msg = data.error?.message || '';
        if (msg.includes('does not exist') || msg.includes('model_not_found') || msg.includes('decommissioned') || r.status === 404) {
          lastError = msg;
          continue;
        }
        return res.status(r.status || 502).json({ success: false, error: msg || 'Error Groq', details: data });
      } catch (err) {
        lastError = err.message;
        continue;
      }
    }
    return res.status(502).json({ success: false, error: lastError || 'Todos los modelos de chat fallaron', details: null });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};
