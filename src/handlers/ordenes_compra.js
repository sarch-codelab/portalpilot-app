const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('./_lib/supabase');

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
        `/ordenes_compra?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500`
      );
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const orden = body.orden_compra || body.orden || null;
      if (!empresaCodigo || !orden) return fail(res, { message: 'Falta empresa_codigo o orden.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo);

      const payload = {
        empresa_codigo: empresaCodigo,
        correlativo: (orden.correlativo || null),
        proveedor_id: (orden.proveedor_id || orden.proveedorId || null),
        proveedor_nombre: (orden.proveedor_nombre || orden.proveedorNombre || null),
        cotizacion_id: (orden.cotizacion_id || orden.cotizacionId || null),
        fecha: orden.fecha || new Date().toISOString(),
        fecha_entrega: orden.fecha_entrega || orden.fechaEntrega || null,
        estado: (orden.estado || 'borrador'),
        subtotal: Number(orden.subtotal || 0),
        isv15: Number(orden.isv15 || 0),
        isv18: Number(orden.isv18 || 0),
        descuento: Number(orden.descuento || 0),
        total: Number(orden.total || 0),
        notas: orden.notas || null,
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/ordenes_compra', { method: 'POST', body: JSON.stringify([payload]) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};