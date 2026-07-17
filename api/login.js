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
  const rawTarget = (process.env.AUTH_BACKEND_URL || '').trim();
  const baseUrlEnv = (process.env.AUTH_BACKEND_BASE_URL || '').trim();
  const tokenEnv = (process.env.AUTH_BACKEND_TOKEN || '').trim();

  if (!rawTarget && !baseUrlEnv) {
    res.status(500).json({
      error: 'Falta AUTH_BACKEND_URL o AUTH_BACKEND_BASE_URL en Vercel. Asegúrate de configurar el backend de autenticación.',
    });
    return;
  }

  const normalizeUrl = (value) => {
    if (!value) return null;
    try {
      return new URL(value).toString();
    } catch {
      const trimmed = value.replace(/\/+$/, '');
      if (/^[a-zA-Z0-9.-]+(:\d+)?$/.test(trimmed) || trimmed.includes('localhost')) {
        return `https://${trimmed}`;
      }
      return null;
    }
  };

  const isToken = rawTarget.startsWith('nc_pat_');
  const targetUrlString = isToken ? normalizeUrl(baseUrlEnv) : normalizeUrl(rawTarget) || normalizeUrl(baseUrlEnv);
  const authToken = isToken ? rawTarget : tokenEnv || '';

  if (!targetUrlString) {
    const message = isToken
      ? 'La variable AUTH_BACKEND_URL contiene un token de NocoDB en lugar de una URL. Configura AUTH_BACKEND_BASE_URL con la URL del backend de autenticación y AUTH_BACKEND_TOKEN con el token.'
      : 'AUTH_BACKEND_URL en Vercel no es una URL válida. Debe comenzar con https:// y apuntar al backend de autenticación.';

    res.status(500).json({
      error: message,
    });
    return;
  }

  const headers = {
    'Content-Type': 'application/json',
  };
  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
    headers['x-api-key'] = authToken;
  }

  const response = await fetch(`${targetUrlString.replace(/\/$/, '')}/api/login`, {
    method: 'POST',
    headers,
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
