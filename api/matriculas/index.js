async function supabaseRequest(path, options = {}) {
  const url = `${process.env.SUPABASE_URL}/rest/v1${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      apikey: process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '',
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  return {
    status: response.status,
    body: text,
  };
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    res.status(500).json({
      error: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.',
    });
    return;
  }

  if (req.method === 'GET') {
    const empresaCodigo = req.query?.empresaCodigo || '';
    const query = empresaCodigo
      ? `?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=50`
      : '?order=created_at.desc&limit=50';

    const result = await supabaseRequest(`/matriculas${query}`);
    if (result.status >= 400) {
      res.status(result.status).json({ error: result.body });
      return;
    }

    res.status(200).json(JSON.parse(result.body));
    return;
  }

  if (req.method === 'POST') {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const result = await supabaseRequest('/matriculas', {
      method: 'POST',
      body: JSON.stringify(body),
    });

    if (result.status >= 400) {
      res.status(result.status).json({ error: result.body });
      return;
    }

    res.status(200).json({ success: true, data: JSON.parse(result.body) });
  } else {
    res.status(405).json({ error: 'Método no permitido' });
  }
};
