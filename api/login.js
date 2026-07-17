module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  const target = process.env.AUTH_BACKEND_URL;

  if (!target) {
    res.status(500).json({
      error: 'Falta AUTH_BACKEND_URL en Vercel. Configúralo en Project Settings → Environment Variables.',
    });
    return;
  }

  const response = await fetch(`${target.replace(/\/$/, '')}/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: body.email,
      password: body.password,
    }),
  });

  const text = await response.text();
  res.status(response.status);
  res.setHeader('Content-Type', 'application/json');
  res.send(text);
};
