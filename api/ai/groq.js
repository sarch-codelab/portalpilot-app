module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  const key = process.env.GROQ_API_KEY;
  if (!key) {
    res.status(500).json({
      error: 'Falta GROQ_API_KEY en Vercel. Configúralo en Project Settings → Environment Variables.',
    });
    return;
  }

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: body.modelId || 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: body.systemPrompt || 'Eres un asistente útil.' },
        { role: 'user', content: body.prompt || '' },
      ],
      max_tokens: body.maxTokens || 1500,
      temperature: body.temperature || 0.7,
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    res.status(response.status).json({
      success: false,
      error: data.error?.message || 'Error al consultar Groq',
    });
    return;
  }

  const content = data.choices?.[0]?.message?.content || '';
  res.status(200).json({
    success: true,
    text: content,
    modelId: body.modelId || 'llama-3.3-70b-versatile',
    provider: 'groq',
    tokensUsed: data.usage?.total_tokens || 0,
  });
};
