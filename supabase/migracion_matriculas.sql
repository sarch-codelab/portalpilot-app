-- =============================================================
-- MIGRACIÓN: Ampliar tabla matriculas para el formulario completo
-- de registro de la App (29 campos) y permitir estado 'pendiente'.
-- Ejecutar en: Supabase SQL Editor (una sola vez).
-- =============================================================

-- 1) Extender tabla matriculas con los campos del formulario de la app
ALTER TABLE matriculas
  ADD COLUMN IF NOT EXISTS folio_matricula TEXT,
  ADD COLUMN IF NOT EXISTS empresa_codigo TEXT,
  ADD COLUMN IF NOT EXISTS ciclo_escolar TEXT,
  ADD COLUMN IF NOT EXISTS nivel_educativo TEXT,
  ADD COLUMN IF NOT EXISTS tipo_ingreso TEXT,
  ADD COLUMN IF NOT EXISTS alumno_nombre TEXT,
  ADD COLUMN IF NOT EXISTS alumno_apellido TEXT,
  ADD COLUMN IF NOT EXISTS alumno_dni TEXT,
  ADD COLUMN IF NOT EXISTS alumno_fecha_nacimiento DATE,
  ADD COLUMN IF NOT EXISTS alumno_lugar_nacimiento TEXT,
  ADD COLUMN IF NOT EXISTS alumno_nacionalidad TEXT,
  ADD COLUMN IF NOT EXISTS observaciones_salud TEXT,
  ADD COLUMN IF NOT EXISTS tutor_parentesco TEXT,
  ADD COLUMN IF NOT EXISTS tutor_nombre TEXT,
  ADD COLUMN IF NOT EXISTS tutor_telefono TEXT,
  ADD COLUMN IF NOT EXISTS tutor_email TEXT,
  ADD COLUMN IF NOT EXISTS direccion_calle TEXT,
  ADD COLUMN IF NOT EXISTS direccion_municipio TEXT,
  ADD COLUMN IF NOT EXISTS direccion_departamento TEXT,
  ADD COLUMN IF NOT EXISTS direccion_referencia TEXT,
  ADD COLUMN IF NOT EXISTS direccion_cp TEXT,
  ADD COLUMN IF NOT EXISTS pago_inscripcion_realizado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS metodo_pago TEXT,
  ADD COLUMN IF NOT EXISTS plan_pagos TEXT;

-- 2) Ampliar el CHECK de estado para aceptar 'pendiente'
ALTER TABLE matriculas DROP CONSTRAINT IF EXISTS matriculas_estado_check;
ALTER TABLE matriculas ADD CONSTRAINT matriculas_estado_check
  CHECK (estado IN ('pendiente', 'activa', 'inactiva', 'retirada', 'graduada'));

-- 3) Índice para búsquedas por empresa
CREATE INDEX IF NOT EXISTS idx_matriculas_empresa_codigo ON matriculas(empresa_codigo);
