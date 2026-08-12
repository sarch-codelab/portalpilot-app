const { configured, supabaseRequest, resolverEmpresaId, parseBody, ok, fail } = require('./_lib/supabase');

// GET /api/productos?empresaCodigo=PP-123456
// POST /api/productos  { empresa_codigo, productos: [...] }  -> upsert masivo (stock/precios)
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
        `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500`
      );
      if (result.status >= 400) {
        const all = await supabaseRequest('/productos?select=id,empresa_id,codigo,nombre,descripcion,categoria,precio_venta,stock_actual,stock_minimo&limit=500');
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
      const productos = Array.isArray(body.productos) ? body.productos : [];
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo); // best-effort, puede ser null

      const payloads = productos.map((p) => {
        const cant = Number(p.cantidad);
        const stock = Number(p.stock_actual);
        const stockActual = Number.isFinite(cant) ? cant : (Number.isFinite(stock) ? stock : 0);
        return {
          empresa_codigo: empresaCodigo,
          codigo: (p.codigo || '').toString().slice(0, 40),
          nombre: (p.nombre || '').toString().slice(0, 120),
          descripcion: (p.descripcion || null)?.toString().slice(0, 200) || null,
          categoria: (p.categoria || null)?.toString().slice(0, 60) || null,
          precio_compra: Number(p.precio_compra) || 0,
          precio_venta: Number(p.precio) || Number(p.precio_venta) || 0,
          stock_minimo: Number(p.stock_minimo) || 0,
          stock_actual: stockActual,
          bodega: (p.bodega || 'General').toString().slice(0, 60),
          isv_rate: Number(p.isv_rate) || 15,
        };
      });
      payloads.forEach((p) => {
        if (empresaId) p.empresa_id = empresaId;
      });

      // Upsert por (empresa_codigo, codigo): requiere índice único
      // idx_productos_empresa_codigo_codigo (ver migración). Si el índice
      // aún no existe (error de constraint), cae a insert simple.
      let result;
      try {
        result = await supabaseRequest(
          '/productos?on_conflict=empresa_codigo,codigo',
          {
            method: 'POST',
            body: JSON.stringify(payloads),
            headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
          }
        );
      } catch (e) {
        result = { status: 0, body: '' };
      }
      if (result.status >= 400) {
        result = await supabaseRequest('/productos', { method: 'POST', body: JSON.stringify(payloads) });
      }
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    if (req.method === 'DELETE') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const codigo = (body.codigo || '').toString();
      if (!empresaCodigo || !codigo) {
        return fail(res, { message: 'Faltan empresa_codigo y codigo.', status: 400 });
      }
      const result = await supabaseRequest(
        `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&codigo=eq.${encodeURIComponent(codigo)}`,
        { method: 'DELETE' }
      );
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true }, 200);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
};
