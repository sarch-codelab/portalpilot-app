-- =============================================================
-- Portal Pilot — Migración Sync App (CORREGIDA)
-- Ejecutar en: Supabase SQL Editor (https://supabase.com/dashboard)
-- Idempotente: se puede ejecutar varias veces sin errores.
--
-- Cambios frente a la versión anterior:
--  1) TODAS las tablas usan `empresa_codigo TEXT` como columna de
--     tenant, SIN FOREIGN KEY rígida a `empresas`/`tenants`
--     (evita el error 42P01 "relation ... does not exist" si la
--     tabla de empresas tiene otro nombre o aún no existe).
--  2) Se conserva `empresa_id UUID` (nullable, sin FK) para que los
--     endpoints serverless que insertan con el UUID resuelto sigan
--     funcionando.
--  3) Las políticas RLS filtran por `empresa_codigo` comparando el
--     claim del JWT, sin referenciar tablas que puedan no existir.
-- =============================================================

-- -------------------------------------------------------------
-- Helper: trigger auto-update updated_at
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------
-- 1. FACTURAS (módulo Facturación electrónica + POS)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS facturas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo TEXT NOT NULL,              -- tenant (código, sin FK)
  empresa_id UUID,                           -- UUID resuelto (opcional, sin FK)

  correlativo TEXT NOT NULL,
  tipo_documento TEXT NOT NULL DEFAULT 'Factura'
    CHECK (tipo_documento IN ('Factura', 'Nota Crédito', 'Nota Débito', 'Factura Exportación')),

  cai TEXT NOT NULL,
  rango_inicio TEXT,
  rango_fin TEXT,
  fecha_limite_emision DATE,

  cliente_nombre TEXT,
  cliente_rtn TEXT,
  cliente_direccion TEXT,
  condicion_pago TEXT DEFAULT 'Contado',
  tipo_venta TEXT DEFAULT 'Gravada'
    CHECK (tipo_venta IN ('Gravada', 'Exenta', 'Exonerada')),

  items JSONB DEFAULT '[]'::JSONB,
  subtotal NUMERIC(12,2) DEFAULT 0,
  isv_15 NUMERIC(12,2) DEFAULT 0,
  isv_18 NUMERIC(12,2) DEFAULT 0,
  descuento NUMERIC(12,2) DEFAULT 0,
  total NUMERIC(12,2) DEFAULT 0,

  estado TEXT DEFAULT 'emitida'
    CHECK (estado IN ('emitida', 'pendiente', 'anulada', 'pagada')),
  fecha_anulacion TIMESTAMPTZ,
  motivo_anulacion TEXT,

  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Si la tabla ya existía (schema.sql) sin la columna, la agrega:
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS empresa_codigo TEXT;
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS empresa_id UUID;

CREATE INDEX IF NOT EXISTS idx_facturas_empresa_codigo ON facturas(empresa_codigo);
CREATE INDEX IF NOT EXISTS idx_facturas_fecha ON facturas(created_at);
CREATE INDEX IF NOT EXISTS idx_facturas_estado ON facturas(estado);

DROP TRIGGER IF EXISTS trigger_facturas_updated ON facturas;
CREATE TRIGGER trigger_facturas_updated BEFORE UPDATE ON facturas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------------
-- 2. TRANSACCIONES (módulo Contabilidad)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transacciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo TEXT NOT NULL,              -- tenant (código, sin FK)
  empresa_id UUID,                           -- UUID resuelto (opcional, sin FK)

  tipo TEXT NOT NULL
    CHECK (tipo IN ('ingreso', 'gasto', 'transferencia', 'ajuste')),
  categoria TEXT,
  descripcion TEXT,
  monto NUMERIC(12,2) NOT NULL,

  metodo_pago TEXT
    CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'cheque', 'otro')),
  referencia TEXT,

  fecha TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE transacciones ADD COLUMN IF NOT EXISTS empresa_codigo TEXT;
ALTER TABLE transacciones ADD COLUMN IF NOT EXISTS empresa_id UUID;

CREATE INDEX IF NOT EXISTS idx_transacciones_empresa_codigo ON transacciones(empresa_codigo);
CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones(fecha);
CREATE INDEX IF NOT EXISTS idx_transacciones_tipo ON transacciones(tipo);

DROP TRIGGER IF EXISTS trigger_transacciones_updated ON transacciones;
CREATE TRIGGER trigger_transacciones_updated BEFORE UPDATE ON transacciones
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------------
-- 3. CLIENTES (módulo Facturación / CRM)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo TEXT NOT NULL,              -- tenant (código, sin FK)
  empresa_id UUID,                           -- UUID resuelto (opcional, sin FK)

  nombre TEXT NOT NULL,
  rtn TEXT,
  direccion TEXT,
  telefono TEXT,
  email TEXT,
  notas TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clientes ADD COLUMN IF NOT EXISTS empresa_codigo TEXT;
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS empresa_id UUID;

CREATE INDEX IF NOT EXISTS idx_clientes_empresa_codigo ON clientes(empresa_codigo);

DROP TRIGGER IF EXISTS trigger_clientes_updated ON clientes;
CREATE TRIGGER trigger_clientes_updated BEFORE UPDATE ON clientes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------------
-- 4. PRODUCTOS (módulo Inventario / POS)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo TEXT NOT NULL,              -- tenant (código, sin FK)
  empresa_id UUID,                           -- UUID resuelto (opcional, sin FK)

  codigo TEXT,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  categoria TEXT,
  unidad_medida TEXT DEFAULT 'Unidad',
  precio_compra NUMERIC(12,2) DEFAULT 0,
  precio_venta NUMERIC(12,2) DEFAULT 0,
  stock_minimo INTEGER DEFAULT 0,
  stock_actual INTEGER DEFAULT 0,
  bodega TEXT DEFAULT 'General',
  isv_rate NUMERIC(4,2) DEFAULT 15.00,
  exento BOOLEAN DEFAULT false,
  imagen_url TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE productos ADD COLUMN IF NOT EXISTS empresa_codigo TEXT;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS empresa_id UUID;

CREATE INDEX IF NOT EXISTS idx_productos_empresa_codigo ON productos(empresa_codigo);
CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos(nombre);

DROP TRIGGER IF EXISTS trigger_productos_updated ON productos;
CREATE TRIGGER trigger_productos_updated BEFORE UPDATE ON productos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------------
-- 5. VENTAS (registro de cierres de caja del POS)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo TEXT NOT NULL,              -- tenant (código, sin FK)
  empresa_id UUID,                           -- UUID resuelto (opcional, sin FK)

  correlativo TEXT,
  cliente_nombre TEXT,
  cliente_rtn TEXT,
  condicion_pago TEXT DEFAULT 'Contado',

  items JSONB DEFAULT '[]'::JSONB,
  subtotal NUMERIC(12,2) DEFAULT 0,
  isv_15 NUMERIC(12,2) DEFAULT 0,
  isv_18 NUMERIC(12,2) DEFAULT 0,
  descuento NUMERIC(12,2) DEFAULT 0,
  total NUMERIC(12,2) DEFAULT 0,

  metodo_pago TEXT DEFAULT 'efectivo'
    CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'cheque', 'otro')),
  notas TEXT,
  fecha TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE ventas ADD COLUMN IF NOT EXISTS empresa_codigo TEXT;
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS empresa_id UUID;

CREATE INDEX IF NOT EXISTS idx_ventas_empresa_codigo ON ventas(empresa_codigo);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha);

DROP TRIGGER IF EXISTS trigger_ventas_updated ON ventas;
CREATE TRIGGER trigger_ventas_updated BEFORE UPDATE ON ventas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------------
-- 6. NOTAS_ESTADO (estado completo de notas por asignatura, JSONB)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notas_estado (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo TEXT NOT NULL,              -- tenant (código, sin FK)
  clave TEXT NOT NULL,                       -- periodo|grado|seccion|asignatura
  datos JSONB DEFAULT '{}'::JSONB,           -- { alumnoId: { rubroId: nota } , ... }
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(empresa_codigo, clave)
);

ALTER TABLE notas_estado ADD COLUMN IF NOT EXISTS empresa_codigo TEXT;

CREATE INDEX IF NOT EXISTS idx_notas_estado_empresa ON notas_estado(empresa_codigo);
CREATE INDEX IF NOT EXISTS idx_notas_estado_clave ON notas_estado(clave);

DROP TRIGGER IF EXISTS trigger_notas_estado_updated ON notas_estado;
CREATE TRIGGER trigger_notas_estado_updated BEFORE UPDATE ON notas_estado
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------------
-- RLS: políticas por empresa_codigo (sin referenciar tablas que
-- puedan no existir). Filtran contra el claim 'empresa_codigo'
-- del JWT. Los endpoints serverless usan service role key, que
-- omite RLS, por lo que estas políticas no bloquean la sync.
-- -------------------------------------------------------------
ALTER TABLE facturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE transacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE notas_estado ENABLE ROW LEVEL SECURITY;

-- Helper reutilizable: ¿el claim 'empresa_codigo' del JWT coincide?
CREATE OR REPLACE FUNCTION jwt_empresa_codigo()
RETURNS TEXT AS $$
  SELECT NULLIF(auth.jwt() ->> 'empresa_codigo', '');
$$ LANGUAGE SQL STABLE;

DROP POLICY IF EXISTS "facturas por empresa" ON facturas;
CREATE POLICY "facturas por empresa" ON facturas
  FOR ALL USING (empresa_codigo = jwt_empresa_codigo());

DROP POLICY IF EXISTS "transacciones por empresa" ON transacciones;
CREATE POLICY "transacciones por empresa" ON transacciones
  FOR ALL USING (empresa_codigo = jwt_empresa_codigo());

DROP POLICY IF EXISTS "clientes por empresa" ON clientes;
CREATE POLICY "clientes por empresa" ON clientes
  FOR ALL USING (empresa_codigo = jwt_empresa_codigo());

DROP POLICY IF EXISTS "productos por empresa" ON productos;
CREATE POLICY "productos por empresa" ON productos
  FOR ALL USING (empresa_codigo = jwt_empresa_codigo());

DROP POLICY IF EXISTS "ventas por empresa" ON ventas;
CREATE POLICY "ventas por empresa" ON ventas
  FOR ALL USING (empresa_codigo = jwt_empresa_codigo());

DROP POLICY IF EXISTS "notas_estado por empresa" ON notas_estado;
CREATE POLICY "notas_estado por empresa" ON notas_estado
  FOR ALL USING (empresa_codigo = jwt_empresa_codigo());
