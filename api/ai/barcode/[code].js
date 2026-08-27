module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';
  if (!SUPABASE_URL || !SUPABASE_KEY) return res.status(500).json({ found: false, products: [], source: 'error', message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY' });
  const code = (req.query?.code || req.query?.slug || '').toString().trim() || decodeURIComponent((req.url.split('/').pop() || '').split('?')[0]);
  if (!code || code === 'barcode' || code === '[code]') {
    // Fallback: try to extract from url path /api/ai/barcode/123
    const parts = (req.url || '').split('?')[0].split('/');
    const last = parts[parts.length - 1] || '';
    if (last && last !== 'barcode' && last !== '[code]') {
      // use last
    } else {
      return res.status(400).json({ found: false, products: [], source: 'error', message: 'Falta código de barras' });
    }
  }
  const barcode = decodeURIComponent((req.query?.code || code || '').toString().trim());
  if (!barcode) return res.status(400).json({ found: false, products: [], source: 'error', message: 'Falta código de barras' });
  try {
    const url = `${SUPABASE_URL}/rest/v1/productos?codigo=eq.${encodeURIComponent(barcode)}&select=*&limit=10`;
    const r = await fetch(url, { headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, 'Content-Type': 'application/json' } });
    const text = await r.text();
    if (r.status >= 400) return res.status(502).json({ found: false, products: [], source: 'supabase', message: text });
    const rows = JSON.parse(text || '[]');
    if (Array.isArray(rows) && rows.length > 0) return res.status(200).json({ found: true, products: rows, source: 'supabase' });
    return res.status(200).json({ found: false, products: [], source: 'supabase', message: 'No encontrado en catálogo' });
  } catch (e) {
    return res.status(500).json({ found: false, products: [], source: 'error', message: e.message });
  }
};
