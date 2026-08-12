const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('./_lib/supabase');

// GET /api/facturas?empresaCodigo=PP-123456
// POST /api/facturas  { empresa_codigo, factura: {...} }
// PATCH /api/facturas/:id  { estado: 'anulada', motivo_anulacion }
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = req.query?.empresaCodigo || '';
      if (!empresaCodigo) return ok(res, []);

      const result = await supabaseRequest(
        `/facturas?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=200`
      );
      if (result.status >= 400) {
        const all = await supabaseRequest('/facturas?select=id,empresa_id,correlativo,tipo_documento,cliente_nombre,cliente_rtn,cliente_direccion,condicion_pago,tipo_venta,items,subtotal,isv_15,isv_18,descuento,total,estado,cai,created_at&limit=500');
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
      const f = body.factura || body;
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo); // best-effort, puede ser null

      const payload = {
        empresa_codigo: empresaCodigo,
        correlativo: f.correlativo || '',
        tipo_documento: f.tipo_documento || 'Factura',
        cai: f.cai || '',
        cliente_nombre: f.cliente_nombre || null,
        cliente_rtn: f.cliente_rtn || null,
        cliente_direccion: f.cliente_direccion || null,
        condicion_pago: f.condicion_pago || 'Contado',
        tipo_venta: f.tipo_venta || 'Gravada',
        items: f.items || [],
        subtotal: f.subtotal || 0,
        isv_15: f.isv_15 || 0,
        isv_18: f.isv_18 || 0,
        descuento: f.descuento || 0,
        total: f.total || 0,
        estado: f.estado || 'emitida',
        notas: f.notas || null,
      };
      if (empresaId) payload.empresa_id = empresaId;

      const result = await supabaseRequest('/facturas', { method: 'POST', body: JSON.stringify(payload) });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    if (req.method === 'PATCH') {
      const id = (req.query?.id || req.params?.id || '').toString();
      const body = parseBody(req);
      const update = { updated_at: new Date().toISOString() };
      if (body.estado !== undefined) update.estado = body.estado;
      if (body.motivo_anulacion !== undefined) update.motivo_anulacion = body.motivo_anulacion;
      if (body.fecha_anulacion !== undefined) update.fecha_anulacion = body.fecha_anulacion;

      const result = await supabaseRequest(`/facturas?id=eq.${encodeURIComponent(id)}`, {
        method: 'PATCH',
        body: JSON.stringify(update),
      });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) });
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};
