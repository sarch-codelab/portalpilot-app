/**
 * Vercel Serverless Function: /api/login
 * 
 * Autentica usuarios consultando la tabla 'usuarios' en NocoDB (app.nocodb.com)
 * usando el token PAT configurado en AUTH_BACKEND_URL o AUTH_BACKEND_TOKEN.
 * 
 * Variables de entorno requeridas en Vercel:
 *   AUTH_BACKEND_URL    → Token PAT de NocoDB (nc_pat_...) o URL base de NocoDB
 *   NOCODB_BASE_ID      → ID de la base/proyecto en NocoDB (ej: p69dy4zcqfhddyp)
 *   NOCODB_TABLE_NAME   → Nombre de la tabla de usuarios (default: 'usuarios')
 * 
 * Variables opcionales para fallback de emergencia:
 *   AUTH_BACKEND_LOGIN_FALLBACK       → 'true' para activar usuario de emergencia
 *   AUTH_BACKEND_FALLBACK_EMAILS      → emails separados por coma
 *   AUTH_BACKEND_FALLBACK_PASSWORD    → contraseña de emergencia
 */

module.exports = async function handler(req, res) {
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

  // ── Configuración NocoDB ──────────────────────────────────────────────────
  const rawAuth = (process.env.AUTH_BACKEND_URL || '').trim();
  const tokenEnv = (process.env.AUTH_BACKEND_TOKEN || '').trim();
  const nocodbBaseId = (process.env.NOCODB_BASE_ID || '').trim();
  const nocodbTableName = (process.env.NOCODB_TABLE_NAME || 'usuarios').trim();
  const nocodbApiUrl = (process.env.NOCODB_API_URL || 'https://app.nocodb.com').trim().replace(/\/$/, '');

  // El token puede estar en AUTH_BACKEND_URL (como nc_pat_...) o en AUTH_BACKEND_TOKEN
  const isToken = rawAuth.startsWith('nc_pat_') || rawAuth.startsWith('nc_');
  const nocodbToken = isToken ? rawAuth : tokenEnv;

  // ── Intento 1: Consultar tabla 'usuarios' en NocoDB ───────────────────────
  if (nocodbToken && nocodbBaseId) {
    try {
      const result = await loginWithNocoDB({
        apiUrl: nocodbApiUrl,
        token: nocodbToken,
        baseId: nocodbBaseId,
        tableName: nocodbTableName,
        email,
        password,
      });
      if (result) {
        res.status(200).json(result);
        return;
      }
    } catch (err) {
      console.error('[login] Error consultando NocoDB:', err.message);
      // Si hay un error claro de autenticación, devolver error
      if (err.message && err.message.startsWith('AUTH_')) {
        const msg = err.message.replace('AUTH_', '');
        res.status(401).json({ error: msg });
        return;
      }
      // Otros errores: continuar al fallback
    }
  }

  // ── Intento 2: Fallback de emergencia ─────────────────────────────────────
  // Las credenciales de emergencia DEBEN definirse explícitamente en el entorno.
  // Sin AUTH_BACKEND_LOGIN_FALLBACK='true' + emails/password/token configurados,
  // el fallback nunca se activa.
  const fallbackEnabled = (process.env.AUTH_BACKEND_LOGIN_FALLBACK || '').trim().toLowerCase() === 'true';
  const fallbackEmails = (process.env.AUTH_BACKEND_FALLBACK_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  const fallbackPassword = (process.env.AUTH_BACKEND_FALLBACK_PASSWORD || '').trim();
  const fallbackToken = (process.env.AUTH_BACKEND_FALLBACK_TOKEN || '').trim();

  if (fallbackEnabled && fallbackEmails.length > 0 && fallbackToken && fallbackPassword && fallbackEmails.includes(email) && password === fallbackPassword) {
    res.status(200).json({
      user: {
        id: 'fallback-user',
        nombre: 'PortalPilot',
        apellido: 'Admin',
        email: email,
        rol: 'Administrador',
        area: 'Educacion',
        rango: 'Admin',
        status: 'active',
        empresa_codigo: 'ROOT',
        empresa_nombre: 'Portal Pilot',
      },
      token: fallbackToken,
    });
    return;
  }

  // ── Error final ───────────────────────────────────────────────────────────
  const missingConfig = !nocodbToken
    ? 'AUTH_BACKEND_URL (token PAT de NocoDB) no está configurado en Vercel.'
    : !nocodbBaseId
    ? 'NOCODB_BASE_ID no está configurado en Vercel. Ve a NocoDB → tu proyecto → copia el ID de la URL.'
    : 'No se pudo autenticar. Verifica las credenciales.';

  res.status(500).json({
    error: missingConfig,
    debug: {
      hasToken: Boolean(nocodbToken),
      hasBaseId: Boolean(nocodbBaseId),
      tableName: nocodbTableName,
      fallbackEnabled,
      hint: 'Configura NOCODB_BASE_ID en Vercel con el ID de tu proyecto NocoDB (ej: p69dy4zcqfhddyp)',
    },
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// Función: loginWithNocoDB
// Consulta la tabla de usuarios en NocoDB y valida las credenciales
// ─────────────────────────────────────────────────────────────────────────────
async function loginWithNocoDB({ apiUrl, token, baseId, tableName, email, password }) {
  // NocoDB API v2 endpoint para buscar registros en una tabla
  // GET /api/v2/tables/{tableId}/records?where=(email,eq,{email})
  // Primero obtenemos la lista de tablas para encontrar el ID de 'usuarios'
  
  const headers = {
    'Content-Type': 'application/json',
    'xc-token': token,
  };

  // Paso 1: Obtener las tablas de la base de datos para encontrar el tableId
  let tableId = null;
  
  try {
    const tablesUrl = `${apiUrl}/api/v2/meta/bases/${baseId}/tables`;
    const tablesRes = await fetch(tablesUrl, { headers });
    
    if (tablesRes.ok) {
      const tablesData = await tablesRes.json();
      const tables = tablesData.list || tablesData.tables || tablesData || [];
      const found = tables.find(
        (t) => t.title?.toLowerCase() === tableName.toLowerCase() ||
               t.table_name?.toLowerCase() === tableName.toLowerCase()
      );
      if (found) {
        tableId = found.id;
      }
    }
  } catch (err) {
    console.error('[NocoDB] Error obteniendo tablas:', err.message);
  }

  // Paso 2: Buscar el usuario por email
  let userRecord = null;
  
  if (tableId) {
    // Usar el tableId encontrado con API v2
    const where = encodeURIComponent(`(email,eq,${email})`);
    const recordsUrl = `${apiUrl}/api/v2/tables/${tableId}/records?where=${where}&limit=1`;
    const recordsRes = await fetch(recordsUrl, { headers });
    
    if (recordsRes.ok) {
      const data = await recordsRes.json();
      const records = data.list || data.data?.list || data.records || [];
      if (records.length > 0) {
        userRecord = records[0];
      }
    }
  } else {
    // Fallback: intentar con el nombre de tabla directamente (API v1)
    const where = encodeURIComponent(`(email,eq,${email})`);
    const recordsUrl = `${apiUrl}/api/v1/db/data/noco/${baseId}/${tableName}?where=${where}&limit=1`;
    const recordsRes = await fetch(recordsUrl, { headers });
    
    if (recordsRes.ok) {
      const data = await recordsRes.json();
      const records = data.list || data.data?.list || data.records || [];
      if (records.length > 0) {
        userRecord = records[0];
      }
    }
  }

  if (!userRecord) {
    throw new Error('AUTH_Credenciales inválidas. Usuario no encontrado.');
  }

  // Paso 3: Validar la contraseña
  const storedPassword = userRecord.password || userRecord.contrasena || userRecord.contraseña || '';
  const passwordMatch = await comparePassword(password, storedPassword);
  
  if (!passwordMatch) {
    throw new Error('AUTH_Credenciales inválidas. Contraseña incorrecta.');
  }

  // Paso 4: Verificar que el usuario esté activo
  const userStatus = (userRecord.status || userRecord.estado || 'active').toLowerCase();
  if (userStatus !== 'active' && userStatus !== 'activo') {
    throw new Error('AUTH_Tu cuenta está pendiente de activación por el Owner.');
  }

  // Paso 5: Construir respuesta en el formato que espera Flutter
  const userId = (userRecord.Id || userRecord.id || userRecord.ID || '').toString();
  const simpleToken = `pp_token_${userId}_${Date.now()}`;

  return {
    user: {
      id: userId,
      nombre: userRecord.nombre || userRecord.name || userRecord.first_name || '',
      apellido: userRecord.apellido || userRecord.last_name || userRecord.apellidos || '',
      email: userRecord.email || email,
      rol: userRecord.rol || userRecord.role || userRecord.cargo || 'Empleado',
      area: userRecord.area || userRecord.department || '',
      rango: userRecord.rango || userRecord.rank || '',
      status: userStatus,
      empresa_codigo: (userRecord.empresa_codigo || userRecord.company_code || '').toUpperCase(),
      empresa_nombre: userRecord.empresa_nombre || userRecord.company_name || '',
    },
    token: simpleToken,
  };
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
