-- =============================================================
-- Portal Pilot APP — Hardening RLS multi-tenant (aislamiento)
-- Ejecutar en: Supabase SQL Editor (proyecto usado por la APP móvil)
-- Idempotente: se puede ejecutar varias veces sin errores.
--
-- PROBLEMA QUE CIERRA:
--   Las tablas de sincronización de la app usan `empresa_codigo TEXT`
--   como columna de tenant, pero varias NO tenían Row Level Security.
--   Con la anon key (empotrada en cualquier cliente) cualquier persona
--   podía leer/escribir filas de OTRO negocio vía PostgREST: dos cuentas
--   de empresas distintas terminaban "compartiendo" la misma base.
--
-- QUÉ HACE:
--   1) Activa RLS en TODAS las tablas de negocio con `empresa_codigo`.
--   2) Elimina cualquier política previa de esas tablas y deja una única
--      política por tabla: solo `service_role` (el backend serverless).
--   3) Revoca SELECT/INSERT/UPDATE/DELETE a `anon` y `authenticated`:
--      aunque alguien consiga la anon key, PostgREST responde vacío/401.
--   4) `tenants` y `empresas` quedan igual de cerrados: el backend resuelve
--      el tenant con la clave de servicio; el cliente nunca los consulta.
--
-- NOTA: los handlers de `PP APP/api` (y el backend web) usan
-- SUPABASE_SERVICE_ROLE_KEY (bypass de RLS) y filtran SIEMPRE por el
-- `empresa_codigo` del JWT del usuario (verifiedTenantCode /
-- requireTenantClaims / withTenantScope), por lo que no se rompe nada.
-- =============================================================

-- ── Helper: cierra una tabla al acceso directo del cliente ──
CREATE OR REPLACE FUNCTION pp_cerrar_tabla_tenant(t TEXT)
RETURNS void AS $$
DECLARE
  pol RECORD;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema = 'public' AND table_name = t) THEN
    RETURN; -- la tabla no existe en este proyecto (migración parcial): nada que hacer
  END IF;

  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

  -- Quitar TODAS las políticas previas de la tabla (pg_policies es una vista:
  -- el drop se hace con DDL dinámico, no con DELETE).
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = t
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, t);
  END LOOP;

  -- Política única: el backend (service_role) conserva acceso total.
  EXECUTE format(
    'CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)',
    t || '_service_role_only', t
  );

  -- Cerrar el acceso directo de la anon key y de usuarios auth a PostgREST.
  EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
  EXECUTE format('REVOKE ALL ON public.%I FROM authenticated', t);
  EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
END;
$$ LANGUAGE plpgsql;

-- ── Tablas del sync de la app con columna de tenant empresa_codigo ──
SELECT pp_cerrar_tabla_tenant(t) FROM unnest(ARRAY[
  'kardex','system_logs','facturas','transacciones','clientes','productos',
  'ventas','notas_estado','proveedores','cotizaciones','cotizacion_items',
  'ordenes_compra','orden_compra_items','compras','compra_items',
  'configuracion_fiscal','bodegas','matriculas','notas','empleados','nomina',
  'fiado_abonos','rutas','ruta_clientes','sucursales','transferencias',
  'transferencia_items','membresias','socios','socio_membresias',
  'socio_precios','sar_correlativo','sar_contingencia','pos_arqueo_caja',
  'pos_promociones','pos_cliente_credito','pos_config','pos_ventas',
  'tenants','empresas'
]) AS t;

-- ── Limpieza del helper (opcional; coméntalo si quieres conservarlo) ──
DROP FUNCTION IF EXISTS pp_cerrar_tabla_tenant(TEXT);

-- ── Verificación rápida (correr aparte en el SQL Editor) ─────
-- SELECT tablename, policyname, roles FROM pg_policies
--  WHERE schemaname = 'public' ORDER BY tablename, policyname;
