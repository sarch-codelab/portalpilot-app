-- =============================================================
-- Portal Pilot — Agregar columna is_perishable a la tabla PRODUCTOS
-- Copiar y pegar en: Supabase SQL Editor (https://supabase.com/dashboard)
-- Para instalaciones existentes (si ya creaste la tabla productos antes).
-- =============================================================

ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS is_perishable BOOLEAN DEFAULT false;

-- Asegurar el índice compuesto (empresa, codigo) sigue disponible
-- para el upsert del backend (si no existe, se crea).
CREATE INDEX IF NOT EXISTS idx_productos_empresa_codigo
  ON productos(empresa_id, codigo);