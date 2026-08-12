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
        `/compras?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500`
      );
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const compra = body.compra || null;
      if (!empresaCodigo || !compra) return fail(res, { message: 'Falta empresa_codigo o compra.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo);

      const payload = {
        empresa_codigo: empresaCodigo,
        correlativo: (compra.correlativo || null),
        proveedor_id: (compra.proveedor_id || compra.proveedorId || null),
        proveedor_nombre: (compra.proveedor_nombre || compra.proveedorNombre || null),
        orden_compra_id: (compra.orden_compra_id || compra.ordenCompraId || null),
        numero_factura: (compra.numero_factura || compra.numeroFactura || null),
        fecha: compra.fecha || new Date().toISOString(),
        fecha_vencimiento: compra.fecha_vencimiento || compra.fechaVencimiento || null,
        estado: (compra.estado || 'pendiente'),
        subtotal: Number(compra.subtotal || 0),
        isv15: Number(compra.isv15 || 0),
        isv18: Number(compra.isv18 || 0),
        descuento: Number(compra.descuento || 0),
        total: Number(compra.total || 0),
        notas: compra.notas || null,
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/compras', { method: 'POST', body: JSON.stringify([payload]) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};