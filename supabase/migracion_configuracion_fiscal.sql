-- Configuración fiscal compartida entre los dispositivos de una empresa.
-- La app mantiene además una copia local para poder facturar sin conexión.
CREATE TABLE IF NOT EXISTS public.configuracion_fiscal (
  id TEXT PRIMARY KEY,
  empresa_codigo TEXT NOT NULL UNIQUE,
  empresa_id UUID,
  configuracion JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.configuracion_fiscal ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.configuracion_fiscal_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS configuracion_fiscal_touch ON public.configuracion_fiscal;
CREATE TRIGGER configuracion_fiscal_touch
BEFORE UPDATE ON public.configuracion_fiscal
FOR EACH ROW EXECUTE FUNCTION public.configuracion_fiscal_touch_updated_at();
