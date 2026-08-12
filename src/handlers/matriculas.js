const ESTADOS_VALIDOS = ['pendiente', 'activa', 'inactiva', 'retirada', 'graduada'];

// Mapea los 29 campos enviados por la app a las columnas del esquema SQL.
function mapMatriculaPayload(body) {
  const b = body || {};

  const nombreCompleto = [b.alumno_nombre, b.alumno_apellido]
    .filter((v) => v && v.trim())
    .join(' ')
    .trim();

  let estado = (b.estado || 'pendiente').toString().trim().toLowerCase();
  if (!ESTADOS_VALIDOS.includes(estado)) estado = 'pendiente';

  return {
    // Columnas originales del esquema
    estudiante_nombre: nombreCompleto || 'Sin nombre',
    estudiante_id: b.alumno_dni || null,
    grado: b.grado || null,
    seccion: b.seccion || null,
    turno: b.turno || null,
    estado,
    observaciones: b.observaciones_salud || null,

    // Columnas nuevas (migracion_matriculas.sql)
    folio_matricula: b.folio_matricula || null,
    empresa_codigo: b.empresa_codigo || null,
    ciclo_escolar: b.ciclo_escolar || null,
    nivel_educativo: b.nivel_educativo || null,
    tipo_ingreso: b.tipo_ingreso || null,
    alumno_nombre: b.alumno_nombre || null,
    alumno_apellido: b.alumno_apellido || null,
    alumno_dni: b.alumno_dni || null,
    alumno_fecha_nacimiento: b.alumno_fecha_nacimiento || null,
    alumno_lugar_nacimiento: b.alumno_lugar_nacimiento || null,
    alumno_nacionalidad: b.alumno_nacionalidad || null,
    observaciones_salud: b.observaciones_salud || null,
    tutor_parentesco: b.tutor_parentesco || null,
    tutor_nombre: b.tutor_nombre || null,
    tutor_telefono: b.tutor_telefono || null,
    tutor_email: b.tutor_email || null,
    direccion_calle: b.direccion_calle || null,
    direccion_municipio: b.direccion_municipio || null,
    direccion_departamento: b.direccion_departamento || null,
    direccion_referencia: b.direccion_referencia || null,
    direccion_cp: b.direccion_cp || null,
    pago_inscripcion_realizado: Boolean(b.pago_inscripcion_realizado),
    metodo_pago: b.metodo_pago || null,
    plan_pagos: b.plan_pagos || null,
  };
}

async function supabaseRequest(path, options = {}) {
  const url = `${process.env.SUPABASE_URL}/rest/v1${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      apikey: process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '',
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  return {
    status: response.status,
    body: text,
  };
}

// Resuelve empresa_codigo (texto) → empresa_id (UUID) contra la tabla empresas.
// Best-effort: si la tabla no existe (42P01) o no hay match, devuelve null.
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

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    res.status(500).json({
      error: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en Vercel.',
    });
    return;
  }

  if (req.method === 'GET') {
    const empresaCodigo = req.query?.empresaCodigo || '';
    const query = empresaCodigo
      ? `?empresa_codigo=eq.${encodeURIComponent(empresaCodigo)}&order=created_at.desc&limit=50`
      : '?order=created_at.desc&limit=50';

    const result = await supabaseRequest(`/matriculas${query}`);
    if (result.status >= 400) {
      // Si la columna empresa_codigo aún no existe (migración pendiente),
      // devolver todo y filtrar en memoria.
      if (empresaCodigo && (result.status === 400 || result.status === 500)) {
        const all = await supabaseRequest('/matriculas?order=created_at.desc&limit=500');
        if (all.status >= 400) {
          res.status(all.status).json({ error: all.body });
          return;
        }
        try {
          const rows = JSON.parse(all.body || '[]');
          const filtered = rows.filter((r) => r.empresa_codigo === empresaCodigo);
          res.status(200).json(filtered);
          return;
        } catch {
          res.status(500).json({ error: 'Respuesta inválida de Supabase.' });
          return;
        }
      }
      res.status(result.status).json({ error: result.body });
      return;
    }

    res.status(200).json(JSON.parse(result.body));
    return;
  }

  if (req.method === 'POST') {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};

    if (!body.empresa_codigo) {
      res.status(400).json({ error: 'Falta empresa_codigo. No se puede asociar la matrícula a un tenant.' });
      return;
    }

    const empresaId = await resolverEmpresaId(body.empresa_codigo); // best-effort, puede ser null

    const payload = {
      ...mapMatriculaPayload(body),
    };
    if (empresaId) payload.empresa_id = empresaId;

    const result = await supabaseRequest('/matriculas', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    if (result.status >= 400) {
      res.status(result.status).json({ error: result.body });
      return;
    }

    res.status(200).json({ success: true, data: JSON.parse(result.body) });
  } else {
    res.status(405).json({ error: 'Método no permitido' });
  }
};
