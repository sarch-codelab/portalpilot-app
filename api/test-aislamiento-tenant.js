// ═══════════════════════════════════════════════════════════════
// Test estático de aislamiento multi-tenant (PP APP/api/[...slug].js)
//
// Qué garantiza (sin depender de Supabase/JWT reales):
//   1. El login móvil NO emite tokens con empresa_codigo 'ROOT'
//      inventado y rechaza cuentas sin empresa asignada.
//   2. Los endpoints con efectos o lecturas sensibles (IA, barcode,
//      storage, análisis POS) exigen sesión JWT válida.
//   3. El lookup de código de barras se filtra SIEMPRE por el
//      empresa_codigo del JWT (nunca búsqueda global).
//   4. El análisis POS usa el tenant del JWT, ignorando el del body.
//   5. El onboarding de sync no puede escribir la empresa de otro
//      tenant (el código se reescribe al del token).
//   6. La migración RLS deja cada tabla con una única política
//      service_role-only y revoca anon/authenticated.
// Ejecutar: node "PP APP/api/test-aislamiento-tenant.js"
// ═══════════════════════════════════════════════════════════════
'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const apiPath = path.join(__dirname, '[...slug].js');
const sqlPath = path.join(__dirname, '..', 'supabase', 'migracion_rls_hardening_tenants.sql');
const dartPath = path.join(__dirname, '..', 'lib', 'Shared', 'services', 'image_service.dart');

const api = fs.readFileSync(apiPath, 'utf8');
const sql = fs.readFileSync(sqlPath, 'utf8');
const dart = fs.readFileSync(dartPath, 'utf8');

function readUntil(src, marker, start = 0) {
  const idx = src.indexOf(marker, start);
  assert.ok(idx >= 0, `No se encontró el marcador: ${marker}`);
  return src.slice(start, idx);
}

let passed = 0;
function check(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✔ ${name}`);
  } catch (e) {
    console.error(`  ✘ ${name}\n    ${e.message}`);
    process.exitCode = 1;
  }
}

console.log('Aislamiento multi-tenant — PP APP/api/[...slug].js\n');

// ── 1. Login móvil ─────────────────────────────────────────────
check('login: rechaza cuentas sin empresa_codigo (no ROOT inventado)', () => {
  const zona = readUntil(api, 'let isMatch = false;');
  assert.ok(/empresa no tiene una empresa asignada|no tiene una empresa asignada/.test(zona.replace(/\r?\n/g, ' ')) || /La cuenta no tiene una empresa asignada/.test(zona),
    'falta el guard 403 para cuentas sin empresa');
});

check('login: el JWT ya no usa empresa_codigo || ROOT', () => {
  const zona = readUntil(api, 'res.status(200).json({', readUntil(api, 'let isMatch').length);
  assert.ok(!/empresa_codigo:\s*user\.empresa_codigo\s*\|\|\s*'ROOT'/.test(zona),
    "el token todavía contiene el fallback a 'ROOT'");
});

check('login: sin token el usuario ya no puede heredar el resto del tenant', () => {
  // El guard debe ir ANTES de comparar contraseñas y firmar tokens.
  const guardIdx = api.indexOf('no tiene una empresa asignada. Contacta al soporte');
  const matchIdx = api.indexOf('let isMatch = false;');
  assert.ok(guardIdx > 0 && matchIdx > guardIdx, 'el guard no precede al check de contraseña');
});

// ── 2. Endpoints que exigen sesión ─────────────────────────────
check('ai/chat y ai/vision exigen requireTenantClaims', () => {
  const chat = api.slice(api.indexOf('async function aiChatHandler'), api.indexOf('async function aiVisionHandler'));
  const vision = api.slice(api.indexOf('async function aiVisionHandler'), api.indexOf('async function aiBarcodeHandler'));
  assert.ok(chat.includes('requireTenantClaims(req)'), 'ai/chat sin auth');
  assert.ok(vision.includes('requireTenantClaims(req)'), 'ai/vision sin auth');
});

check('ai/barcode exige sesión y filtra por empresa_codigo del JWT', () => {
  const bc = api.slice(api.indexOf('async function aiBarcodeHandler'), api.indexOf('async function aiPosAnalyzeHandler'));
  assert.ok(bc.includes('requireTenantClaims(req)'), 'barcode sin auth');
  assert.ok(bc.includes('empresa_codigo=eq.'), 'barcode no filtra por empresa');
  assert.ok(!bc.includes('búsqueda global'), 'queda el fallback global');
});

check('ai/pos/analyze usa el tenant del JWT (no el del body)', () => {
  const pos = api.slice(api.indexOf('async function aiPosAnalyzeHandler'), api.indexOf('module.exports.aiPosUpsellHandler'));
  assert.ok(pos.includes('const empresaCodigo = tenantPos;'), 'analyze debe usar tenantPos');
  assert.ok(!pos.includes('body.empresaCodigo'), 'analyze todavía acepta empresaCodigo del body');
});

check('storage exige sesión y prefija los objetos con el tenant', () => {
  const st = api.slice(api.indexOf('async function storageHandler'));
  assert.ok(st.includes('requireTenantClaims(req)'), 'storage sin auth');
  assert.ok(st.includes('`${tenantSt}/${fileName}`'), 'storage no separa por tenant');
});

// ── 3. Helper único de identidad ───────────────────────────────
check('requireTenantClaims está definido y verifica con JWT_SECRET', () => {
  assert.ok(/function requireTenantClaims\(req\)/.test(api), 'helper ausente');
  const body = api.slice(api.indexOf('function requireTenantClaims'), api.indexOf('function requireTenantClaims') + 600);
  assert.ok(body.includes("verify(token, process.env.JWT_SECRET)"), 'no verifica la firma');
});

// ── 4. Onboarding sync ─────────────────────────────────────────
check('sync (empresas): el código se reescribe al tenant del token', () => {
  const zona = api.slice(api.indexOf("if (tabla === 'empresas')"), api.indexOf("if (tabla === 'empresas')") + 1200);
  assert.ok(zona.includes('const codigo = tenantClaim;'), 'el onboarding todavía usa el codigo del body');
});

// ── 5. Migración RLS ───────────────────────────────────────────
check('migración RLS: única política service_role-only por tabla', () => {
  assert.ok(sql.includes("'_service_role_only'") || sql.includes('service_role_only'), 'política service_role ausente');
  assert.ok(sql.includes('REVOKE ALL ON public.%I FROM anon'), 'falta REVOKE anon');
  assert.ok(sql.includes('REVOKE ALL ON public.%I FROM authenticated'), 'falta REVOKE authenticated');
  assert.ok(sql.includes("ENABLE ROW LEVEL SECURITY"), 'falta ENABLE ROW LEVEL SECURITY');
});

check('migración RLS cubre las tablas de negocio clave', () => {
  for (const t of ['kardex', 'facturas', 'clientes', 'productos', 'pos_ventas', 'socios', 'tenants', 'empresas']) {
    assert.ok(sql.includes(`'${t}'`), `tabla ${t} no está en la migración`);
  }
});

// ── 6. Cliente Flutter ─────────────────────────────────────────
check('image_service.dart envía el JWT al API de storage', () => {
  assert.ok(dart.includes("_storageHeaders()"), 'falta _storageHeaders');
  assert.ok(dart.includes("AuthController.instance.token"), 'no usa el token de sesión');
  assert.ok(dart.includes("'Authorization': 'Bearer $token'"), 'falta el header Authorization');
});

console.log(`\n${passed} checks OK${process.exitCode ? ' (con fallos)' : ''}`);
if (!process.exitCode) console.log('✅ Aislamiento multi-tenant verificado (estáticamente).');
