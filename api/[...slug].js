// Despachador Ãºnico de la API mÃ³vil (plan Hobby: mÃ¡x 12 funciones).
// El handler de login estÃ¡ integrado directamente para evitar problemas de despliegue.

const routes = {
  'login': loginHandler,
  'me': meHandler,
  'ai/groq': aiGroqHandler,
  'ai/chat': aiChatHandler,
  'ai/vision': aiVisionHandler,
  'ai/barcode': aiBarcodeHandler,
  'ai/dashboard': aiDashboardHandler,
  'ai/pos/analyze': aiPosAnalyzeHandler,
  'ai/pos/upsell': aiPosUpsellHandler,
  'ai/crm/customer': aiCrmHandler,
  'ai/support': aiSupportHandler,
  'clientes': clientesHandler,
  'compras': comprasHandler,
  'cotizaciones': cotizacionesHandler,
  'facturas': facturasHandler,
  'facturas/resumen': facturasResumenHandler,
  'configuracion-fiscal': configuracionFiscalHandler,
  'kardex': kardexHandler,
  'audit': auditHandler,
  'matriculas': matriculasHandler,
  'matriculas/stats': matriculasStatsHandler,
  'notas': notasHandler,
  'ordenes-compra': ordenesCompraHandler,
  'productos': productosHandler,
  'proveedores': proveedoresHandler,
  'storage': storageHandler,
  'sync': syncHandler,
  'transacciones': transaccionesHandler,
  'bodegas': bodegasHandler,
  'ventas': ventasHandler,
};

module.exports = async function handler(req, res) {
  // Vercel [...slug] puede venir en req.query.slug (array) o en req.url
  let pathname = '';
  if (req.query && req.query.slug) {
    const slug = req.query.slug;
    pathname = Array.isArray(slug) ? slug.join('/') : String(slug);
    pathname = pathname.replace(/^\/+|\/+$/g, '');
  } else {
    pathname = (req.url || '').split('?')[0].replace(/^\/api\//, '').replace(/\/+$/g, '').replace(/^\/+|\/+$/g, '');
  }
  if (!pathname && req.url) {
    // fallback por si req.query.slug no estÃ¡ poblado
    pathname = req.url.split('?')[0].replace(/^\/api\//, '').replace(/\/+$/g, '').replace(/^\/+|\/+$/g, '');
  }

  // Soporte para rutas dinÃ¡micas con prefijo (ej: ai/barcode/12345)
  let route = routes[pathname];
  if (!route && pathname.startsWith('ai/barcode/')) {
    route = aiBarcodeHandler;
  }
  // normalize: quitar trailing slash ya hecho, pero por si acaso
  if (!route) {
    // intentar sin query extra
    const clean = pathname.split('?')[0];
    route = routes[clean];
    if (!route && clean.startsWith('ai/barcode/')) route = aiBarcodeHandler;
    if (!route) {
      console.log(`[api] 404 pathname='${pathname}' url='${req.url}' query=${JSON.stringify(req.query)}`);
      return res.status(404).json({ error: `Ruta no encontrada: /api/${pathname}`, debug: { pathname, url: req.url, query: req.query } });
    }
  }
  return route(req, res);
};

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Handler de Login (integrado para evitar problemas de despliegue)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

function loginHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'MÃ©todo no permitido' });
    return;
  }

  // â”€â”€ Parsear body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    res.status(400).json({ error: 'Email y contraseÃ±a son requeridos.' });
    return;
  }

  const jwt = require('jsonwebtoken');
  const bcrypt = require('bcryptjs');

  const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY || '';
  const jwtSecret = process.env.JWT_SECRET || '';

  if (!supabaseUrl || !supabaseKey) {
    return res.status(503).json({ error: 'Supabase no estÃ¡ configurado en las variables de entorno de Vercel (SUPABASE_URL / SUPABASE_SERVICE_KEY).' });
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
        return res.status(401).json({ error: 'Credenciales invÃ¡lidas. Usuario no registrado.' });
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
        return res.status(401).json({ error: 'ContraseÃ±a incorrecta.' });
      }

      // Lookup tenant data (area, plan) â€” same as web portal
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

      const userArea = tenantData?.area || user.area || 'Ãrea Comercial';
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ComparaciÃ³n de contraseÃ±as: soporta bcrypt y texto plano
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// ============================================================
// GET /api/me - datos vivos del usuario autenticado (incluida la foto de
// perfil) para refrescar la sesion del app sin volver a hacer login.
// ============================================================
async function meHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Metodo no permitido' });
  const authHeader = (req.headers.authorization || '').toString();
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  if (!token) {
    return res.status(401).json({ error: 'Token requerido.' });
  }

  const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY || '';
  const jwtSecret = process.env.JWT_SECRET || '';
  if (!supabaseUrl || !supabaseKey) {
    return res.status(503).json({ error: 'Supabase no esta configurado en el servidor.' });
  }

  let payload;
  try {
    payload = require('jsonwebtoken').verify(token, jwtSecret);
  } catch (e) {
    return res.status(401).json({ error: 'Token invalido o expirado.' });
  }

  const userId = payload.sub || payload.id;
  if (!userId) {
    return res.status(401).json({ error: 'Token sin usuario.' });
  }

  const restBase = `${supabaseUrl}/rest/v1`;
  const headers = {
    apikey: supabaseKey,
    Authorization: `Bearer ${supabaseKey}`,
    'Content-Type': 'application/json'
  };

  try {
    const r = await fetch(`${restBase}/usuarios?id=eq.${encodeURIComponent(userId)}&select=*`, { headers });
    if (!r.ok) return res.status(502).json({ error: 'No se pudo consultar el perfil.' });
    const rows = await r.json();
    const user = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado.' });
    }

    let tenantData = null;
    if (user.empresa_codigo) {
      try {
        const tRes = await fetch(
          `${restBase}/tenants?codigo=eq.${encodeURIComponent(user.empresa_codigo)}&select=*`,
          { headers }
        );
        const tRows = await tRes.json();
        if (Array.isArray(tRows) && tRows.length > 0) tenantData = tRows[0];
      } catch (_) {}
    }

    return res.status(200).json({
      user: {
        id: user.id,
        nombre: user.nombre || '',
        apellido: user.apellido || '',
        email: user.email,
        rol: user.rol || 'admin',
        empresa_codigo: user.empresa_codigo || 'ROOT',
        tenant: user.empresa_codigo || 'ROOT',
        area: tenantData?.area || user.area || '',
        plan: tenantData?.plan || 'pro',
        status: user.estado || 'activo',
        foto_perfil_url: user.avatar_url || user.foto_perfil_url || null
      }
    });
  } catch (err) {
    console.error('[me] Error consultando Supabase:', err.message);
    return res.status(500).json({ error: 'Error al conectar con la base de datos Supabase.' });
  }
}

async function comparePassword(inputPassword, storedPassword) {
  if (!storedPassword) return false;
  
  // Verificar si la contraseÃ±a almacenada es un hash bcrypt
  if (storedPassword.startsWith('$2b$') || storedPassword.startsWith('$2a$') || storedPassword.startsWith('$2y$')) {
    try {
      // bcrypt estÃ¡ disponible en Node.js serverless de Vercel
      const bcrypt = require('bcryptjs');
      return await bcrypt.compare(inputPassword, storedPassword);
    } catch {
      // Si bcryptjs no estÃ¡ disponible, comparar como texto plano
      console.warn('[login] bcryptjs no disponible, comparando texto plano');
      return inputPassword === storedPassword;
    }
  }
  
  // ComparaciÃ³n de texto plano (sin hashing)
  return inputPassword === storedPassword;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Helper functions para Supabase
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

const { pickModels } = require('./_modelPicker.js');

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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// AI Groq Handler
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

function aiGroqHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'MÃ©todo no permitido' });
    return;
  }

  const key = process.env.GROQ_API_KEY;
  if (!key) {
    res.status(500).json({
      error: 'Falta GROQ_API_KEY en Vercel. ConfigÃºralo en Project Settings â†’ Environment Variables.',
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
      model: body.modelId || 'openai/gpt-oss-20b',
      messages: [
        { role: 'system', content: body.systemPrompt || 'Eres un asistente Ãºtil.' },
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
        modelId: body.modelId || 'openai/gpt-oss-20b',
        provider: 'groq',
        tokensUsed: data.usage?.total_tokens || 0,
      });
    })
    .catch(err => {
      res.status(500).json({ error: err.message });
    });
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// AI Gateway handlers (vision, chat, barcode, dashboard...)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

async function aiChatHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  const body = parseBody(req);
  const message = body.message || body.prompt || body.query || '';
  const systemPrompt = body.systemPrompt || 'Eres un asistente Ãºtil de Portal Pilot.';
  if (!message) return res.status(400).json({ error: 'Falta message', reply: null });
  const requested = body.model || body.modelId || '';
  let chatModels;
  try {
    const live = await pickModels(key, requested);
    chatModels = live.chat.length ? live.chat : [requested || 'openai/gpt-oss-20b', 'openai/gpt-oss-120b'];
  } catch {
    chatModels = [requested || 'openai/gpt-oss-20b', 'openai/gpt-oss-120b'];
  }
  let lastError = null;
  for (const model of chatModels) {
    try {
      const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: message },
          ],
          max_tokens: body.maxTokens || 1500,
          temperature: body.temperature ?? 0.7,
        }),
      });
      const data = await r.json();
      if (r.ok && data.choices) {
        const reply = data.choices?.[0]?.message?.content || '';
        return res.status(200).json({ reply, model: data.model || model, provider: 'groq', usage: data.usage });
      }
      const msg = data.error?.message || '';
      // Model not found/decommissioned -> siguiente modelo
      // 401/403 = key del proveedor vencida/sin créditos → siguiente modelo
      // y fallback OpenRouter. JAMÁS propagar el código tal cual: el app
      // interpreta 401 como sesión expirada y cierra la sesión (bug).
      if (r.status === 404 || r.status === 401 || r.status === 403 ||
          msg.includes('does not exist') || msg.includes('model_not_found') ||
          msg.includes('decommissioned') || msg.toLowerCase().includes('api key') ||
          msg.toLowerCase().includes('invalid_api_key') || msg.toLowerCase().includes('quota')) {
        lastError = msg || `Groq HTTP ${r.status}`;
        continue;
      }
      return res.status(r.status === 401 || r.status === 403 ? 502 : (r.status || 502)).json({
        error: msg || 'Error Groq', reply: null, code: 'IA_PROVIDER', details: data,
      });
    } catch (e) {
      lastError = e.message;
      continue;
    }
  }
  // Respaldo automático: OpenRouter cuando Groq falla o no hay más modelos.
  try {
    const { openRouterComplete } = require('./_aiRouter.js');
    const fallback = await openRouterComplete({
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: message },
      ],
      model: requested,
      maxTokens: body.maxTokens || 1500,
      temperature: body.temperature ?? 0.7,
    });
    return res.status(200).json({ reply: fallback.reply, model: fallback.model, provider: fallback.provider, usage: fallback.usage });
  } catch (fallbackErr) {
    return res.status(502).json({ error: lastError || fallbackErr.message || 'Todos los modelos de chat fallaron', reply: null });
  }
}

async function aiVisionHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  const body = parseBody(req);
  let image = body.image || body.base64 || '';
  const prompt = body.prompt || 'Identifica este producto y devuelve un JSON con: nombre, marca, categoria, descripcion, presentacion, unidad_medida, confianza (0-1). Si no puedes determinar algo, deja el campo como null. Responde SOLO con el JSON.';
  if (!image) return res.status(400).json({ error: 'Falta image (base64)', reply: null });
  if (!image.startsWith('data:')) image = `data:image/jpeg;base64,${image.replace(/\s+/g, '')}`;
  // Modelos de visión disponibles (auto-descubrimiento contra la API de Groq)
  const requestedModel = body.model || '';
  let visionModels;
  try {
    const live = await pickModels(key, requestedModel);
    visionModels = live.vision.length ? live.vision : [requestedModel || 'qwen/qwen3.6-27b', 'qwen/qwen3.8-27b'];
  } catch {
    visionModels = [requestedModel || 'qwen/qwen3.6-27b', 'qwen/qwen3.8-27b'];
  }
  // Limitar a máximo 2 intentos para evitar timeout de Vercel (Hobby: 10s)
  const modelsToTry = visionModels.slice(0, 2);
  let lastError = null;
    for (const model of modelsToTry) {
      try {
        const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
          method: 'POST',
          headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model,
            messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, { type: 'image_url', image_url: { url: image } }] }],
            max_tokens: body.maxTokens || 800,
            temperature: 0.2,
          }),
        });
        const data = await r.json();
        if (r.ok && data.choices) {
          let reply = data.choices?.[0]?.message?.content || '';
          reply = reply.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
          return res.status(200).json({ reply, model: data.model || model, provider: 'groq', usage: data.usage });
        }
        const msg = data.error?.message || '';
        // Si es deprecación, prueba siguiente modelo. 401/403 = key del
        // proveedor vencida/sin créditos → también continuar al fallback;
        // JAMÁS propagar el código (el app lo toma como sesión expirada).
        if (msg.includes('decommissioned') || msg.includes('model_') || data.error?.code === 'model_decommissioned' ||
            r.status === 401 || r.status === 403 || msg.toLowerCase().includes('api key') ||
            msg.toLowerCase().includes('invalid_api_key') || msg.toLowerCase().includes('quota')) {
          lastError = msg || `Groq HTTP ${r.status}`;
          continue;
        }
        return res.status(r.status === 401 || r.status === 403 ? 502 : (r.status || 502)).json({
          error: msg || 'Error Groq Vision', reply: null, code: 'IA_PROVIDER', details: data,
        });
} catch (e) {
      lastError = e.message;
      continue;
    }
  }
  // Respaldo automático: OpenRouter de visión cuando Groq falla.
  try {
    const { openRouterVision } = require('./_aiRouter.js');
    const fallback = await openRouterVision({ prompt, image, maxTokens: body.maxTokens || 800 });
    return res.status(200).json({ reply: fallback.reply, model: fallback.model, provider: fallback.provider, usage: fallback.usage });
  } catch (fallbackErr) {
    return res.status(502).json({ error: lastError || fallbackErr.message || 'Todos los modelos de visión fallaron', reply: null });
  }
}

async function aiBarcodeHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'MÃ©todo no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  // Extraer cÃ³digo de la ruta ai/barcode/<code> o query ?code=
  const urlParts = (req.url || '').split('?')[0].split('/');
  let code = urlParts[urlParts.length - 1] || '';
  if (!code || code === 'barcode') code = (req.query?.code || '').toString();
  code = decodeURIComponent((code || '').toString().trim());
  if (!code) return res.status(400).json({ found: false, products: [], source: 'error', message: 'Falta cÃ³digo de barras' });
  try {
    const result = await supabaseRequest(`/productos?codigo=eq.${encodeURIComponent(code)}&select=*&limit=10`);
    if (result.status >= 400) return res.status(502).json({ found: false, products: [], source: 'supabase', message: result.body });
    const rows = JSON.parse(result.body || '[]');
    if (Array.isArray(rows) && rows.length > 0) {
      return ok(res, { found: true, products: rows, source: 'supabase' });
    }
    // Fallback sin empresa_codigo: busca global
    return ok(res, { found: false, products: [], source: 'supabase', message: 'No encontrado en catÃ¡logo' });
  } catch (e) {
    return res.status(500).json({ found: false, products: [], source: 'error', message: e.message });
  }
}

function aiDashboardHandler(req, res) { return aiChatHandler(req, res); }

// Análisis de caja POS: enriquece el mensaje con el rango de fechas, el rol
// especializado y los datos reales de ventas (facturas) de Supabase.
async function aiPosAnalyzeHandler(req, res) {
  const body = parseBody(req);
  const dateRange = body.dateRange || {};
  const desde = dateRange.desde || dateRange.from || body.desde || null;
  const hasta = dateRange.hasta || dateRange.to || body.hasta || null;
  const rango = (desde ? ` Desde: ${desde}.` : '') + (hasta ? ` Hasta: ${hasta}.` : '');

  // Datos reales de la nube (facturas de venta) para enriquecer el análisis
  let datosNube = null;
  let consultaNubeOk = false;
  const empresaCodigo = body.empresaCodigo || body.empresa_codigo || '';
  if (configured() && empresaCodigo) {
    try {
      let path = `/facturas?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&select=*&order=created_at.desc&limit=2000`;
      if (desde) path += `&created_at=gte.${encodeURIComponent(desde)}`;
      if (hasta) path += `&created_at=lte.${encodeURIComponent(hasta)}T23:59:59.999Z`;
      const result = await supabaseRequest(path);
      consultaNubeOk = result.status < 400;
      if (consultaNubeOk) {
        const rows = JSON.parse(result.body || '[]');
        if (Array.isArray(rows) && rows.length) {
          let total = 0, efectivo = 0, tarjeta = 0, transferencia = 0, otras = 0;
          const porProducto = {};
          for (const f of rows) {
            const t = Number(f.total) || 0;
            total += t;
            const notas = String(f.notas || '').toLowerCase();
            if (notas.includes('efectivo')) efectivo += t;
            else if (notas.includes('tarjeta')) tarjeta += t;
            else if (notas.includes('transferencia')) transferencia += t;
            else otras += t;
            if (Array.isArray(f.items)) {
              for (const it of f.items) {
                const n = String(it.nombre || it.producto_nombre || '').trim();
                if (n) porProducto[n] = (porProducto[n] || 0) + (Number(it.cantidad) || 1);
              }
            }
          }
          const cant = rows.length;
          datosNube = {
            fuente: 'facturas (Supabase)',
            total_ventas: total,
            total_transacciones: cant,
            efectivo,
            tarjeta,
            transferencia,
            otras,
            ticket_promedio: cant ? total / cant : 0,
            top_productos: Object.entries(porProducto)
              .sort((a, b) => b[1] - a[1])
              .slice(0, 5)
              .map(([producto, cantidad]) => ({ producto, cantidad })),
          };
        }
      }
    } catch (e) {
      console.log('[pos/analyze] Error obteniendo facturas:', e.message);
    }
  }

  const base = (body.message || body.prompt || body.query || '').trim();
  const contextoNube = datosNube
    ? `\n\nDatos de ventas desde la nube (Supabase): ${JSON.stringify(datosNube)}`
    : consultaNubeOk && empresaCodigo
      ? `\n\nNo se encontraron facturas de venta en Supabase para el periodo${empresaCodigo ? ` (empresa ${empresaCodigo})` : ''}.`
      : '';
  const guarda = '\nSi no hay datos de ventas en el periodo (ni locales ni de la nube), dilo con claridad, da 2-3 causas probables y recomendaciones, y NO inventes cifras ni ejemplos de productos.';
  const msg = base
    ? `${base}${contextoNube}${rango}${guarda}\nAnaliza la caja del POS de ese periodo: total de ventas por m\u00e9todo de pago, ticket promedio, top de productos, posibles sobrantes/faltantes de caja y recomendaciones accionables. Si hay datos de la nube, priorizalos sobre los locales. Usa datos duros y formato con vi\u00f1etas.`
    : `Genera el an\u00e1lisis de caja del POS del periodo actual.${contextoNube}${rango}${guarda}`;
  req.body = {
    ...body,
    message: msg,
    systemPrompt: body.systemPrompt || 'Eres el analista de caja del POS de Portal Pilot. Responde en espa\u00f1ol, conciso y con n\u00fameros claros. Usa L. (lempiras hondure\u00f1as) como moneda, formato "L 1,234.56". Nunca uses \u20AC, $ ni otra moneda.',
  };
  return aiChatHandler(req, res);
}

// Recomendaciones de upsell/cross-sell: recibe carrito + catálogo y
// devuelve sugerencias accionables SOLO del catálogo enviado.
async function aiPosUpsellHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'M\u00e9todo no permitido', reply: null });
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'Falta GROQ_API_KEY en Vercel', reply: null });
  const body = parseBody(req);

  const carrito = Array.isArray(body.carrito) ? body.carrito : [];
  const catalogo = Array.isArray(body.catalogo) ? body.catalogo : [];
  if (carrito.length === 0) return res.status(400).json({ error: 'Falta carrito', reply: null });

  const nombresEnCarrito = new Set(
    carrito.map((c) => String(c.nombre || '').trim().toLowerCase()).filter(Boolean)
  );

  const prompt = [
    'Eres un vendedor experto de punto de venta. Tu tarea es recomendar productos complementarios (upsell/cross-sell) para el ticket actual.',
    'Reglas:',
    '- Recomienda SOLO productos existentes en el cat\u00e1logo proporcionado.',
    '- No repitas productos que ya est\u00e1n en el carrito.',
    '- M\u00e1ximo 3 sugerencias, ordenadas por relevancia (la mejor primero).',
    '- Un motivo corto y persuasivo por sugerencia (m\u00e1x 12 palabras).',
    '- Responde \u00daNICAMENTE con JSON v\u00e1lido con este formato exacto:',
    '{"sugerencias":[{"codigo":"CODIGO_DEL_CATALOGO","nombre":"Nombre del producto","motivo":"Motivo corto"}]}',
    '',
    'Carrito actual:',
    JSON.stringify(carrito),
    '',
    'Cat\u00e1logo disponible:',
    JSON.stringify(catalogo),
  ].join('\n');

  let models;
  try {
    const live = await pickModels(key, '');
    models = live.chat.length ? live.chat : ['openai/gpt-oss-20b', 'openai/gpt-oss-120b'];
  } catch {
    models = ['openai/gpt-oss-20b', 'openai/gpt-oss-120b'];
  }

  let lastError = null;
  for (const model of models) {
    try {
      const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: 'Eres el motor de recomendaciones de Portal Pilot POS. Si el cat\u00e1logo est\u00e1 vac\u00edo o no hay productos candidatos, devuelve {"sugerencias":[]}.' },
            { role: 'user', content: prompt },
          ],
          max_tokens: body.maxTokens || 600,
          temperature: 0.3,
        }),
      });
      const data = await r.json();
      if (r.ok && data.choices) {
        let reply = data.choices?.[0]?.message?.content || '';
        reply = reply.replace(/ thinking[\s\S]*?<\/think>/gi, '').trim();
        let sugerencias = [];
        try {
          const jsonStr = reply.trim();
          const start = jsonStr.indexOf('{');
          const end = jsonStr.lastIndexOf('}');
          if (start >= 0 && end > start) {
            const parsed = JSON.parse(jsonStr.substring(start, end + 1));
            const arr = Array.isArray(parsed) ? parsed : (parsed.sugerencias || []);
            sugerencias = arr
              .filter((s) => s && s.codigo && !nombresEnCarrito.has(String(s.nombre || '').trim().toLowerCase()))
              .slice(0, 3)
              .map((s) => ({
                codigo: String(s.codigo || ''),
                nombre: String(s.nombre || ''),
                motivo: String(s.motivo || ''),
              }));
          }
        } catch (err) {
          console.log('[pos/upsell] No se pudo parsear JSON del modelo:', err.message);
        }
        return res.status(200).json({ reply, sugerencias, model: data.model || model, provider: 'groq', usage: data.usage });
      }
      const msg = data.error?.message || '';
      // Igual que en chat: no propagar 401/403 del proveedor (logout espurio).
      if (r.status === 404 || r.status === 401 || r.status === 403 ||
          msg.includes('does not exist') || msg.includes('model_not_found') ||
          msg.includes('decommissioned') || msg.toLowerCase().includes('api key') ||
          msg.toLowerCase().includes('invalid_api_key') || msg.toLowerCase().includes('quota')) {
        lastError = msg || `Groq HTTP ${r.status}`;
        continue;
      }
      return res.status(r.status === 401 || r.status === 403 ? 502 : (r.status || 502)).json({
        error: msg || 'Error Groq', reply: null, code: 'IA_PROVIDER', details: data, sugerencias: [],
      });
    } catch (e) {
      lastError = e.message;
      continue;
    }
  }
  return res.status(502).json({ error: lastError || 'Todos los modelos fallaron', reply: null, sugerencias: [] });
}

// Reexporta handlers para que las funciones individuales (api/ai/pos/upsell.js)
// puedan reutilizarlos sin duplicar lógica.
module.exports.aiPosUpsellHandler = aiPosUpsellHandler;
module.exports.aiPosAnalyzeHandler = aiPosAnalyzeHandler;
function aiCrmHandler(req, res) { return aiChatHandler(req, res); }
function aiSupportHandler(req, res) { return aiChatHandler(req, res); }

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Placeholder handlers para otros endpoints
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

async function clientesHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const authHeader = String(req.headers?.authorization || '');
      let claims;
      try {
        const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
        if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
        claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
      } catch (_) { return fail(res, { message: 'Sesión inválida o expirada.', status: 401 }); }
      const empresaCodigo = String(claims.empresa_codigo || claims.tenant || '').trim();
      if (!empresaCodigo) return fail(res, { message: 'La sesión no tiene empresa asignada.', status: 403 });
      if (req.query?.empresaCodigo && String(req.query.empresaCodigo).toUpperCase() !== empresaCodigo.toUpperCase()) {
        return fail(res, { message: 'La sesión no pertenece a esa empresa.', status: 403 });
      }

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
      const empresaCodigo = verifiedTenantCode(req, body.empresa_codigo || '');
      const c = body.cliente || body;
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
      // Si la columna dni aÃºn no existe en la BD (migraciÃ³n pendiente), reintentar sin ella.
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
      const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);
      if (!id) return fail(res, { message: 'Falta id.', status: 400 });
      const result = await supabaseRequest(`/clientes?id=eq.${encodeURIComponent(id)}&empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`, { method: 'DELETE' });
      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true });
    }

    return res.status(405).json({ error: 'MÃ©todo no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

function verifiedTenantCode(req, requestedCode) {
  const auth = String(req.headers?.authorization || '');
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!token || !process.env.JWT_SECRET) {
    const error = new Error('Se requiere una sesión autenticada.');
    error.status = 401;
    throw error;
  }
  let claims;
  try {
    claims = require('jsonwebtoken').verify(token, process.env.JWT_SECRET);
  } catch (_) {
    const error = new Error('La sesión es inválida o expiró.');
    error.status = 401;
    throw error;
  }
  const tenantCode = String(claims.empresa_codigo || claims.tenant || '').trim();
  if (!tenantCode) {
    const error = new Error('La sesión no tiene una empresa asignada.');
    error.status = 403;
    throw error;
  }
  if (requestedCode && String(requestedCode).trim().toUpperCase() !== tenantCode.toUpperCase()) {
    const error = new Error('La sesión no pertenece a la empresa solicitada.');
    error.status = 403;
    throw error;
  }
  return tenantCode;
}

async function comercialListHandler(req, res, { table, responseKey, childTable, childForeignKey }) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido.' });
  try {
    const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);
    const limit = Math.min(1000, Math.max(1, Number.parseInt(req.query?.limit, 10) || 500));
    const result = await supabaseRequest(
      `/${table}?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=${limit}`
    );
    if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
    const rows = JSON.parse(result.body || '[]');
    if (childTable && rows.length) {
      const ids = rows.map((row) => row.id).filter(Boolean);
      if (ids.length) {
        const filter = ids.map((id) => encodeURIComponent(String(id))).join(',');
        const children = await supabaseRequest(
          `/${childTable}?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&${childForeignKey}=in.(${filter})&order=created_at.asc&limit=5000`
        );
        if (children.status >= 400) return fail(res, { message: children.body, status: 502 });
        const grouped = new Map(ids.map((id) => [String(id), []]));
        for (const item of JSON.parse(children.body || '[]')) {
          const parentId = String(item[childForeignKey] || '');
          if (grouped.has(parentId)) grouped.get(parentId).push(item);
        }
        for (const row of rows) row.items = grouped.get(String(row.id)) || [];
      }
    }
    return ok(res, { [responseKey]: rows });
  } catch (err) {
    return fail(res, err);
  }
}

function comprasHandler(req, res) {
  return comercialListHandler(req, res, {
    table: 'compras', responseKey: 'compras', childTable: 'compra_items', childForeignKey: 'compra_id',
  });
}

function cotizacionesHandler(req, res) {
  return comercialListHandler(req, res, {
    table: 'cotizaciones', responseKey: 'cotizaciones', childTable: 'cotizacion_items', childForeignKey: 'cotizacion_id',
  });
}

async function facturasHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);

      const result = await supabaseRequest(
        `/facturas?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=200`
      );
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = verifiedTenantCode(req, body.empresa_codigo || '');
      const f = body.factura || body;
      const empresaId = await resolverEmpresaId(empresaCodigo);
      const tasaIsvEstandar = Number(f.tasa_isv_estandar ?? 0.15);
      if (!Number.isFinite(tasaIsvEstandar) || tasaIsvEstandar < 0 || tasaIsvEstandar > 0.50) {
        return fail(res, { message: 'La tasa ISV estándar debe estar entre 0 y 0.50.', status: 400 });
      }
      if (f.correlativo) {
        const existing = await supabaseRequest(
          `/facturas?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&correlativo=eq.${encodeURIComponent(f.correlativo)}&select=id&limit=1`
        );
        if (existing.status >= 400) return fail(res, { message: existing.body, status: 502 });
        if ((JSON.parse(existing.body || '[]') || []).length) {
          return ok(res, { success: true, duplicate: true });
        }
      }

      const payload = {
        empresa_codigo: empresaCodigo,
        correlativo: f.correlativo || '',
        tipo_documento: f.tipo_documento || 'Factura',
        cai: f.cai || '',
        rango_inicio: f.rango_inicio || null,
        rango_fin: f.rango_fin || null,
        fecha_limite_emision: f.fecha_limite_emision || null,
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
        tasa_isv_estandar: tasaIsvEstandar,
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
      const empresaCodigo = verifiedTenantCode(req, body.empresa_codigo || '');
      const f = body.factura || body;
      const correlativo = (req.query?.correlativo || f.correlativo || '').toString();
      if (!id && !correlativo) return fail(res, { message: 'Falta el identificador de la factura.', status: 400 });
      const update = { updated_at: new Date().toISOString() };
      const allowed = ['tipo_documento','cai','rango_inicio','rango_fin','fecha_limite_emision','cliente_nombre','cliente_rtn','cliente_direccion','condicion_pago','tipo_venta','items','subtotal','isv_15','isv_18','descuento','total','tasa_isv_estandar','estado','notas','fecha_anulacion','motivo_anulacion'];
      if (f.tasa_isv_estandar !== undefined) {
        const tasa = Number(f.tasa_isv_estandar);
        if (!Number.isFinite(tasa) || tasa < 0 || tasa > 0.50) {
          return fail(res, { message: 'La tasa ISV estándar debe estar entre 0 y 0.50.', status: 400 });
        }
      }
      for (const key of allowed) if (f[key] !== undefined) update[key] = f[key];
      const identityFilter = id
        ? `id=eq.${encodeURIComponent(id)}`
        : `correlativo=eq.${encodeURIComponent(correlativo)}`;

      const result = await supabaseRequest(`/facturas?${identityFilter}&empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`, {
        method: 'PATCH',
        body: JSON.stringify(update),
      });
      if (result.status >= 400) return fail(res, { message: result.body });
      const rows = JSON.parse(result.body || '[]');
      if (!rows.length) return fail(res, { message: 'Factura no encontrada en esta empresa.', status: 404 });
      return ok(res, { success: true, data: rows });
    }

    return res.status(405).json({ error: 'MÃ©todo no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

// Resumen de facturas para el home de Facturación (períodos hoy/mes + acumulado).
async function facturasResumenHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  if (req.method !== 'GET') return res.status(405).json({ error: 'Metodo no permitido' });

  try {
    const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);

    const select = 'select=total,estado,created_at';
    let result = await supabaseRequest(
      `/facturas?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&${select}&order=created_at.desc&limit=10000`
    );
    let rows = [];
    if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
    rows = JSON.parse(result.body || '[]');

    const fechaHonduras = (date) => {
      const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'America/Tegucigalpa', year: 'numeric', month: '2-digit', day: '2-digit',
      }).formatToParts(date);
      const part = (type) => parts.find((item) => item.type === type)?.value || '';
      return `${part('year')}-${part('month')}-${part('day')}`;
    };
    const hoyKey = fechaHonduras(new Date());
    const mesKey = hoyKey.slice(0, 7);
    let totalFacturas = 0, totalFacturado = 0;
    let hoy = 0, hoyTotal = 0;
    let mes = 0, mesTotal = 0;
    for (const f of rows) {
      const estado = String(f.estado || '').toLowerCase();
      if (estado === 'anulada') continue;
      const t = Number(f.total) || 0;
      totalFacturas++;
      totalFacturado += t;
      const d = f.created_at ? new Date(f.created_at) : null;
      if (d && !isNaN(d.getTime())) {
        const fechaKey = fechaHonduras(d);
        if (fechaKey === hoyKey) {
          hoy++;
          hoyTotal += t;
        }
        if (fechaKey.startsWith(mesKey)) {
          mes++;
          mesTotal += t;
        }
      }
    }
    return ok(res, {
      resumen: {
        total_facturas: totalFacturas,
        total_facturado: totalFacturado,
        facturas_hoy: hoy,
        facturado_hoy: hoyTotal,
        facturas_mes: mes,
        facturado_mes: mesTotal,
      },
    });
  } catch (err) {
    return fail(res, err);
  }
}

async function configuracionFiscalHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });
  try {
    const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);
    const result = await supabaseRequest(
      `/configuracion_fiscal?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&select=configuracion,updated_at&limit=1`
    );
    if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
    const rows = JSON.parse(result.body || '[]');
    return ok(res, { success: true, configuracion: rows[0]?.configuracion || null, updated_at: rows[0]?.updated_at || null });
  } catch (err) {
    return fail(res, err);
  }
}

// Movimientos de inventario usados por la vista Kardex.
async function kardexHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  try {
    if (req.method === 'GET') {
      const authHeader = String(req.headers?.authorization || '');
      let claims;
      try {
        const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
        if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
        claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
      } catch (_) { return fail(res, { message: 'Sesi?n inv?lida o expirada.', status: 401 }); }
      const empresaCodigo = String(claims.empresa_codigo || claims.tenant || '').trim();
      if (!empresaCodigo) return fail(res, { message: 'La sesi?n no tiene empresa asignada.', status: 403 });
      if (req.query?.empresaCodigo && String(req.query.empresaCodigo).toUpperCase() !== empresaCodigo.toUpperCase()) {
        return fail(res, { message: 'La sesi?n no pertenece a esa empresa.', status: 403 });
      }
      const limit = Math.min(Math.max(parseInt(req.query?.limit || '200', 10) || 200, 1), 1000);
      const result = await supabaseRequest('/kardex?empresa_codigo=eq.' + encodeURIComponent(empresaCodigo) + '&order=created_at.desc&limit=' + limit);
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      return ok(res, { movimientos: JSON.parse(result.body || '[]') });
    }
    if (req.method === 'POST') {
      const body = parseBody(req);
      const authHeader = String(req.headers?.authorization || '');
      let claims;
      try {
        const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
        if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
        claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
      } catch (_) { return fail(res, { message: 'Sesi?n inv?lida o expirada.', status: 401 }); }
      const empresaCodigo = String(claims.empresa_codigo || claims.tenant || '').trim();
      if (!empresaCodigo || (body.empresa_codigo && String(body.empresa_codigo).toUpperCase() !== empresaCodigo.toUpperCase())) {
        return fail(res, { message: 'La sesi?n no pertenece a esa empresa.', status: 403 });
      }
      const cantidad = Number.parseInt(body.cantidad, 10);
      if (!body.producto_codigo || !['entrada', 'salida'].includes(String(body.tipo_movimiento)) || !Number.isInteger(cantidad) || cantidad <= 0) {
        return fail(res, { message: 'Faltan datos v?lidos para registrar el movimiento.', status: 400 });
      }
      const empresaId = await resolverEmpresaId(empresaCodigo);
      const movimiento = {
        id: require('crypto').randomUUID(),
        producto_codigo: String(body.producto_codigo),
        tipo_movimiento: String(body.tipo_movimiento),
        cantidad,
        referencia: body.referencia || null,
        notas: body.notas || null,
        created_at: new Date().toISOString(),
      };
      const result = await supabaseRequest('/rpc/pos_registrar_movimiento_stock', {
        method: 'POST',
        body: JSON.stringify({ p_empresa_codigo: empresaCodigo, p_empresa_id: empresaId, p_movimiento: movimiento }),
      });
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      const saved = JSON.parse(result.body || '{}');
      if (saved.success !== true) return fail(res, { message: 'Supabase no confirm? el movimiento.', status: 502 });
      return ok(res, { success: true, movimiento: saved }, 201);
    }
    return res.status(405).json({ error: 'Metodo no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

async function auditHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!['GET', 'POST'].includes(req.method)) return res.status(405).json({ error: 'Metodo no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan credenciales de Supabase.' });
  try {
    const header = String(req.headers.authorization || '');
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
    if (!token) return res.status(401).json({ error: 'Token requerido.' });
    let user;
    try { user = require('jsonwebtoken').verify(token, process.env.JWT_SECRET || ''); }
    catch { return res.status(401).json({ error: 'Token invalido o expirado.' }); }
    const body = parseBody(req);
    const empresaCodigo = user.empresa_codigo || user.tenant;
    if (!empresaCodigo) return res.status(400).json({ error: 'Empresa no asociada a la sesión.' });
    if (req.method === 'GET') {
      const limit = Math.min(Math.max(parseInt(req.query?.limit || '100', 10) || 100, 1), 500);
      const result = await supabaseRequest(`/system_logs?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=${limit}`);
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      return ok(res, { logs: JSON.parse(result.body || '[]') });
    }
    const row = {
      empresa_codigo: empresaCodigo,
      usuario_id: user.sub || user.id || null,
      nivel: String(body.level || 'INFO').slice(0, 16),
      mensaje: String(body.message || '').slice(0, 500),
      modulo: body.module ? String(body.module).slice(0, 80) : null,
      metadata: body.metadata && typeof body.metadata === 'object' ? body.metadata : {},
      created_at: body.timestamp || new Date().toISOString(),
    };
    const result = await supabaseRequest('/system_logs', { method: 'POST', body: JSON.stringify(row) });
    if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
    return ok(res, { success: true }, 201);
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
  return comercialListHandler(req, res, {
    table: 'ordenes_compra', responseKey: 'ordenes', childTable: 'orden_compra_items', childForeignKey: 'orden_compra_id',
  });
}

async function productosHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);

      const result = await supabaseRequest(
        `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=500&select=*`
      );
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      return ok(res, JSON.parse(result.body || '[]'));
    }

    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = body.empresa_codigo || '';
      // Aceptar tanto lote ({"productos":[...]}) como un solo producto plano
      let productos = Array.isArray(body.productos) ? body.productos : [];
      if (productos.length === 0 && body.nombre) productos = [body];
      if (!empresaCodigo) return fail(res, { message: 'Falta empresa_codigo.', status: 400 });
      const authHeader = String(req.headers?.authorization || '');
      let claims;
      try {
        const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
        if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
        claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
      } catch (_) { return fail(res, { message: 'Sesión inválida o expirada.', status: 401 }); }
      const tenantClaim = String(claims.empresa_codigo || claims.tenant || '').trim().toUpperCase();
      if (!tenantClaim || tenantClaim !== String(empresaCodigo).trim().toUpperCase()) {
        return fail(res, { message: 'La sesión no pertenece a la empresa de estos productos.', status: 403 });
      }
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
          unidad_medida: (p.unidad_medida || 'Unidad').toString().slice(0, 50),
          marca: (p.marca || null)?.toString().slice(0, 100) || null,
          presentacion: (p.presentacion || null)?.toString().slice(0, 100) || null,
          barcode: (p.barcode || null)?.toString().slice(0, 100) || null,
          exento: p.exento === true,
          is_perishable: p.is_perishable === true,
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
      // el on_conflict requiere un constraint UNIQUE que aÃºn no existe en la tabla.
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

        if (payload.barcode) {
          const duplicate = await supabaseRequest(`/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&barcode=eq.${encodeURIComponent(payload.barcode)}&select=id,codigo`);
          if (duplicate.status < 400) {
            const matches = JSON.parse(duplicate.body || '[]');
            const ownId = rows[0]?.id;
            if (matches.some((item) => item.id !== ownId)) { errores.push(`C?digo de barras duplicado: ${payload.barcode}`); continue; }
          }
        }

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
      const authHeader = String(req.headers?.authorization || '');
      let claims;
      try {
        const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
        if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
        claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
      } catch (_) { return fail(res, { message: 'Sesión inválida o expirada.', status: 401 }); }
      const tenantClaim = String(claims.empresa_codigo || claims.tenant || '').trim().toUpperCase();
      if (!tenantClaim || tenantClaim !== String(empresaCodigo).trim().toUpperCase()) {
        return fail(res, { message: 'La sesión no pertenece a la empresa de este producto.', status: 403 });
      }
      const result = await supabaseRequest(
        `/productos?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&codigo=eq.${encodeURIComponent(codigo)}`,
        { method: 'DELETE' }
      );

      if (result.status >= 400) return fail(res, { message: result.body });
      return ok(res, { success: true }, 200);
    }

    return res.status(405).json({ error: 'MÃ©todo no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

function proveedoresHandler(req, res) {
  return comercialListHandler(req, res, { table: 'proveedores', responseKey: 'proveedores' });
}

async function transaccionesHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    if (req.method === 'GET') {
      const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);
      const result = await supabaseRequest(`/transacciones?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=fecha.desc&limit=1000`);
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      return ok(res, JSON.parse(result.body || '[]'));
    }
    if (req.method === 'POST') {
      const body = parseBody(req);
      const empresaCodigo = verifiedTenantCode(req, body.empresa_codigo || '');
      const t = body.transaccion || body;
      if (!['ingreso', 'gasto', 'transferencia', 'ajuste'].includes(String(t.tipo))) {
        return fail(res, { message: 'Tipo de transacción inválido.', status: 400 });
      }
      const monto = Number(t.monto);
      if (!Number.isFinite(monto) || monto < 0) return fail(res, { message: 'Monto de transacción inválido.', status: 400 });
      if (t.id) {
        const existing = await supabaseRequest(`/transacciones?id=eq.${encodeURIComponent(t.id)}&empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&select=id&limit=1`);
        if (existing.status >= 400) return fail(res, { message: existing.body, status: 502 });
        if ((JSON.parse(existing.body || '[]') || []).length) return ok(res, { success: true, duplicate: true });
      }
      const payload = {
        ...(t.id ? { id: t.id } : {}),
        empresa_codigo: empresaCodigo,
        empresa_id: await resolverEmpresaId(empresaCodigo),
        tipo: t.tipo,
        categoria: t.categoria || null,
        descripcion: t.descripcion || null,
        monto,
        metodo_pago: t.metodo_pago || null,
        referencia: t.referencia || null,
        fecha: t.fecha || new Date().toISOString(),
      };
      const result = await supabaseRequest('/transacciones', { method: 'POST', body: JSON.stringify(payload) });
      if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
      return ok(res, { success: true, data: JSON.parse(result.body || '[]') }, 201);
    }
    return res.status(405).json({ error: 'Método no permitido' });
  } catch (err) {
    return fail(res, err);
  }
}

async function bodegasHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });
  try {
    const empresaCodigo = verifiedTenantCode(req, req.query?.empresaCodigo || req.query?.empresa_codigo);
    const result = await supabaseRequest(
      `/bodegas?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=nombre.asc&limit=500`
    );
    if (result.status >= 400) return fail(res, { message: result.body, status: 502 });
    return ok(res, { success: true, bodegas: JSON.parse(result.body || '[]') });
  } catch (err) {
    return fail(res, err);
  }
}

async function ventasHandler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    const body = parseBody(req);
    const empresaCodigo = verifiedTenantCode(req, body.empresa_codigo || '');
    const venta = body.venta || {};

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

  for (const venta of ventas) {
    try {
      if (typeof venta !== 'object' || venta === null) continue;
      const result = await supabaseRequest('/rpc/pos_registrar_venta', {
        method: 'POST',
        body: JSON.stringify({
          p_empresa_codigo: empresaCodigo,
          p_empresa_id: empresaId,
          p_venta: venta,
        }),
      });
      if (result.status >= 400) throw new Error(result.body);
      const saved = JSON.parse(result.body || '{}');
      if (saved.success !== true) throw new Error('Supabase no confirmó el registro de la venta.');
      ok++;
      if (saved.correlativo) correlativos.push(saved.correlativo);
      if (Array.isArray(saved.decrementados)) decrementados.push(...saved.decrementados);
    } catch (e) {
      errores.push((e && e.message) || String(e));
    }
  }

  return { ok, errores, decrementados, correlativos };
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Sync genÃ©rico por tabla (upsert idempotente fila por fila)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// Tablas sincronizables desde la app (nombres de tabla locales = Supabase).
const TABLAS_SYNC = new Set([
  'proveedores',
  'empresas',
  'kardex',
  'cotizaciones',
  'cotizacion_items',
  'ordenes_compra',
  'orden_compra_items',
  'compras',
  'compra_items',
  'transacciones',
  'configuracion_fiscal',
  'bodegas',
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
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido' });
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

    // Actualizaciones del tenant autenticado; el onboarding de bienvenida no crea empresas.
    if (tabla === 'empresas') {
      const authHeader = String(req.headers?.authorization || '');
      const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
      let claims;
      try {
        if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
        claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
      } catch (_) {
        return fail(res, { message: 'Sesión inválida o expirada para sincronizar la empresa.', status: 401 });
      }
      const tenantClaim = String(claims.empresa_codigo || claims.tenant || '').trim().toUpperCase();
      if (!tenantClaim || tenantClaim !== String(empresaCodigo).trim().toUpperCase()) {
        return fail(res, { message: 'La sesión no pertenece a la empresa de estos cambios.', status: 403 });
      }
      const results = [];
      const errores = [];
      for (const raw of rows) {
        const codigo = String(raw?.codigo || raw?.empresa_codigo || empresaCodigo);
        const tenant = { codigo, nombre: String(raw?.nombre || 'Portal Pilot Empresa'), area: raw?.area || raw?.area_negocio || null, plan: raw?.plan || 'Prueba' };
        const current = await supabaseRequest(`/tenants?codigo=eq.${encodeURIComponent(codigo)}&select=codigo`);
        let found = [];
        try { found = JSON.parse(current.body || '[]'); } catch {}
        const saved = found.length
          ? await supabaseRequest(`/tenants?codigo=eq.${encodeURIComponent(codigo)}`, { method: 'PATCH', body: JSON.stringify(tenant) })
          : await supabaseRequest('/tenants', { method: 'POST', body: JSON.stringify(tenant) });
        if (saved.status >= 400) errores.push(saved.body); else results.push({ codigo });
      }
      if (!results.length && errores.length) return fail(res, { message: errores.join(' | '), status: 502 });
      return ok(res, { success: true, ok: results.length, errores }, 201);
    }

    // El resto de la cola se ejecuta con la clave privilegiada del servidor:
    // nunca aceptes el tenant del body como prueba de identidad.
    const authHeader = String(req.headers?.authorization || '');
    const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
    let claims;
    try {
      if (!bearer || !process.env.JWT_SECRET) throw new Error('missing token');
      claims = require('jsonwebtoken').verify(bearer, process.env.JWT_SECRET);
    } catch (_) {
      return fail(res, { message: 'Sesión inválida o expirada para sincronizar.', status: 401 });
    }
    const tenantClaim = String(claims.empresa_codigo || claims.tenant || '').trim().toUpperCase();
    if (!tenantClaim || tenantClaim !== String(empresaCodigo).trim().toUpperCase()) {
      return fail(res, { message: 'La sesión no pertenece a la empresa de estos cambios.', status: 403 });
    }

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

    // Ajustes manuales de Kardex también modifican existencias; ambos efectos
    // se confirman juntos mediante la función SQL transaccional.
    if (tabla === 'kardex') {
      // Compatibilidad con filas encoladas por versiones anteriores: estas
      // procedían de ventas/compras cuyo RPC padre ya aplicó stock y Kardex.
      // Volver a pasarlas por el RPC de movimiento duplicaría el ajuste.
      const movimientosYaAplicados = rows.filter((m) =>
        /venta pos|recepci.n de compra|anulaci.n de compra/i.test(String(m?.notas || '')) ||
        /venta pos|compra a proveedor|anulaci.n de compra/i.test(String(m?.referencia || ''))
      );
      const pendientes = rows.filter((m) => !movimientosYaAplicados.includes(m));
      let procesados = movimientosYaAplicados.length;
      const errores = [];
      for (const movimiento of pendientes) {
        const result = await supabaseRequest('/rpc/pos_registrar_movimiento_stock', {
          method: 'POST',
          body: JSON.stringify({
            p_empresa_codigo: empresaCodigo,
            p_empresa_id: empresaId,
            p_movimiento: movimiento,
          }),
        });
        if (result.status >= 400) {
          errores.push({ error: result.body });
          continue;
        }
        let saved = {};
        try { saved = JSON.parse(result.body || '{}'); } catch {}
        if (saved.success === true) procesados++;
        else errores.push({ error: 'Supabase no confirmó el movimiento de inventario.' });
      }
      if (procesados === 0 && errores.length) return fail(res, { message: errores.map((e) => e.error).join(' | '), status: 502 });
      return ok(res, { success: true, ok: procesados, errores }, 201);
    }

    // El pago de fiado es idempotente: aplica el abono, actualiza el saldo,
    // registra la entrada contable y deja el historial en una sola transacción.
    if (tabla === 'fiado_abonos' && operacion === 'insert') {
      const errores = [];
      let procesados = 0;
      for (const abono of rows) {
        const result = await supabaseRequest('/rpc/pos_registrar_abono_fiado', {
          method: 'POST',
          body: JSON.stringify({ p_empresa_codigo: empresaCodigo, p_empresa_id: empresaId, p_abono: abono }),
        });
        if (result.status >= 400) { errores.push({ error: result.body }); continue; }
        let saved = {};
        try { saved = JSON.parse(result.body || '{}'); } catch {}
        if (saved.success === true) procesados++;
        else errores.push({ error: 'Supabase no confirmó el abono.' });
      }
      if (procesados === 0 && errores.length) return fail(res, { message: errores.map((e) => e.error).join(' | '), status: 502 });
      return ok(res, { success: true, ok: procesados, errores }, 201);
    }

    // Recepción de compra: registra documento, líneas, stock y Kardex como
    // una sola transacción en PostgreSQL.
    if (tabla === 'compras' && operacion === 'update' && rows.length > 0 && rows.every((compra) => compra?.estado === 'anulada')) {
      const errores = [];
      let procesados = 0;
      for (const compra of rows) {
        const result = await supabaseRequest('/rpc/pos_anular_compra', {
          method: 'POST',
          body: JSON.stringify({
            p_empresa_codigo: empresaCodigo,
            p_empresa_id: empresaId,
            p_compra_id: String(compra.id || ''),
          }),
        });
        if (result.status >= 400) { errores.push({ error: result.body }); continue; }
        let saved = {};
        try { saved = JSON.parse(result.body || '{}'); } catch {}
        if (saved.success === true) procesados++;
        else errores.push({ error: 'Supabase no confirmó la anulación de compra.' });
      }
      if (procesados === 0 && errores.length) return fail(res, { message: errores.map((e) => e.error).join(' | '), status: 502 });
      return ok(res, { success: true, ok: procesados, errores }, 200);
    }

    if (tabla === 'compras' && operacion === 'insert') {
      const errores = [];
      let procesados = 0;
      for (const compra of rows) {
        const result = await supabaseRequest('/rpc/pos_registrar_compra', {
          method: 'POST',
          body: JSON.stringify({ p_empresa_codigo: empresaCodigo, p_empresa_id: empresaId, p_compra: compra }),
        });
        if (result.status >= 400) { errores.push({ error: result.body }); continue; }
        let saved = {};
        try { saved = JSON.parse(result.body || '{}'); } catch {}
        if (saved.success === true) procesados++;
        else errores.push({ error: 'Supabase no confirmó la recepción.' });
      }
      if (procesados === 0 && errores.length) return fail(res, { message: errores.map((e) => e.error).join(' | '), status: 502 });
      return ok(res, { success: true, ok: procesados, errores }, 201);
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
        // Nunca actualices ni borres una fila solo por su id: todo cambio se
        // limita al tenant dueño de la cola que envió la operación.
        const tenantScope = `empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}`;

        if (operacion === 'delete' && id) {
          const del = await supabaseRequest(`/${tabla}?id=eq.${encodeURIComponent(id)}&${tenantScope}`, {
            method: 'DELETE',
          });
          if (del.status >= 400) throw new Error(del.body);
          procesados.push({ id });
          continue;
        }

        if (id) {
          const existing = await supabaseRequest(`/${tabla}?id=eq.${encodeURIComponent(id)}&${tenantScope}&select=id`);
          let rowsFound = [];
          try { rowsFound = JSON.parse(existing.body || '[]'); } catch {}
          if (existing.status < 400 && rowsFound.length > 0) {
            const patch = await supabaseRequest(`/${tabla}?id=eq.${encodeURIComponent(id)}&${tenantScope}`, {
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Handler de Storage (Supabase Storage: upload y delete de imÃ¡genes)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
  if (req.method !== 'POST') return res.status(405).json({ error: 'MÃ©todo no permitido' });
  if (!configured()) return fail(res, { message: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.' });

  try {
    const body = parseBody(req);
    const action = body.action === 'delete' ? 'delete' : 'upload';

    // â”€â”€ Eliminar imagen a partir de su URL pÃºblica â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    // â”€â”€ Subir imagen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      return fail(res, { message: 'base64 invÃ¡lido.', status: 400 });
    }
    if (buffer.length === 0) return fail(res, { message: 'Imagen vacÃ­a.', status: 400 });
    if (buffer.length > 3.5 * 1024 * 1024) {
      return fail(res, { message: 'La imagen excede el lÃ­mite de 3.5 MB.', status: 413 });
    }

    const ext = MIME_EXT[mime] || 'jpg';
    const fileName = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext}`;
    const objectPath = folder ? `${folder}/${fileName}` : fileName;

    // Asegurar que el bucket exista y sea pÃºblico (ignorar si ya existe).
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
