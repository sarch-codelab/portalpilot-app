const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('../_lib/supabase');

// POST /api/ventas  { empresa_codigo, venta: { fecha, items:[{nombre,precio,cantidad,codigo}], total, metodo_pago } }
// Cierra la venta POS: crea la factura y descuenta stock de productos.
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    const body = parseBody(req);
    const empresaCodigo = body.empresa_codigo || '';
    const venta = body.venta || {};
    const items = Array.isArray(venta.items) ? venta.items : [];
    if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
    if (items.length === 0) return fail(res, { message: 'La venta no tiene items.', status: 400 });

    const empresaId = await resolverEmpresaId(empresaCodigo); // best-effort, puede ser null

    const decrementados = [];
    const errores = [];

    // 1. Descuento de stock por item
    for (const item of items) {
      const codigo = (item.codigo || '').toString();
      const nombre = (item.nombre || '').toString();
      const cantidad = Number(item.cantidad) || 1;

      const filtroTenant = empresaId
        ? `empresa_id=eq.${empresaId}`
        : `empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`;
      const match = await supabaseRequest(
        `/productos?${filtroTenant}&or=(codigo.eq.${encodeURIComponent(codigo)},nombre.eq.${encodeURIComponent(nombre)})&select=id,stock_actual,codigo,nombre`
      );
      if (match.status >= 400) { errores.push(nombre); continue; }
      let rows = [];
      try { rows = JSON.parse(match.body || '[]'); } catch {}
      const prod = rows[0];
      if (!prod) { errores.push(nombre); continue; }

      const nuevoStock = Math.max(0, (Number(prod.stock_actual) || 0) - cantidad);
      await supabaseRequest(`/productos?id=eq.${prod.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ stock_actual: nuevoStock, updated_at: new Date().toISOString() }),
      });
      decrementados.push({ id: prod.id, codigo: prod.codigo, nombre: prod.nombre, nuevoStock });
    }

    // 2. Registrar factura de venta
    const ahora = new Date();
    const correlativo = `POS-${ahora.getFullYear()}${String(ahora.getMonth() + 1).padStart(2, '0')}${String(ahora.getDate()).padStart(2, '0')}-${String(ahora.getHours()).padStart(2, '0')}${String(ahora.getMinutes()).padStart(2, '0')}${String(ahora.getSeconds()).padStart(2, '0')}`;

    const facturaPayload = {
      empresa_codigo: empresaCodigo,
      correlativo,
      tipo_documento: 'Factura',
      cai: 'POS-DIRECTO',
      cliente_nombre: venta.cliente_nombre || 'Consumidor Final',
      cliente_rtn: venta.cliente_rtn || 'CF',
      condicion_pago: 'Contado',
      tipo_venta: 'Gravada',
      items,
      subtotal: Number(venta.subtotal) || 0,
      isv_15: Number(venta.isv_15) || 0,
      isv_18: Number(venta.isv_18) || 0,
      descuento: Number(venta.descuento) || 0,
      total: Number(venta.total) || items.reduce((s, i) => s + (Number(i.precio) || 0) * (Number(i.cantidad) || 1), 0),
      estado: 'pagada',
      notas: `Pago: ${venta.metodo_pago || 'efectivo'}`,
    };
    if (empresaId) facturaPayload.empresa_id = empresaId;

    const facturaRes = await supabaseRequest('/facturas', { method: 'POST', body: JSON.stringify(facturaPayload) });
    if (facturaRes.status >= 400) return fail(res, { message: facturaRes.body });

    return ok(res, {
      success: true,
      correlativo,
      decrementados,
      errores,
      factura: JSON.parse(facturaRes.body),
    }, 201);
  } catch (err) {
    return fail(res, err);
  }
};
