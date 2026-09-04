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
    // Auto-descubrimiento de modelos de chat vivos (Groq depreca modelos con frecuencia)
    const { pickModels } = require('../_modelPicker.js');
    const requested = body.modelId || body.model || '';
    let chatModels;
    try {
      const live = await pickModels(key, requested);
      chatModels = live.chat.length ? live.chat : [requested || 'openai/gpt-oss-20b', 'openai/gpt-oss-120b'];
    } catch {
      chatModels = [requested || 'openai/gpt-oss-20b', 'openai/gpt-oss-120b'];
    }
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
    // Respaldo automático: OpenRouter cuando Groq falla o no hay más modelos.
    try {
      const { openRouterComplete } = require('../_aiRouter.js');
      const fallback = await openRouterComplete({
        messages: [
          { role: 'system', content: body.systemPrompt || 'Eres un asistente útil.' },
          { role: 'user', content: body.prompt || body.message || '' },
        ],
        model: body.modelId || body.model || '',
        maxTokens: body.maxTokens || 1500,
        temperature: body.temperature ?? 0.7,
      });
      return res.status(200).json({
        success: true,
        text: fallback.reply,
        modelId: fallback.model,
        provider: fallback.provider,
        tokensUsed: fallback.usage?.total_tokens || 0,
      });
    } catch (fallbackErr) {
      return res.status(502).json({ success: false, error: lastError || fallbackErr.message || 'Todos los modelos de chat fallaron', details: null });
    }
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};
