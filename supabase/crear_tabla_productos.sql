-- =============================================================
-- Portal Pilot — Tabla PRODUCTOS para Supabase
-- Copiar y pegar en: Supabase SQL Editor (https://supabase.com/dashboard)
-- =============================================================

-- 0. CREAR TABLA USUARIOS (si no existe)
-- =============================================================
-- La política RLS de productos necesita la tabla usuarios para saber
-- a qué empresa pertenece el usuario autenticado.
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  empresa_id UUID,
  nombre TEXT NOT NULL,
  apellido TEXT,
  email TEXT NOT NULL,
  rol_global TEXT DEFAULT 'user' CHECK (rol_global IN ('owner', 'admin', 'user')),
  avatar_url TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1. CREAR TABLA PRODUCTOS
-- =============================================================
CREATE TABLE IF NOT EXISTS productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL,
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

-- 2. ÍNDICES DE BÚSQUEDA
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_productos_empresa ON productos(empresa_id);
CREATE INDEX IF NOT EXISTS idx_productos_empresa_codigo ON productos(empresa_id, codigo);
CREATE INDEX IF NOT EXISTS idx_productos_empresa_nombre ON productos(empresa_id, nombre);
CREATE INDEX IF NOT EXISTS idx_productos_empresa_activo ON productos(empresa_id, activo);
CREATE INDEX IF NOT EXISTS idx_productos_empresa_categoria ON productos(empresa_id, categoria);

-- 3. RLS (Row Level Security) — Multi-tenant
-- =============================================================
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;

-- Cada usuario solo ve los productos de su empresa
DROP POLICY IF EXISTS "productos por empresa" ON productos;
CREATE POLICY "productos por empresa" ON productos
  FOR ALL
  USING (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()))
  WITH CHECK (empresa_id = (SELECT empresa_id FROM usuarios WHERE id = auth.uid()));

-- 4. TRIGGER: auto-update updated_at
-- =============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_productos_updated ON productos;
CREATE TRIGGER trigger_productos_updated
BEFORE UPDATE ON productos
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 5. EJEMPLO DE INSERT (cambiar el UUID de la empresa por uno real)
-- =============================================================
-- INSERT INTO productos (
--   empresa_id, codigo, nombre, descripcion, categoria, unidad_medida,
--   precio_compra, precio_venta, stock_minimo, stock_actual, bodega,
--   isv_rate, exento, activo
-- ) VALUES (
--   'REEMPLAZA-CON-UUID-DE-EMPRESA',  -- ← UUID de la empresa
--   'P001', 'Coca Cola 12oz', 'Bebida carbonatada', 'Bebidas', 'Unidad',
--   8.00, 15.00, 10, 50, 'General',
--   15.00, false, true
-- );

-- Obtener el UUID de tu empresa:
-- SELECT * FROM empresas;