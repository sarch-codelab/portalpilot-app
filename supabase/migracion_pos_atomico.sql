-- Venta POS atómica e idempotente. Aplicar en Supabase SQL Editor antes de
-- desplegar el backend que llama /rpc/pos_registrar_venta.
CREATE TABLE IF NOT EXISTS public.pos_arqueo_caja (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  usuario_id text NOT NULL,
  terminal_id text,
  fecha_apertura timestamptz NOT NULL,
  fecha_cierre timestamptz,
  fondo_inicial numeric(12,2) NOT NULL DEFAULT 0,
  total_ventas_efectivo numeric(12,2) NOT NULL DEFAULT 0,
  total_ventas_tarjeta numeric(12,2) NOT NULL DEFAULT 0,
  total_ventas_transferencia numeric(12,2) NOT NULL DEFAULT 0,
  total_ventas_mixto numeric(12,2) NOT NULL DEFAULT 0,
  total_gastos numeric(12,2) NOT NULL DEFAULT 0,
  total_entradas numeric(12,2) NOT NULL DEFAULT 0,
  total_salidas numeric(12,2) NOT NULL DEFAULT 0,
  sistema_total numeric(12,2) NOT NULL DEFAULT 0,
  conteo_fisico numeric(12,2),
  diferencia numeric(12,2),
  observaciones text,
  estado text NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto','cerrado')),
  detalle_denominaciones jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_arqueo_empresa_fecha
  ON public.pos_arqueo_caja (empresa_codigo, fecha_apertura DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_pos_arqueo_abierto_terminal
  ON public.pos_arqueo_caja (empresa_codigo, terminal_id)
  WHERE estado = 'abierto';

CREATE TABLE IF NOT EXISTS public.pos_cliente_credito (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  cliente_id text NOT NULL,
  cliente_nombre text,
  limite_credito numeric(12,2) NOT NULL DEFAULT 0,
  saldo_actual numeric(12,2) NOT NULL DEFAULT 0,
  dias_vencimiento integer NOT NULL DEFAULT 30,
  estado text NOT NULL DEFAULT 'activo',
  fecha_ultimo_pago timestamptz,
  monto_ultimo_pago numeric(12,2) NOT NULL DEFAULT 0,
  fecha_ultima_venta timestamptz,
  notas text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (empresa_codigo, cliente_id)
);
CREATE INDEX IF NOT EXISTS idx_pos_credito_empresa_saldo
  ON public.pos_cliente_credito (empresa_codigo, saldo_actual DESC);

CREATE TABLE IF NOT EXISTS public.fiado_abonos (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  cliente_id text NOT NULL,
  cliente_nombre text,
  venta_id text,
  factura_id text,
  monto numeric(12,2) NOT NULL CHECK (monto > 0),
  metodo_pago text NOT NULL,
  referencia text,
  notas text,
  usuario_id text,
  fecha timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fiado_abonos_empresa_fecha
  ON public.fiado_abonos (empresa_codigo, fecha DESC);

ALTER TABLE public.productos ADD COLUMN IF NOT EXISTS barcode text;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.productos
    WHERE NULLIF(BTRIM(barcode), '') IS NOT NULL
    GROUP BY empresa_codigo, BTRIM(barcode)
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Hay códigos de barras duplicados en productos. Corrígelos por empresa antes de aplicar esta migración.';
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_productos_empresa_barcode
  ON public.productos (empresa_codigo, BTRIM(barcode))
  WHERE NULLIF(BTRIM(barcode), '') IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.kardex (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  producto_id text NOT NULL,
  tipo_movimiento text NOT NULL CHECK (tipo_movimiento IN ('entrada', 'salida')),
  cantidad integer NOT NULL CHECK (cantidad > 0),
  referencia text,
  notas text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.pos_registrar_venta(
  p_empresa_codigo text,
  p_empresa_id uuid,
  p_venta jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_correlativo text := NULLIF(BTRIM(p_venta->>'correlativo'), '');
  v_item jsonb;
  v_producto productos%ROWTYPE;
  v_cantidad integer;
  v_precio numeric;
  v_descuento_linea numeric;
  v_tasa numeric;
  v_decrementados jsonb := '[]'::jsonb;
  v_existente facturas%ROWTYPE;
  v_credito pos_cliente_credito%ROWTYPE;
  v_subtotal numeric(12,2);
  v_isv15 numeric(12,2);
  v_isv18 numeric(12,2);
  v_descuento numeric(12,2);
  v_total numeric(12,2);
  v_subtotal_calculado numeric := 0;
  v_descuento_items numeric := 0;
  v_isv15_calculado numeric := 0;
  v_isv18_calculado numeric := 0;
BEGIN
  IF COALESCE(BTRIM(p_empresa_codigo), '') = '' THEN
    RAISE EXCEPTION 'empresa_codigo es requerido';
  END IF;
  IF jsonb_typeof(p_venta->'items') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'La venta debe incluir una lista de productos';
  END IF;
  IF jsonb_array_length(p_venta->'items') = 0 THEN
    RAISE EXCEPTION 'La venta debe incluir productos';
  END IF;
  IF v_correlativo IS NULL THEN
    RAISE EXCEPTION 'correlativo es requerido para garantizar idempotencia';
  END IF;

  -- Serializa reintentos simultáneos del mismo ticket sin bloquear otras ventas.
  PERFORM pg_advisory_xact_lock(hashtextextended(UPPER(p_empresa_codigo) || ':' || v_correlativo, 0));
  SELECT * INTO v_existente
    FROM facturas
    WHERE empresa_codigo = p_empresa_codigo AND correlativo = v_correlativo
    LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true, 'correlativo', v_correlativo);
  END IF;

  -- Bloquea cada producto y rebaja stock dentro de la misma transacción que
  -- inserta la factura. Cualquier error revierte ambos lados.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_venta->'items') LOOP
    v_cantidad := (v_item->>'cantidad')::integer;
    IF v_cantidad IS NULL OR v_cantidad <= 0 THEN RAISE EXCEPTION 'Cantidad inválida en %', v_item->>'nombre'; END IF;
    v_precio := COALESCE((v_item->>'precio_unitario')::numeric, (v_item->>'precio')::numeric);
    v_descuento_linea := COALESCE((v_item->>'descuento')::numeric, 0);
    v_tasa := COALESCE((v_item->>'isv_rate')::numeric, 15);
    IF v_precio IS NULL OR v_precio < 0 OR v_descuento_linea < 0 OR
       v_descuento_linea > v_precio * v_cantidad THEN
      RAISE EXCEPTION 'Precio o descuento inválido para %', v_item->>'nombre';
    END IF;
    IF v_tasa NOT IN (0, 15, 18) THEN RAISE EXCEPTION 'Tasa ISV inválida para %', v_item->>'nombre'; END IF;
    v_subtotal_calculado := v_subtotal_calculado + v_precio * v_cantidad;
    v_descuento_items := v_descuento_items + v_descuento_linea;
    IF v_tasa = 15 THEN v_isv15_calculado := v_isv15_calculado + (v_precio * v_cantidad - v_descuento_linea) * 0.15; END IF;
    IF v_tasa = 18 THEN v_isv18_calculado := v_isv18_calculado + (v_precio * v_cantidad - v_descuento_linea) * 0.18; END IF;
    IF COALESCE(BTRIM(v_item->>'codigo'), '') = '' THEN
      RAISE EXCEPTION 'El producto % no tiene código para sincronizar', v_item->>'nombre';
    END IF;

    SELECT * INTO v_producto FROM productos
      WHERE empresa_codigo = p_empresa_codigo
        AND (codigo = v_item->>'codigo' OR barcode = v_item->>'codigo')
      ORDER BY CASE WHEN codigo = v_item->>'codigo' THEN 0 ELSE 1 END
      LIMIT 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto no encontrado: %', v_item->>'codigo'; END IF;
    IF COALESCE(v_producto.stock_actual, 0) < v_cantidad THEN
      RAISE EXCEPTION 'Stock insuficiente para %: disponible %, solicitado %',
        v_producto.nombre, COALESCE(v_producto.stock_actual, 0), v_cantidad;
    END IF;

    UPDATE productos
      SET stock_actual = COALESCE(stock_actual, 0) - v_cantidad,
          updated_at = now()
      WHERE id = v_producto.id;
    INSERT INTO kardex (
      id, empresa_codigo, empresa_id, producto_id, tipo_movimiento,
      cantidad, referencia, notas
    ) VALUES (
      gen_random_uuid(), p_empresa_codigo, p_empresa_id, v_producto.id::text,
      'salida', v_cantidad, v_correlativo, 'Venta POS'
    );
    v_decrementados := v_decrementados || jsonb_build_array(jsonb_build_object(
      'id', v_producto.id, 'codigo', v_producto.codigo,
      'nombre', v_producto.nombre,
      'nuevoStock', COALESCE(v_producto.stock_actual, 0) - v_cantidad
    ));
  END LOOP;

  v_subtotal := COALESCE((p_venta->>'subtotal')::numeric, 0);
  v_isv15 := COALESCE((p_venta->>'isv_15')::numeric, 0);
  v_isv18 := COALESCE((p_venta->>'isv_18')::numeric, 0);
  v_descuento := COALESCE((p_venta->>'descuento')::numeric, 0);
  v_total := COALESCE((p_venta->>'total')::numeric, v_subtotal - v_descuento + v_isv15 + v_isv18);
  IF v_subtotal < 0 OR v_isv15 < 0 OR v_isv18 < 0 OR
     v_descuento < v_descuento_items OR v_descuento > v_subtotal OR v_total < 0 THEN
    RAISE EXCEPTION 'Los importes de la venta no pueden ser negativos';
  END IF;
  IF ABS(v_subtotal - v_subtotal_calculado) > 0.02 OR
     ABS(v_isv15 - v_isv15_calculado) > 0.02 OR
     ABS(v_isv18 - v_isv18_calculado) > 0.02 OR
     ABS(v_total - (v_subtotal - v_descuento + v_isv15 + v_isv18)) > 0.02 THEN
    RAISE EXCEPTION 'Los importes no coinciden con el detalle de productos';
  END IF;

  INSERT INTO facturas (
    empresa_codigo, empresa_id, correlativo, tipo_documento, cai,
    cliente_nombre, cliente_rtn, condicion_pago, tipo_venta, items,
    subtotal, isv_15, isv_18, descuento, total, estado, notas
  ) VALUES (
    p_empresa_codigo, p_empresa_id, v_correlativo, 'Factura', 'POS-DIRECTO',
    COALESCE(NULLIF(p_venta->>'cliente_nombre', ''), 'Consumidor Final'),
    COALESCE(NULLIF(p_venta->>'cliente_rtn', ''), 'CF'),
    CASE WHEN p_venta->>'estado' = 'pendiente_pago' THEN 'Crédito' ELSE 'Contado' END,
    'Gravada', p_venta->'items', v_subtotal, v_isv15, v_isv18, v_descuento,
    v_total,
    CASE WHEN p_venta->>'estado' = 'pendiente_pago' THEN 'pendiente' ELSE 'pagada' END,
    COALESCE(NULLIF(BTRIM(p_venta->>'notas'), ''), 'Pago: ' || COALESCE(p_venta->>'metodo_pago', 'efectivo'))
  );

  IF p_venta->>'estado' = 'pendiente_pago' AND NULLIF(BTRIM(p_venta->>'cliente_id'), '') IS NOT NULL THEN
    SELECT * INTO v_credito FROM pos_cliente_credito
      WHERE empresa_codigo = p_empresa_codigo AND cliente_id = p_venta->>'cliente_id'
      FOR UPDATE;
    IF FOUND AND v_credito.limite_credito > 0 AND v_credito.saldo_actual + v_total > v_credito.limite_credito THEN
      RAISE EXCEPTION 'La venta supera el límite de crédito del cliente';
    END IF;
    INSERT INTO pos_cliente_credito (
      id, empresa_codigo, empresa_id, cliente_id, cliente_nombre,
      saldo_actual, fecha_ultima_venta, estado, created_at, updated_at
    ) VALUES (
      gen_random_uuid()::text, p_empresa_codigo, p_empresa_id,
      p_venta->>'cliente_id', NULLIF(p_venta->>'cliente_nombre', ''),
      v_total, now(), 'activo', now(), now()
    )
    ON CONFLICT (empresa_codigo, cliente_id) DO UPDATE SET
      cliente_nombre = COALESCE(EXCLUDED.cliente_nombre, pos_cliente_credito.cliente_nombre),
      saldo_actual = pos_cliente_credito.saldo_actual + EXCLUDED.saldo_actual,
      fecha_ultima_venta = now(),
      estado = 'activo',
      updated_at = now();
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'duplicate', false, 'correlativo', v_correlativo,
    'decrementados', v_decrementados
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_registrar_venta(text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_registrar_venta(text, uuid, jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.pos_registrar_movimiento_stock(
  p_empresa_codigo text,
  p_empresa_id uuid,
  p_movimiento jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_movimiento_id uuid := (p_movimiento->>'id')::uuid;
  v_cantidad integer := (p_movimiento->>'cantidad')::integer;
  v_tipo text := p_movimiento->>'tipo_movimiento';
  v_codigo text := BTRIM(p_movimiento->>'producto_codigo');
  v_producto productos%ROWTYPE;
  v_nuevo_stock integer;
BEGIN
  IF COALESCE(BTRIM(p_empresa_codigo), '') = '' OR v_movimiento_id IS NULL THEN
    RAISE EXCEPTION 'Empresa e identificador de movimiento son requeridos';
  END IF;
  IF v_tipo IS NULL OR v_tipo NOT IN ('entrada', 'salida') OR
     v_cantidad IS NULL OR v_cantidad <= 0 OR COALESCE(v_codigo, '') = '' THEN
    RAISE EXCEPTION 'Tipo, cantidad o producto inválido';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_empresa_codigo || ':' || v_movimiento_id::text, 0));
  IF EXISTS (SELECT 1 FROM kardex WHERE id = v_movimiento_id) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true);
  END IF;

  SELECT * INTO v_producto FROM productos
    WHERE empresa_codigo = p_empresa_codigo
      AND (codigo = v_codigo OR barcode = v_codigo)
    ORDER BY CASE WHEN codigo = v_codigo THEN 0 ELSE 1 END
    LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Producto no encontrado: %', v_codigo; END IF;

  IF v_tipo = 'salida' AND COALESCE(v_producto.stock_actual, 0) < v_cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente para %: disponible %, solicitado %',
      v_producto.nombre, COALESCE(v_producto.stock_actual, 0), v_cantidad;
  END IF;
  v_nuevo_stock := CASE WHEN v_tipo = 'entrada'
    THEN COALESCE(v_producto.stock_actual, 0) + v_cantidad
    ELSE COALESCE(v_producto.stock_actual, 0) - v_cantidad END;

  UPDATE productos SET stock_actual = v_nuevo_stock, updated_at = now() WHERE id = v_producto.id;
  INSERT INTO kardex (
    id, empresa_codigo, empresa_id, producto_id, tipo_movimiento,
    cantidad, referencia, notas, created_at
  ) VALUES (
    v_movimiento_id, p_empresa_codigo, p_empresa_id, v_producto.id::text,
    v_tipo, v_cantidad, p_movimiento->>'referencia', p_movimiento->>'notas',
    COALESCE((p_movimiento->>'created_at')::timestamptz, now())
  );

  RETURN jsonb_build_object(
    'success', true, 'duplicate', false,
    'producto_id', v_producto.id, 'stock_actual', v_nuevo_stock
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_registrar_movimiento_stock(text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_registrar_movimiento_stock(text, uuid, jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.pos_registrar_abono_fiado(
  p_empresa_codigo text,
  p_empresa_id uuid,
  p_abono jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id text := NULLIF(BTRIM(p_abono->>'id'), '');
  v_cliente text := NULLIF(BTRIM(p_abono->>'cliente_id'), '');
  v_monto numeric := (p_abono->>'monto')::numeric;
  v_credito pos_cliente_credito%ROWTYPE;
  v_aplicado numeric;
  v_fecha timestamptz := COALESCE((p_abono->>'fecha')::timestamptz, now());
BEGIN
  IF COALESCE(BTRIM(p_empresa_codigo), '') = '' OR v_id IS NULL OR v_cliente IS NULL OR v_monto IS NULL OR v_monto <= 0 THEN
    RAISE EXCEPTION 'Empresa, cliente, id y monto válido son requeridos';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(UPPER(p_empresa_codigo) || ':FIADO:' || v_id, 0));
  IF EXISTS (SELECT 1 FROM fiado_abonos WHERE empresa_codigo = p_empresa_codigo AND id = v_id) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true, 'id', v_id);
  END IF;
  SELECT * INTO v_credito FROM pos_cliente_credito
    WHERE empresa_codigo = p_empresa_codigo AND cliente_id = v_cliente FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'El cliente no tiene cuenta por cobrar'; END IF;
  v_aplicado := LEAST(v_monto, GREATEST(v_credito.saldo_actual, 0));
  IF v_aplicado <= 0 THEN RAISE EXCEPTION 'La cuenta no tiene saldo pendiente'; END IF;

  UPDATE pos_cliente_credito SET
    saldo_actual = saldo_actual - v_aplicado,
    fecha_ultimo_pago = v_fecha,
    monto_ultimo_pago = v_aplicado,
    estado = CASE WHEN saldo_actual - v_aplicado <= 0 THEN 'al_dia' ELSE 'activo' END,
    updated_at = now()
    WHERE empresa_codigo = p_empresa_codigo AND cliente_id = v_cliente;

  INSERT INTO fiado_abonos (
    id, empresa_codigo, empresa_id, cliente_id, cliente_nombre,
    venta_id, factura_id, monto, metodo_pago, referencia, notas, usuario_id,
    fecha, created_at
  ) VALUES (
    v_id, p_empresa_codigo, p_empresa_id, v_cliente,
    COALESCE(NULLIF(p_abono->>'cliente_nombre', ''), v_credito.cliente_nombre),
    p_abono->>'venta_id', p_abono->>'factura_id', v_aplicado,
    COALESCE(NULLIF(p_abono->>'metodo_pago', ''), 'efectivo'),
    p_abono->>'referencia', p_abono->>'notas', p_abono->>'usuario_id',
    v_fecha, now()
  );

  INSERT INTO transacciones (
    id, empresa_codigo, empresa_id, usuario_id, tipo, categoria,
    descripcion, monto, metodo_pago, referencia, fecha, created_at, updated_at
  ) VALUES (
    v_id::uuid, p_empresa_codigo, p_empresa_id, p_abono->>'usuario_id',
    'ingreso', 'Abono a cuenta por cobrar',
    'Abono ' || COALESCE(NULLIF(p_abono->>'cliente_nombre', ''), v_cliente) || ' - ' || COALESCE(p_abono->>'metodo_pago', 'efectivo'),
    v_aplicado, COALESCE(NULLIF(p_abono->>'metodo_pago', ''), 'efectivo'),
    p_abono->>'referencia', v_fecha, now(), now()
  ) ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'duplicate', false, 'id', v_id, 'monto_aplicado', v_aplicado);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_registrar_abono_fiado(text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_registrar_abono_fiado(text, uuid, jsonb) TO service_role;
