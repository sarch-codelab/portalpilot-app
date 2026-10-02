-- Bodegas por empresa, compartidas y sincronizables desde varios dispositivos.
CREATE TABLE IF NOT EXISTS public.bodegas (
  id TEXT PRIMARY KEY,
  empresa_codigo TEXT NOT NULL,
  empresa_id UUID,
  nombre TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (empresa_codigo, nombre)
);

CREATE INDEX IF NOT EXISTS idx_bodegas_empresa_nombre
  ON public.bodegas (empresa_codigo, nombre);

ALTER TABLE public.bodegas ENABLE ROW LEVEL SECURITY;
