// Despachador único de la API móvil (plan Hobby: máx 12 funciones).
// El handler de login está integrado directamente para evitar problemas de despliegue.

const routes = {
  'login': loginHandler,
  'ai/groq': aiGroqHandler,
  'ai/chat': aiChatHandler,
  'ai/vision': aiVisionHandler,
  'ai/barcode': aiBarcodeHandler,
  'ai/dashboard': aiDashboardHandler,
  'ai/pos/analyze': aiPosAnalyzeHandler,
  'ai/crm/customer': aiCrmHandler,
  'ai/support': aiSupportHandler,
  'clientes': clientesHandler,
  'compras': comprasHandler,
  'cotizaciones': cotizacionesHandler,
  'facturas': facturasHandler,
  'matriculas': matriculasHandler,
  'matriculas/stats': matriculasStatsHandler,
  'notas': notasHandler,
  'ordenes-compra': ordenesCompraHandler,
  'productos': productosHandler,
  'proveedores': proveedoresHandler,
  'storage': storageHandler,
  'sync': syncHandler,
  'transacciones': transaccionesHandler,
  'ventas': ventasHandler,
};

module.exports = async function handler(req, res) {
  const pathname = req.url
    .split('?')[0]
    .replace(/^\/api\//, '')
    .replace(/\/+$/, '');

  // Soporte para rutas dinámicas con prefijo (ej: ai/barcode/12345)
  let route = routes[pathname];
  if (!route && pathname.startsWith('ai/barcode/')) {
    route = aiBarcodeHandler;
  }
  if (!route) {
    return res.status(404).json({ error: `Ruta no encontrada: /api/${pathname}` });
  }
  return route(req, res);
};

// ═══════════════════════════════════════════════════════════════
// Handler de Login (integrado para evitar problemas de despliegue)
// ═══════════════════════════════════════════════════════════════

function loginHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  // ── Parsear body ──────────────────────────────────────────────────────────
  const parseBody = (value) => {
    if (!value) return {};
    if (Buffer.isBuffer(value)) {
      try { return JSON.parse(value.toString('utf-8')); } catch { return {}; }
    }
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch { return {}; }
    }
    if (typeof value === 'object') return value;
    return {};
  };

  const body = parseBody(req.body);
  const email = (body.email || '').trim().toLowerCase();
  const password = (body.password || '').toString().trim();

  if (!email || !password) {
    res.status(400).json({ error: 'Email y contraseña son requeridos.' });
    return;
  }

  const jwt = require('jsonwebtoken');
  const bcrypt = require('bcryptjs');

  const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY || '';
  const jwtSecret = process.env.JWT_SECRET || 'portalpilot_production_jwt_secret_key_2026_secure';

  if (!supabaseUrl || !supabaseKey) {
    return res.status(503).json({ error: 'Supabase no está configurado en las variables de entorno de Vercel (SUPABASE_URL / SUPABASE_SERVICE_KEY).' });
  }

  const restBase = `${supabaseUrl}/rest/v1`;
  const headers = {
    apikey: supabaseKey,
    Authorization: `Bearer ${supabaseKey}`,
    'Content-Type': 'application/json'
  };

  fetch(`${restBase}/usuarios?email=eq.${encodeURIComponent(email)}&select=*`, { headers })
    .then(r => r.json())
    .then(async (rows) => {
      const user = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
      if (!user) {
        return res.status(401).json({ error: 'Credenciales inválidas. Usuario no registrado.' });
      }

      let isMatch = false;
      const storedHash = user.password_hash || user.password;
      if (storedHash) {
        if (storedHash.startsWith('$2')) {
          isMatch = await bcrypt.compare(password, storedHash);
        } else {
          isMatch = (password === storedHash);
        }
      }

      if (!isMatch) {
        return res.status(401).json({ error: 'Contraseña incorrecta.' });
      }

      // Lookup tenant data (area, plan) — same as web portal
      let tenantData = null;
      if (user.empresa_codigo) {
        try {
          const tenantRes = await fetch(
            `${restBase}/tenants?codigo=eq.${encodeURIComponent(user.empresa_codigo)}&select=*`,
            { headers }
          );
          const tenantRows = await tenantRes.json();
          if (Array.isArray(tenantRows) && tenantRows.length > 0) {
            tenantData = tenantRows[0];
          }
        } catch (_) {}
      }

      const userArea = tenantData?.area || user.area || 'Área Comercial';
      const userPlan = tenantData?.plan || 'pro';

      const token = jwt.sign(
        {
          sub: user.id,
          email: user.email,
          rol: user.rol || 'admin',
          empresa_codigo: user.empresa_codigo || 'ROOT'
        },
        jwtSecret,
        { expiresIn: '30d' }
      );

      res.status(200).json({
        message: 'Login exitoso',
        token: token,
        user: {
          id: user.id,
          nombre: user.nombre || '',
          apellido: user.apellido || '',
          email: user.email,
          rol: user.rol || 'admin',
          empresa_codigo: user.empresa_codigo || 'ROOT',
          tenant: user.empresa_codigo || 'ROOT',
          area: userArea,
          plan: userPlan,
          status: user.estado || 'activo',
          foto_perfil_url: user.avatar_url || user.foto_perfil_url || null,
          token: token
        }
      });
    })
    .catch((err) => {
      console.error('[login] Error consultando Supabase:', err.message);
      res.status(500).json({ error: 'Error al conectar con la base de datos Supabase.' });
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// Comparación de contraseñas: soporta bcrypt y texto plano
// ─────────────────────────────────────────────────────────────────────────────
async function comparePassword(inputPassword, storedPassword) {
  if (!storedPassword) return false;
  
  // Verificar si la contraseña almacenada es un hash bcrypt
  if (storedPassword.startsWith('$2b$') || storedPassword.startsWith('$2a$') || storedPassword.startsWith('$2y$')) {
    try {
      // bcrypt está disponible en Node.js serverless de Vercel
      const bcrypt = require('bcryptjs');
      return await bcrypt.compare(inputPassword, storedPassword);
    } catch {
      // Si bcryptjs no está disponible, comparar como texto plano
      console.warn('[login] bcryptjs no disponible, comparando texto plano');
      return inputPassword === storedPassword;
    }
  }
  
  // Comparación de texto plano (sin hashing)
  return inputPassword === storedPassword;
}

// ═══════════════════════════════════════════════════════════════
// Helper functions para Supabase
// ═══════════════════════════════════════════════════════════════

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';

function configured() {
  return Boolean(SUPABASE_URL && SUPABASE_KEY);
}

async function supabaseRequest(path, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  return { status: response.status, body: text };
}

async function resolverEmpresaId(empresaCodigo) {
  if (!empresaCodigo) return null;
  try {
    const result = await supabaseRequest(
      `/empresas?codigo=eq.${encodeURIComponent(empresaCodigo)}&select=id&limit=1`
    );
    if (result.status >= 400) return null;
    const rows = JSON.parse(result.body || '[]');
    return rows[0]?.id || null;
  } catch {
    return null;
  }
}

function parseBody(req) {
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  return body;
}

function ok(res, data, status = 200) {
  res.status(status).json(data);
}

function fail(res, err) {
  const code = Number.isInteger(err?.status) ? err.status : 500;
  res.status(code).json({ error: err?.message || 'Error interno del servidor.' });
}

// ═══════════════════════════════════════════════════════════════
// AI Groq Handler
// ═══════════════════════════════════════════════════════════════

function aiGroqHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  const key = process.env.GROQ_API_KEY;
  if (!key) {
    res.status(500).json({
      error: 'Falta GROQ_API_KEY en Vercel. Configúralo en Project Settings → Environment Variables.',
    });
    return;
  }

  const body = parseBody(req);
  fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: body.modelId || 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: body.systemPrompt || 'Eres un asistente útil.' },
        { role: 'user', content: body.prompt || '' },
      ],
      max_tokens: body.maxTokens || 1500,
      temperature: body.temperature || 0.7,
    }),
  })
    .then(response => response.json())
    .then(data => {
      if (!data.ok) {
        res.status(data.status).json({
          success: false,
          error: data.error?.message || 'Error al consultar Groq',
        });
        return;
      }

      const content = data.choices?.[0]?.message?.content || '';
      res.status(200).json({
        success: true,
        text: content,
        modelId: body.modelId || 'llama-3.3-70b-versatile',
        provider: 'groq',
        tokensUsed: data.usage?.total_tokens || 0,
      });
    })
    .catch(err => {
      res.status(500).json({ error: err.message });
    });
}

// ═══════════════════════════════════════════════════════════════
// AI Gateway handlers (vision, chat, barcode, dashboard...)
// ═══════════════════════════════════════════════════════════════

function aiChatHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  const body = parseBody(req);
  const message = body.message || body.prompt || body.query || '';
  const systemPrompt = body.systemPrompt || 'Eres un asistente útil de Portal Pilot.';
  if (!message) return res.status(400).json({ error: 'Falta message', reply: null });
  fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: body.model || body.modelId || 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: message },
      ],
      max_tokens: body.maxTokens || 1500,
      temperature: body.temperature ?? 0.7,
    }),
  })
    .then(async (r) => {
      const data = await r.json();
      if (!r.ok || !data.choices) {
        return res.status(r.status || 502).json({ error: data.error?.message || 'Error Groq', reply: null, details: data });
      }
      const reply = data.choices?.[0]?.message?.content || '';
      return res.status(200).json({ reply, model: data.model || body.model, provider: 'groq', usage: data.usage });
    })
    .catch((err) => res.status(500).json({ error: err.message, reply: null }));
}

function aiVisionHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  const body = parseBody(req);
  let image = body.image || body.base64 || '';
  const prompt = body.prompt || 'Identifica este producto y devuelve un JSON con: nombre, marca, categoria, descripcion, presentacion, unidad_medida, confianza (0-1). Si no puedes determinar algo, deja el campo como null. Responde SOLO con el JSON.';
  if (!image) return res.status(400).json({ error: 'Falta image (base64)', reply: null });
  if (!image.startsWith('data:')) image = `data:image/jpeg;base64,${image.replace(/\s+/g, '')}`;
  fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: body.model || 'meta-llama/llama-4-scout-17b-16e-instruct',
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { type: 'image_url', image_url: { url: image } },
          ],
        },
      ],
      max_tokens: body.maxTokens || 800,
      temperature: 0.2,
    }),
  })
    .then(async (r) => {
      const data = await r.json();
      if (!r.ok || !data.choices) {
        return res.status(r.status || 502).json({ error: data.error?.message || 'Error Groq Vision', reply: null, details: data });
      }
      const reply = data.choices?.[0]?.message?.content || '';
      return res.status(200).json({ reply, model: data.model || 'meta-llama/llama-4-scout-17b-16e-instruct', provider: 'groq', usage: data.usage });
    })
    .catch((err) => res.status(500).json({ error: err.message, reply: null }));
}

async function aiBarcodeHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  // Extraer código de la ruta ai/barcode/<code> o query ?code=
  const urlParts = (req.url || '').split('?')[0].split('/');
  let code = urlParts[urlParts.length - 1] || '';
  if (!code || code === 'barcode') code = (req.query?.code || '').toString();
  code = decodeURIComponent((code || '').toString().trim());
  if (!code) return res.status(400).json({ found: false, products: [], source: 'error', message: 'Falta código de barras' });
  try {
    const result = await supabaseRequest(`/productos?codigo=eq.${encodeURIComponent(code)}&select=*&limit=10`);
    if (result.status >= 400) return res.status(502).json({ found: false, products: [], source: 'supabase', message: result.body });
    const rows = JSON.parse(result.body || '[]');
    if (Array.isArray(rows) && rows.length > 0) {
      return ok(res, { found: true, products: rows, source: 'supabase' });
    }
    // Fallback sin empresa_codigo: busca global
    return ok(res, { found: false, products: [], source: 'supabase', message: 'No encontrado en catálogo' });
  } catch (e) {
    return res.status(500).json({ found: false, products: [], source: 'error', message: e.message });
  }
}

function aiDashboardHandler(req, res) { return aiChatHandler(req, res); }
function aiPosAnalyzeHandler(req, res) { return aiChatHandler(req, res); }
function aiCrmHandler(req, res) { return aiChatHandler(req, res); }
function aiSupportHandler(req, res) { return aiChatHandler(req, res); }

// ═══════════════════════════════════════════════════════════════
// Placeholder handlers para otros endpoints
// ═══════════════════════════════════════════════════════════════

async function clientesHandler(req, res) {
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
        `/clientes?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=200`
      );
      if (result.status >= 400) {
        const all = await supabaseRequest('/clientes?select=id,empresa_id,nombre,rtn,direccion,telefono,email&limit=500');
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
      const c = body.cliente || body;
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      const empresaId = await resolverEmpresaId(empresaCodigo);

      const payload = {
        empresa_codigo: empresaCodigo,
        nombre: c.nombre || '',
        dni: c.dni || null,
        rtn: c.rtn || null,
        direccion: c.direccion || null,
        telefono: c.telefono || null,
        email: c.email || null,
      };
      if (empresaId) payload.empresa_id = empresaId;

      let result = await supabaseRequest('/clientes', { method: 'POST', body: JSON.stringify(payload) });
      // Si la columna dni aún no existe en la BD (migración pendiente), reintentar sin ella.
      if (result.status >= 400 && payload.dni != null && String(result.body || '').includes('dni')) {
        const fallback = { ...payload };
        delete fallback.dni;
        result = await supabaseRequest('/clientes', { method: 'POST', body: JSON.stringify(fallback) });
      }
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true, data: JSON.parse(result.body) }, 201);
    }

    if (req.method === 'DELETE') {
      const id = req.query?.id || '';
      if (!id) return fail(res, { message: 'Falta id.', status: 400 });
      const result = await supabaseRequest(`/clientes?id=eq.${encodeURIComponent(id)}`, { method: 'DELETE' });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true });
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

function comprasHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

function cotizacionesHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

async function facturasHandler(req, res) {
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
      const empresaId = await resolverEmpresaId(empresaCodigo);

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
}

function matriculasHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

function matriculasStatsHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

function notasHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

function ordenesCompraHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

async function productosHandler(req, res) {
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
        `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500&select=*`
      );
      if (result.status >= 400) {
        const all = await supabaseRequest('/productos?select=*&limit=500');
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
      const empresaId = await resolverEmpresaId(empresaCodigo);

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
          imagen_url: p.imagen_url || p.imagenUrl || null,
        };
      });
      payloads.forEach((p) => {
        if (empresaId) p.empresa_id = empresaId;
      });

      // Upsert manual idempotente por (empresa_codigo, codigo):
      // el on_conflict requiere un constraint UNIQUE que aún no existe en la tabla.
      const results = [];
      const errores = [];
      for (const payload of payloads) {
        const codigo = payload.codigo;
        if (!codigo) {
          const r = await supabaseRequest('/productos', { method: 'POST', body: JSON.stringify(payload) });
          if (r.status >= 400) { errores.push(r.body); continue; }
          const inserted = JSON.parse(r.body || '[]');
          results.push(...(Array.isArray(inserted) ? inserted : [inserted]));
          continue;
        }

        const filtro = `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&codigo=eq.${encodeURIComponent(codigo)}&select=id`;
        const existing = await supabaseRequest(filtro);
        let rows = [];
        try { rows = JSON.parse(existing.body || '[]'); } catch {}

        if (existing.status < 400 && rows.length > 0) {
          const { id: _ignored, ...update } = payload;
          const r = await supabaseRequest(`/productos?id=eq.${encodeURIComponent(rows[0].id)}`, {
            method: 'PATCH',
            body: JSON.stringify({ ...update, updated_at: new Date().toISOString() }),
          });
          if (r.status >= 400) { errores.push(r.body); continue; }
          results.push({ id: rows[0].id, ...payload });
        } else {
          const r = await supabaseRequest('/productos', { method: 'POST', body: JSON.stringify(payload) });
          if (r.status >= 400) { errores.push(r.body); continue; }
          const inserted = JSON.parse(r.body || '[]');
          results.push(...(Array.isArray(inserted) ? inserted : [inserted]));
        }
      }

      if (results.length === 0 && errores.length > 0) {
        return fail(res, { message: errores.join(' | ') });
      }
      return ok(res, { success: true, data: results, errores }, 201);
    }

    if (req.method === 'DELETE') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      const codigo = (body.codigo || '').toString();
      if (!empresaCodigo || !codigo) {
        return fail(res, { message: 'Faltan empresa_codigo y codigo.', status: 400 });
      }
      
      // Primero intentar buscar por empresa_codigo y codigo
      let result = await supabaseRequest(
        `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&codigo=eq.${encodeURIComponent(codigo)}`,
        { method: 'DELETE' }
      );
      
      // Si falla, intentar por empresa_id
      if (result.status >= 400) {
        const empresaId = await resolverEmpresaId(empresaCodigo);
        if (empresaId) {
          result = await supabaseRequest(
            `/productos?empresa_id=eq.${empresaId}&codigo=eq.${encodeURIComponent(codigo)}`,
            { method: 'DELETE' }
          );
        }
      }
      
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true }, 200);
    }

    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

function proveedoresHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

function transaccionesHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  
  res.status(501).json({ error: 'Endpoint en desarrollo' });
}

async function ventasHandler(req, res) {
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
    if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });

    const empresaId = await resolverEmpresaId(empresaCodigo);
    const resultado = await procesarVentaSync(empresaCodigo, empresaId, [venta]);

    if (resultado.ok === 0 && resultado.errores.length > 0) {
      return fail(res, { message: resultado.errores.join(' | '), status: 502 });
    }
    return ok(res, {
      success: true,
      correlativo: resultado.correlativos[0] || null,
      decrementados: resultado.decrementados,
      errores: resultado.errores,
    }, 201);
  } catch (err) {
    return fail(res, err);
  }
}

/// Procesa una o varias ventas POS de forma idempotente:
/// - Si la factura ya existe por correlativo, no re-decrementa stock.
/// - Decrementa stock de cada item y registra la factura de venta.
async function procesarVentaSync(empresaCodigo, empresaId, ventas) {
  const decrementados = [];
  const errores = [];
  const correlativos = [];
  let ok = 0;

  const filtroTenant = empresaId
    ? `empresa_id=eq.${empresaId}`
    : `empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`;

  for (const venta of ventas) {
    try {
      if (typeof venta !== 'object' || venta === null) continue;
      const items = Array.isArray(venta.items) ? venta.items : [];
      const correlativo = String(venta.correlativo || '');

      // Idempotencia: si la venta ya fue registrada, se omite.
      if (correlativo) {
        const ex = await supabaseRequest(
          `/facturas?correlativo=eq.${encodeURIComponent(correlativo)}&select=id`
        );
        if (ex.status < 400) {
          let found = [];
          try { found = JSON.parse(ex.body || '[]'); } catch {}
          if (found.length > 0) { ok++; correlativos.push(correlativo); continue; }
        }
      }

      // 1. Descuento de stock por item
      for (const item of items) {
        const codigo = (item.codigo || '').toString();
        const nombre = (item.nombre || '').toString();
        const cantidad = Number(item.cantidad) || 1;

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
      const correlativoFinal = correlativo ||
        `POS-${ahora.getFullYear()}${String(ahora.getMonth() + 1).padStart(2, '0')}${String(ahora.getDate()).padStart(2, '0')}-${String(ahora.getHours()).padStart(2, '0')}${String(ahora.getMinutes()).padStart(2, '0')}${String(ahora.getSeconds()).padStart(2, '0')}`;

      const facturaPayload = {
        empresa_codigo: empresaCodigo,
        correlativo: correlativoFinal,
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
      if (facturaRes.status >= 400) throw new Error(facturaRes.body);

      ok++;
      correlativos.push(correlativoFinal);
    } catch (e) {
      errores.push((e && e.message) || String(e));
    }
  }

  return { ok, errores, decrementados, correlativos };
}

// ═══════════════════════════════════════════════════════════════
// Sync genérico por tabla (upsert idempotente fila por fila)
// ═══════════════════════════════════════════════════════════════

// Tablas sincronizables desde la app (nombres de tabla locales = Supabase).
const TABLAS_SYNC = new Set([
  'proveedores',
  'cotizaciones',
  'cotizacion_items',
  'ordenes_compra',
  'orden_compra_items',
  'compras',
  'compra_items',
  'transacciones',
  'matriculas',
  'notas',
  'empleados',
  'nomina',
  'fiado_abonos',
  'rutas',
  'ruta_clientes',
  'sucursales',
  'transferencias',
  'transferencia_items',
  'membresias',
  'socios',
  'socio_membresias',
  'socio_precios',
  'sar_correlativo',
  'sar_contingencia',
  'pos_arqueo_caja',
  'pos_promociones',
  'pos_cliente_credito',
  'pos_config',
  'pos_ventas',
]);

function sanitizeColumnName(name) {
  return String(name || '')
    .replace(/[^a-zA-Z0-9_]/g, '')
    .slice(0, 60);
}

function sanitizeValue(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === 'boolean') return v;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return v;
  return JSON.stringify(v);
}

async function syncHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    const body = parseBody(req);
    const empresaCodigo = body.empresa_codigo || '';
    const tabla = String(body.tabla || '');
    const operacion = String(body.operacion || 'insert');
    const rows = Array.isArray(body.rows) ? body.rows : [];

    if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
    if (!TABLAS_SYNC.has(tabla)) {
      return fail(res, { message: `Tabla no permitida para sync: ${tabla}`, status: 400 });
    }
    if (rows.length === 0) return ok(res, { success: true, ok: 0, errores: [] });

    const empresaId = await resolverEmpresaId(empresaCodigo);

    // Ventas POS: flujo especial con decremento de stock y factura idempotente.
    if (tabla === 'pos_ventas') {
      const resultado = await procesarVentaSync(empresaCodigo, empresaId, rows);
      if (resultado.ok === 0 && resultado.errores.length > 0) {
        return fail(res, { message: resultado.errores.join(' | '), status: 502 });
      }
      return ok(res, {
        success: true,
        ok: resultado.ok,
        decrementados: resultado.decrementados,
        errores: resultado.errores,
      }, 201);
    }

    const procesados = [];
    const errores = [];

    for (const raw of rows) {
      try {
        if (typeof raw !== 'object' || raw === null) continue;
        const payload = {};
        for (const [k, v] of Object.entries(raw)) {
          const col = sanitizeColumnName(k);
          if (!col || col === 'empresa_id') continue;
          payload[col] = sanitizeValue(v);
        }
        if (Object.keys(payload).length === 0) continue;
        payload.empresa_codigo = empresaCodigo;
        if (empresaId) payload.empresa_id = empresaId;

        const id = payload.id ? String(payload.id) : null;

        if (operacion === 'delete' && id) {
          const del = await supabaseRequest(`/${tabla}?id=eq.${encodeURIComponent(id)}`, {
            method: 'DELETE',
          });
          if (del.status >= 400) throw new Error(del.body);
          procesados.push({ id });
          continue;
        }

        if (id) {
          const existing = await supabaseRequest(`/${tabla}?id=eq.${encodeURIComponent(id)}&select=id`);
          let rowsFound = [];
          try { rowsFound = JSON.parse(existing.body || '[]'); } catch {}
          if (existing.status < 400 && rowsFound.length > 0) {
            const patch = await supabaseRequest(`/${tabla}?id=eq.${encodeURIComponent(id)}`, {
              method: 'PATCH',
              body: JSON.stringify({ ...payload, updated_at: new Date().toISOString() }),
            });
            if (patch.status >= 400) throw new Error(patch.body);
            procesados.push({ id, actualizado: true });
            continue;
          }
        }

        const inserted = await supabaseRequest(`/${tabla}`, { method: 'POST', body: JSON.stringify(payload) });
        if (inserted.status >= 400) throw new Error(inserted.body);
        procesados.push({ id, insertado: true });
      } catch (e) {
        errores.push({ error: (e && e.message) || String(e) });
      }
    }

    if (procesados.length === 0 && errores.length > 0) {
      return fail(res, { message: errores.join(' | '), status: 502 });
    }
    return ok(res, { success: true, ok: procesados.length, errores }, 201);
  } catch (e) {
    return fail(res, e);
  }
}

// ═══════════════════════════════════════════════════════════════
// Handler de Storage (Supabase Storage: upload y delete de imágenes)
// ═══════════════════════════════════════════════════════════════

const MIME_EXT = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'image/bmp': 'bmp',
  'image/avif': 'avif',
};

async function storageHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    const body = parseBody(req);
    const action = body.action === 'delete' ? 'delete' : 'upload';

    // ── Eliminar imagen a partir de su URL pública ───────────────────────────
    if (action === 'delete') {
      const url = String(body.url || '');
      const prefix = `${SUPABASE_URL}/storage/v1/object/`;
      if (!url.startsWith(prefix)) return ok(res, { deleted: false });
      const path = url.slice(prefix.length).replace(/^public\//, '');
      if (!path) return ok(res, { deleted: false });
      const del = await fetch(`${SUPABASE_URL}/storage/v1/object/${path}`, {
        method: 'DELETE',
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
      });
      return ok(res, { deleted: del.status === 200 });
    }

    // ── Subir imagen ──────────────────────────────────────────────────────────
    const bucket = String(body.bucket || 'productos').replace(/[^a-zA-Z0-9_-]/g, '');
    const folder = String(body.folder || '')
      .replace(/[^a-zA-Z0-9_/-]/g, '')
      .replace(/^\/+|\/+$/g, '');
    const rawBase64 = String(body.base64 || '');
    if (!rawBase64) return fail(res, { message: 'Falta base64.', status: 400 });

    const match = /^data:(image\/[\w.+-]+);base64,(.*)$/s.exec(rawBase64);
    const mime = match ? match[1] : 'image/jpeg';
    const dataB64 = match ? match[2] : rawBase64.replace(/\s+/g, '');

    let buffer;
    try {
      buffer = Buffer.from(dataB64, 'base64');
    } catch {
      return fail(res, { message: 'base64 inválido.', status: 400 });
    }
    if (buffer.length === 0) return fail(res, { message: 'Imagen vacía.', status: 400 });
    if (buffer.length > 3.5 * 1024 * 1024) {
      return fail(res, { message: 'La imagen excede el límite de 3.5 MB.', status: 413 });
    }

    const ext = MIME_EXT[mime] || 'jpg';
    const fileName = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext}`;
    const objectPath = folder ? `${folder}/${fileName}` : fileName;

    // Asegurar que el bucket exista y sea público (ignorar si ya existe).
    await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ id: bucket, name: bucket, public: true }),
    }).catch(() => {});

    let up = null;
    for (const method of ['POST', 'PUT']) {
      up = await fetch(`${SUPABASE_URL}/storage/v1/object/${bucket}/${objectPath}`, {
        method,
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          'Content-Type': mime,
        },
        body: buffer,
      });
      if (up.status !== 405) break;
    }
    if (up.status >= 400) {
      return fail(res, { message: `Error subiendo a Storage: ${up.status} ${await up.text()}`, status: up.status });
    }

    return ok(res, {
      url: `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${objectPath}`,
    });
  } catch (e) {
    return fail(res, { message: `Error en storage: ${(e && e.message) || e}`, status: 500 });
  }
}
