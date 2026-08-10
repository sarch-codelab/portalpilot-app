const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('../_lib/supabase');

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
        `/proveedores?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500`
      );
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const proveedor = body.proveedor || null;
      if (!empresaCodigo || !proveedor) return fail(res, { message: 'Falta empresa_codigo o proveedor.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo);

      const payload = {
        empresa_codigo: empresaCodigo,
        nombre: (proveedor.nombre || '').toString().slice(0, 120),
        contacto: (proveedor.contacto || null),
        telefono: (proveedor.telefono || null),
        email: (proveedor.email || null),
        direccion: (proveedor.direccion || null),
        rtn: (proveedor.rtn || null),
        condiciones_pago: Number(proveedor.condiciones_pago || proveedor.condicionesPago || 30),
        notas: (proveedor.notas || null),
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/proveedores', { method: 'POST', body: JSON.stringify([payload]) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};