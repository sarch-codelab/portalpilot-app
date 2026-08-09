async function supabaseRequest(path) {
  const url = `${process.env.SUPABASE_URL}/rest/v1${path}`;
  const response = await fetch(url, {
    headers: {
      apikey: process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '',
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''}`,
      'Content-Type': 'application/json',
    },
  });

  const text = await response.text();
  return { status: response.status, body: text };
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  const empresaCodigo = req.query?.empresaCodigo || '';
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    res.status(500).json({ error: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
    return;
  }

  const query = empresaCodigo
    ? `?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`
    : '';

  let result = await supabaseRequest(`/matriculas${query}`);

  // Si la columna empresa_codigo aún no existe (migración pendiente),
  // traer todo y filtrar en memoria.
  if (result.status >= 400 && empresaCodigo) {
    const all = await supabaseRequest('/matriculas');
    if (all.status < 400) {
      try {
        const rows = JSON.parse(all.body || '[]');
        const filtered = rows.filter((r) => r.empresa_codigo === empresaCodigo);
        result = { status: 200, body: JSON.stringify(filtered) };
      } catch {
        res.status(500).json({ error: 'Respuesta inválida de Supabase.' });
        return;
      }
    }
  }

  if (result.status >= 400) {
    res.status(result.status).json({ error: result.body });
    return;
  }

  const rows = JSON.parse(result.body || '[]');
  const porEstado = {};
  const porNivel = {};
  const porGrado = {};

  rows.forEach((row) => {
    const estado = row.estado || 'desconocido';
    porEstado[estado] = (porEstado[estado] || 0) + 1;

    const nivel = row.nivel_educativo || 'desconocido';
    porNivel[nivel] = (porNivel[nivel] || 0) + 1;

    const grado = row.grado || 'desconocido';
    porGrado[grado] = (porGrado[grado] || 0) + 1;
  });

  res.status(200).json({
    total: rows.length,
    por_estado: porEstado,
    por_nivel: porNivel,
    por_grado: porGrado,
  });
};
