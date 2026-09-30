// Crea un usuario QA temporal (empresa PP-48GX-Q8ME, que ya tiene facturas
// reales) para poder hacer login contra la API desplegada y probar el chat.
const fs = require('node:fs');
const path = require('node:path');
const bcrypt = require('bcryptjs');

// Carga .env.prod
fs.readFileSync(path.join(__dirname, '..', '..', '.env.prod'), 'utf8')
  .split(/\r?\n/).forEach((l) => {
    const m = l.match(/^([A-Z_0-9]+)=(.*)$/);
    if (m) process.env[m[1]] = m[2].replace(/^"|"$/g, '');
  });

const SB = process.env.SUPABASE_URL.replace(/\/+$/, '');
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const H = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };

async function main() {
  const email = 'qa.chat@portalpilot-test.hn';
  // ¿Ya existe?
  const ex = await fetch(`${SB}/rest/v1/usuarios?email=eq.${encodeURIComponent(email)}&select=id,empresa_codigo`).then(r => r.json());
  const hash = bcrypt.hashSync('QaChat2026!', 10);
  if (Array.isArray(ex) && ex.length > 0) {
    await fetch(`${SB}/rest/v1/usuarios?id=eq.${ex[0].id}`, {
      method: 'PATCH', headers: H,
      body: JSON.stringify({ password_hash: hash, rol: 'admin', empresa_codigo: 'PP-48GX-Q8ME' }),
    });
    console.log('usuario QA actualizado:', ex[0].id);
  } else {
    const r = await fetch(`${SB}/rest/v1/usuarios`, {
      method: 'POST', headers: H,
      body: JSON.stringify({
        email,
        nombre: 'QA',
        apellido: 'Chat',
        rol: 'admin',
        empresa_codigo: 'PP-48GX-Q8ME',
        password_hash: hash,
        activo: true,
      }),
    });
    const body = await r.text();
    console.log('usuario QA creado:', r.status, body.slice(0, 200));
  }
}

main().catch(e => { console.error(e); process.exit(1); });
