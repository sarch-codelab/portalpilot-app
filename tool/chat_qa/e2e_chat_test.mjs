// Prueba end-to-end del flujo de reportes del Chat IA contra PRODUCCIÓN
// (portal-pilot.vercel.app) con login real y el MISMO prompt maestro que
// genera la app. Replica la lógica del parser para decidir qué pasaría en la app.
import { readFileSync } from 'node:fs';

const API = 'https://portal-pilot.vercel.app';
const systemPrompt = readFileSync('build/system_prompt_real.txt', 'utf8');

// 1. Login real
const loginRes = await fetch(`${API}/api/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'qa.chat@portalpilot-test.hn', password: 'QaChat2026!' }),
});
if (!loginRes.ok) {
  console.error('LOGIN FALLÓ:', loginRes.status, await loginRes.text());
  process.exit(1);
}
const { token } = await loginRes.json();
console.log('✅ Login real OK (empresa PP-48GX-Q8ME / Mini Market Pilot)\n');

// 2. Mapa de herramientas: EXACTAMENTE el mismo que ReportToolType.fromName
const HERRAMIENTAS = {
  gastos: 'gastos', gasto: 'gastos', egresos: 'gastos', egreso: 'gastos',
  ventas: 'ventas', venta: 'ventas', ingresos: 'ventas', ingreso: 'ventas',
  movimientos: 'inventario_movimientos', entradas_salidas: 'inventario_movimientos',
  'inventario_movimientos': 'inventario_movimientos', kardex: 'inventario_movimientos',
  'entradas y salidas': 'inventario_movimientos',
  stock: 'stock', inventario: 'stock', inventario_actual: 'stock', existencias: 'stock',
  compras: 'compras', compra: 'compras', adquisiciones: 'compras', compras_realizadas: 'compras',
  clientes: 'clientes', cliente: 'clientes', directorio: 'clientes', lista_clientes: 'clientes',
  facturacion: 'facturacion', 'facturación': 'facturacion', facturas: 'facturacion',
  facturas_emitidas: 'facturacion', facturacion_sar: 'facturacion', ventas_facturadas: 'facturacion',
  cuentas_por_cobrar: 'cuentas_por_cobrar', 'cuentas por cobrar': 'cuentas_por_cobrar',
  cxc: 'cuentas_por_cobrar', fiado: 'cuentas_por_cobrar', creditos: 'cuentas_por_cobrar',
  'créditos': 'cuentas_por_cobrar', pendientes_de_cobro: 'cuentas_por_cobrar',
  caja: 'caja', arqueo: 'caja', arqueos: 'caja', movimientos_caja: 'caja',
  cuadre_caja: 'caja', arqueos_caja: 'caja',
  resumen_financiero: 'resumen_financiero', 'resumen financiero': 'resumen_financiero',
  financiero: 'resumen_financiero', estado_financiero: 'resumen_financiero',
  utilidad: 'resumen_financiero', 'estado de resultados': 'resumen_financiero', balance: 'resumen_financiero',
  empleados: 'empleados', empleado: 'empleados', personal: 'empleados',
  nomina: 'empleados', 'nómina': 'empleados', planilla: 'empleados',
};

function extraerJson(texto) {
  const m = texto.match(/\{[^{}]*["']tool["'][^{}]*\}/);
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch { return null; }
}

async function enviar(message, contextoExtra) {
  let sp = systemPrompt;
  if (contextoExtra) sp += '\n\n## CONTEXTO ADICIONAL\n' + contextoExtra;
  const r = await fetch(`${API}/api/ai/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ message, systemPrompt: sp, maxTokens: 1600, temperature: 0.4 }),
  });
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const d = await r.json();
  return d.reply || '';
}

const casos = [
  { n: 1, msg: 'Dame un reporte de lo que sea', nota: 'CASO ORIGINAL del usuario (ambiguo)' },
  { n: 2, msg: 'dame un informe de inventario en PDF', nota: 'debe ir a stock' },
  { n: 3, msg: 'muéstrame un reporte de ventas de este mes', nota: 'debe ir a ventas' },
];

for (const c of casos) {
  process.stdout.write(`\n═══ CASO ${c.n}: "${c.msg}"  (${c.nota}) ═══\n`);
  let reply = await enviar(c.msg);
  let json = extraerJson(reply);
  let tool = json ? HERRAMIENTAS[json.tool] : null;

  // EXACTAMENTE lo que hace la app ahora: hasta 2 reintentos con contexto
  // correctivo y, si la IA sigue inventando, fallback por palabras clave.
  let vueltas = 0;
  let correctionContext = '';
  while (json && !tool && vueltas < 2) {
    vueltas++;
    process.stdout.write(`  [intento ${vueltas}] tool inventada "${json.tool}" → REINTENTANDO con lista válida…\n`);
    reply = await enviar(
      c.msg,
      (vueltas === 1
        ? `Tu respuesta anterior fue invalida: usaste la herramienta "${json.tool}" que NO existe. `
        : `Tu respuesta anterior fue invalida otra vez: usaste la herramienta "${json.tool}" que NO existe. COPIA EXACTAMENTE uno de estos nombres: `) +
      'Herramientas validas: gastos, ventas, inventario_movimientos, stock, compras, clientes, ' +
      'facturacion, cuentas_por_cobrar, caja, resumen_financiero, empleados. ' +
      (vueltas === 1
        ? 'Si la peticion del usuario no corresponde a ninguna, responde en texto sin JSON. Vuelve a responder a: '
        : 'Si no corresponde ninguna, responde SOLO texto plano sin llaves JSON. Vuelve a responder a: ') + c.msg,
    );
    json = extraerJson(reply);
    tool = json ? HERRAMIENTAS[json.tool] : null;
  }

  // Fallback final de la app: infiere por palabras del mensaje del usuario
  if (json && !tool) {
    const PALABRAS = ['gastos', 'gasto', 'egresos', 'ventas', 'venta', 'ingresos', 'kardex',
      'movimientos de inventario', 'inventario_movimientos', 'existencias', 'inventario', 'stock',
      'compras', 'compra', 'clientes', 'cliente', 'facturacion', 'facturación', 'facturas',
      'cuentas por cobrar', 'cuentas_por_cobrar', 'fiado', 'creditos', 'créditos', 'caja', 'arqueo',
      'resumen financiero', 'resumen_financiero', 'financiero', 'utilidad', 'empleados', 'empleado',
      'nomina', 'nómina', 'planilla'];
    const low = c.msg.toLowerCase();
    let cat = null;
    for (const k of PALABRAS) {
      if (low.includes(k) && (cat === null || k.length > cat.length)) cat = k;
    }
    if (cat) {
      tool = HERRAMIENTAS[cat] || null;
      if (tool) process.stdout.write(`  [fallback] inferido por palabras clave "${cat}" → ${tool}\n`);
    }
  }

  console.log(`  [respuesta] ${reply.replace(/\s+/g, ' ').slice(0, 200)}`);
  if (tool) {
    console.log(`  ✅ RESULTADO: ejecutaría "${tool}" → reporte con datos reales (el usuario NUNCA ve JSON)`);
  } else if (!json) {
    console.log('  ✅ RESULTADO: responde texto normal (sin JSON crudo) — correcto para petición ambigua');
  } else {
    console.log(`  ❌ RESULTADO: seguiría mostrando JSON crudo con tool "${json.tool}"`);
  }
}
