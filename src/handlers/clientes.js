const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('./_lib/supabase');

// GET /api/clientes?empresaCodigo=PP-123456
// POST /api/clientes  { empresa_codigo, cliente: {...} }
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = req.query?.empresaCodigo || '';
      if (!empresaCodigo) return ok(res, []);

      const result = await supabaseRequest(
        `/clientes?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=200`
      );
      if (result.status >= 400) {
        const all = await supabaseRequest('/clientes?select=id,empresa_id,nombre,rtn,direccion,telefono,email&limit=500');
        if (all.status >= 400) return fail(res, { message: all.body });
        const rows = JSON.parse(all.body || '[]');
        const empresas = await supabaseRequest('/empresas?select=id,codigo');
        let mapa = {};
        try {
          const empRows = JSON.parse(empresas.body || '[]');
          empRows.forEach((e) => (mapa[e.id] = e.codigo));
        } catch {}
        return ok(res, rows.filter((r) => mapa[r.empresa_id] === empresaCodigo));
      }
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const c = body.cliente || body;
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo); // best-effort, puede ser null

      const payload = {
        empresa_codigo: empresaCodigo,
        nombre: c.nombre || '',
        rtn: c.rtn || null,
        direccion: c.direccion || null,
        telefono: c.telefono || null,
        email: c.email || null,
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/clientes', { method: 'POST', body: JSON.stringify(payload) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    if (req.method === 'DELETE') {
      const id = req.query?.id || '';
      if (!id) return fail(res, { message: 'Falta id.', status: 400 });
      const result = await supabaseRequest(`/clientes?id=eq.${encodeURIComponent(id)}`, { method: 'DELETE' });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true });
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};
