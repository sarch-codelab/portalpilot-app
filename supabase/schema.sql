-- =============================================================
-- Portal Pilot — Supabase Multi-Tenant Schema
-- Ejecutar en: Supabase SQL Editor (https://supabase.com/dashboard)
-- =============================================================

-- =============================================================
-- 1. EMPRESAS (tenant principal)
-- =============================================================
CREATE TABLE IF NOT EXISTS empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE,  -- código del tenant en NocoDB (ej: PP-123456)
  nombre TEXT NOT NULL,
  rtn TEXT,
  direccion TEXT,
  telefono TEXT,
  email TEXT,
  logo_url TEXT,
  banner_url TEXT,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'starter', 'business', 'enterprise')),
  modulos_habilitados TEXT[] DEFAULT ARRAY['educacion']::TEXT[],
  config JSONB DEFAULT '{}'::JSONB,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- 2. USUARIOS (extiende auth.users de Supabase)
-- =============================================================
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  empresa_id UUID REFERENCES empresas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  apellido TEXT,
  email TEXT NOT NULL,
  rol_global TEXT DEFAULT 'user' CHECK (rol_global IN ('owner', 'admin', 'user')),
  avatar_url TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- 3. EMPRESA_MÓDULOS (qué módulos tiene habilitados cada empresa)
-- =============================================================
CREATE TABLE IF NOT EXISTS empresa_modulos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  modulo_id TEXT NOT NULL,
  habilitado BOOLEAN DEFAULT true,
  fecha_habilitado TIMESTAMPTZ DEFAULT now(),
  config JSONB DEFAULT '{}'::JSONB,
  UNIQUE(empresa_id, modulo_id)
);

-- =============================================================
-- 4. USUARIO_MÓDULOS (qué módulos tiene asignados cada usuario + rol por módulo)
-- =============================================================
CREATE TABLE IF NOT EXISTS usuario_modulos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  modulo_id TEXT NOT NULL,
  rol TEXT NOT NULL DEFAULT 'user' CHECK (rol IN ('admin', 'user', 'viewer')),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(usuario_id, empresa_id, modulo_id)
);

-- =============================================================
-- 5. FACTURAS (módulo Facturación Electrónica SAR)
-- =============================================================
CREATE TABLE IF NOT EXISTS facturas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,

  correlativo TEXT NOT NULL,
  tipo_documento TEXT NOT NULL DEFAULT 'Factura' CHECK (tipo_documento IN ('Factura', 'Nota Crédito', 'Nota Débito', 'Factura Exportación')),
  
  cai TEXT NOT NULL,
  rango_inicio TEXT,
  rango_fin TEXT,
  fecha_limite_emision DATE,
  
  cliente_nombre TEXT,
  cliente_rtn TEXT,
  cliente_direccion TEXT,
  condicion_pago TEXT DEFAULT 'Contado',
  tipo_venta TEXT DEFAULT 'Gravada' CHECK (tipo_venta IN ('Gravada', 'Exenta', 'Exonerada')),
  
  items JSONB DEFAULT '[]'::JSONB,
  subtotal NUMERIC(12,2) DEFAULT 0,
  isv_15 NUMERIC(12,2) DEFAULT 0,
  isv_18 NUMERIC(12,2) DEFAULT 0,
  descuento NUMERIC(12,2) DEFAULT 0,
  total NUMERIC(12,2) DEFAULT 0,
  
  estado TEXT DEFAULT 'emitida' CHECK (estado IN ('emitida', 'pendiente', 'anulada', 'pagada')),
  fecha_anulacion TIMESTAMPTZ,
  motivo_anulacion TEXT,
  
  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_facturas_empresa ON facturas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_facturas_fecha ON facturas(created_at);
CREATE INDEX IF NOT EXISTS idx_facturas_estado ON facturas(estado);

-- =============================================================
-- 6. CLIENTES
-- =============================================================
CREATE TABLE IF NOT EXISTS clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_clientes_empresa ON clientes(empresa_id);

-- =============================================================
-- 7. PRODUCTOS (para Inventario y Facturación)
-- =============================================================
CREATE TABLE IF NOT EXISTS productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_productos_empresa ON productos(empresa_id);

-- =============================================================
-- 8. TRANSACCIONES CONTABLES (módulo Contabilidad)
-- =============================================================
CREATE TABLE IF NOT EXISTS transacciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
  
  tipo TEXT NOT NULL CHECK (tipo IN ('ingreso', 'gasto', 'transferencia', 'ajuste')),
  categoria TEXT,
  descripcion TEXT,
  monto NUMERIC(12,2) NOT NULL,
  
  metodo_pago TEXT CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'cheque', 'otro')),
  referencia TEXT,
  
  fecha TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transacciones_empresa ON transacciones(empresa_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones(fecha);

-- =============================================================
-- 9. MATRÍCULA ESTUDIANTIL (módulo Educación)
-- =============================================================
CREATE TABLE IF NOT EXISTS matriculas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  estudiante_nombre TEXT NOT NULL,
  estudiante_id TEXT,
  grado TEXT,
  seccion TEXT,
  turno TEXT,
  estado TEXT DEFAULT 'activa' CHECK (estado IN ('activa', 'inactiva', 'retirada', 'graduada')),
  fecha_matricula DATE DEFAULT CURRENT_DATE,
  observaciones TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- 10. NOTAS (módulo Educación)
-- =============================================================
CREATE TABLE IF NOT EXISTS notas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  matricula_id UUID REFERENCES matriculas(id) ON DELETE CASCADE,
  materia TEXT NOT NULL,
  trimestre INTEGER CHECK (trimestre IN (1, 2, 3)),
  nota NUMERIC(4,2),
  observaciones TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- 11. EMPLEADOS (módulo RRHH)
-- =============================================================
CREATE TABLE IF NOT EXISTS empleados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  identidad TEXT,
  rtn TEXT,
  puesto TEXT,
  departamento TEXT,
  salario_base NUMERIC(12,2) DEFAULT 0,
  fecha_ingreso DATE,
  estado TEXT DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo', 'vacaciones', 'licencia')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- 12. NÓMINA (módulo RRHH)
-- =============================================================
CREATE TABLE IF NOT EXISTS nomina (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  mes INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
  anio INTEGER NOT NULL,
  salario_base NUMERIC(12,2) DEFAULT 0,
  bonificaciones NUMERIC(12,2) DEFAULT 0,
  deducciones NUMERIC(12,2) DEFAULT 0,
  isss NUMERIC(12,2) DEFAULT 0,
  rtn NUMERIC(12,2) DEFAULT 0,
  ihss NUMERIC(12,2) DEFAULT 0,
  neta NUMERIC(12,2) DEFAULT 0,
  pagado BOOLEAN DEFAULT false,
  fecha_pago DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================
-- RLS (Row Level Security) — Multi-tenant
-- =============================================================

ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE empresa_modulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario_modulos ENABLE ROW LEVEL SECURITY;
ALTER TABLE facturas ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE transacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE matriculas ENABLE ROW LEVEL SECURITY;
ALTER TABLE notas ENABLE ROW LEVEL SECURITY;
ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE nomina ENABLE ROW LEVEL SECURITY;

-- Policies: cada usuario solo ve datos de su empresa
CREATE POLICY "usuarios ven su empresa" ON empresas
  FOR ALL USING (id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "usuarios ven sus datos" ON usuarios
  FOR ALL USING (id = auth.uid());

CREATE POLICY "empresa_modulos por empresa" ON empresa_modulos
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "usuario_modulos por empresa" ON usuario_modulos
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "facturas por empresa" ON facturas
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "clientes por empresa" ON clientes
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "productos por empresa" ON productos
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "transacciones por empresa" ON transacciones
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "matriculas por empresa" ON matriculas
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "notas por empresa" ON notas
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "empleados por empresa" ON empleados
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "nomina por empresa" ON nomina
  FOR ALL USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

-- =============================================================
-- TRIGGER: auto-update updated_at
-- =============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_empresas_updated BEFORE UPDATE ON empresas FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_usuarios_updated BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_facturas_updated BEFORE UPDATE ON facturas FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_clientes_updated BEFORE UPDATE ON clientes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_productos_updated BEFORE UPDATE ON productos FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_transacciones_updated BEFORE UPDATE ON transacciones FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_matriculas_updated BEFORE UPDATE ON matriculas FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_notas_updated BEFORE UPDATE ON notas FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trigger_empleados_updated BEFORE UPDATE ON empleados FOR EACH ROW EXECUTE FUNCTION update_updated_at();
