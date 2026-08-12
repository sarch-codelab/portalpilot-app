// Helper compartido: acceso a Supabase REST (server-side) con service role key.
// Mismo patrón que api/matriculas. Usado por los endpoints de sync de la app.

const SUPABASE_URL = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';

function configured() {
  return Boolean(SUPABASE_URL && KEY);
}

async function supabaseRequest(path, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      apikey: KEY,
      Authorization: `Bearer ${KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  return { status: response.status, body: text };
}

// Resuelve empresa_codigo (texto) → empresa_id (UUID) contra la tabla empresas.
// Best-effort: si la tabla no existe (42P01) o no hay match, devuelve null.
// Los endpoints operan por `empresa_codigo` (columna de tenant, sin FK), de modo
// que una empresa no resuelta NO debe bloquear la escritura.
async function resolverEmpresaId(empresaCodigo) {
  if (!empresaCodigo) return null;
  try {
    const result = await supabaseRequest(
      `/empresas?codigo=eq.${encodeURIComponent(empresaCodigo)}&select=id&limit=1`
    );
    if (result.status >= 400) return null;
    const rows = JSON.parse(result.body || '[]');
    return rows[0]?.id || null;
  } catch {
    return null;
  }
}

function parseBody(req) {
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  return body;
}

function ok(res, data, status = 200) {
  res.status(status).json(data);
}

function fail(res, err) {
  const code = Number.isInteger(err?.status) ? err.status : 500;
  res.status(code).json({ error: err?.message || 'Error interno del servidor.' });
}

module.exports = {
  configured,
  supabaseRequest,
  resolverEmpresaId,
  parseBody,
  ok,
  fail,
};
