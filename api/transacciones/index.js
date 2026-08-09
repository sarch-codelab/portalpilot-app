const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('../_lib/supabase');

// GET /api/transacciones?empresaCodigo=PP-123456
// POST /api/transacciones  { empresa_codigo, transaccion: {...} }
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = req.query?.empresaCodigo || '';
      if (!empresaCodigo) return ok(res, []);

      const result = await supabaseRequest(
        `/transacciones?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=fecha.desc&limit=200`
      );
      if (result.status >= 400) {
        const all = await supabaseRequest('/transacciones?select=id,empresa_id,tipo,categoria,descripcion,monto,metodo_pago,referencia,fecha&limit=500');
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
      const t = body.transaccion || body;
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo); // best-effort, puede ser null

      const payload = {
        empresa_codigo: empresaCodigo,
        tipo: t.tipo || 'ingreso',
        categoria: t.categoria || null,
        descripcion: t.descripcion || '',
        monto: t.monto || 0,
        metodo_pago: t.metodo_pago || 'otro',
        referencia: t.referencia || null,
        fecha: t.fecha || new Date().toISOString(),
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/transacciones', { method: 'POST', body: JSON.stringify(payload) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};
