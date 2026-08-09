const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('../_lib/supabase');

// GET /api/notas?empresaCodigo=PP-123456&clave=...
// POST /api/notas  { empresa_codigo, clave, datos: {...} }  -> upsert del estado completo de notas
// Guarda el estado completo (rubricas/calificaciones por alumno) en la tabla notas_estado (JSONB).
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = req.query?.empresaCodigo || '';
      const clave = req.query?.clave || '';
      if (!empresaCodigo) return ok(res, []);

      let url = `/notas_estado?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`;
      if (clave) url += `&clave=eq.${encodeURIComponent(clave)}`;
      url += '&order=updated_at.desc&limit=100';

      const result = await supabaseRequest(url);
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const clave = (body.clave || '').toString();
      const datos = body.datos || {};
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      if (!clave) return fail(res, { message: 'Falta clave.', status: 400 });

      const empresaId = await resolverEmpresaId(empresaCodigo); // best-effort, puede ser null

      const existing = await supabaseRequest(
        `/notas_estado?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&clave=eq.${encodeURIComponent(clave)}&select=id`
      );
      const rows = existing.status < 400 ? JSON.parse(existing.body || '[]') : [];
      const payload = { empresa_codigo: empresaCodigo, clave, datos, updated_at: new Date().toISOString() };
      if (empresaId) payload.empresa_id = empresaId;

      let result;
      if (rows.length > 0) {
        result = await supabaseRequest(`/notas_estado?id=eq.${rows[0].id}`, {
          method: 'PATCH',
          body: JSON.stringify(payload),
        });
      } else {
        result = await supabaseRequest('/notas_estado', { method: 'POST', body: JSON.stringify(payload) });
      }
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};
