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
        `/cotizaciones?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500`
      );
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const cotizacion = body.cotizacion || null;
      if (!empresaCodigo || !cotizacion) return fail(res, { message: 'Falta empresa_codigo o cotizacion.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo);

      const payload = {
        empresa_codigo: empresaCodigo,
        correlativo: (cotizacion.correlativo || null),
        proveedor_id: (cotizacion.proveedor_id || cotizacion.proveedorId || null),
        proveedor_nombre: (cotizacion.proveedor_nombre || cotizacion.proveedorNombre || null),
        fecha: cotizacion.fecha || new Date().toISOString(),
        validez_dias: Number(cotizacion.validez_dias || cotizacion.validezDias || 30),
        estado: (cotizacion.estado || 'borrador'),
        subtotal: Number(cotizacion.subtotal || 0),
        isv15: Number(cotizacion.isv15 || 0),
        isv18: Number(cotizacion.isv18 || 0),
        descuento: Number(cotizacion.descuento || 0),
        total: Number(cotizacion.total || 0),
        notas: cotizacion.notas || null,
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/cotizaciones', { method: 'POST', body: JSON.stringify([payload]) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};