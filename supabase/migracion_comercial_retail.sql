-- Tablas de compras y proveedores usadas por el flujo offline-first del POS.
-- Aplicar antes de habilitar la sincronización de estos módulos.
-- Orden recomendado: schema.sql, migracion_sync.sql, migracion_pos_atomico.sql,
-- y por último este archivo (que usa productos.barcode y la tabla kardex).
CREATE TABLE IF NOT EXISTS public.proveedores (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  nombre text NOT NULL,
  contacto text,
  telefono text,
  email text,
  direccion text,
  rtn text,
  condiciones_pago integer NOT NULL DEFAULT 30,
  notas text,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cotizaciones (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  correlativo text,
  proveedor_id text NOT NULL,
  proveedor_nombre text NOT NULL,
  fecha timestamptz NOT NULL,
  validez_dias integer NOT NULL DEFAULT 30,
  estado text NOT NULL DEFAULT 'borrador',
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  isv15 numeric(12,2) NOT NULL DEFAULT 0,
  isv18 numeric(12,2) NOT NULL DEFAULT 0,
  descuento numeric(12,2) NOT NULL DEFAULT 0,
  total numeric(12,2) NOT NULL DEFAULT 0,
  notas text,
  usuario_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cotizacion_items (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  cotizacion_id text NOT NULL,
  producto_id text,
  producto_codigo text,
  producto_nombre text NOT NULL,
  descripcion text,
  cantidad integer NOT NULL,
  precio_unitario numeric(12,2) NOT NULL,
  descuento numeric(12,2) NOT NULL DEFAULT 0,
  isv_rate numeric(4,2) NOT NULL DEFAULT 15,
  subtotal numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ordenes_compra (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  correlativo text,
  proveedor_id text NOT NULL,
  proveedor_nombre text NOT NULL,
  cotizacion_id text,
  fecha timestamptz NOT NULL,
  fecha_entrega timestamptz,
  estado text NOT NULL DEFAULT 'borrador',
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  isv15 numeric(12,2) NOT NULL DEFAULT 0,
  isv18 numeric(12,2) NOT NULL DEFAULT 0,
  descuento numeric(12,2) NOT NULL DEFAULT 0,
  total numeric(12,2) NOT NULL DEFAULT 0,
  notas text,
  usuario_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.orden_compra_items (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  orden_compra_id text NOT NULL,
  producto_id text,
  producto_codigo text,
  producto_nombre text NOT NULL,
  descripcion text,
  cantidad integer NOT NULL,
  precio_unitario numeric(12,2) NOT NULL,
  descuento numeric(12,2) NOT NULL DEFAULT 0,
  isv_rate numeric(4,2) NOT NULL DEFAULT 15,
  subtotal numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.compras (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  correlativo text,
  proveedor_id text NOT NULL,
  proveedor_nombre text NOT NULL,
  orden_compra_id text,
  numero_factura text,
  fecha timestamptz NOT NULL,
  fecha_vencimiento timestamptz,
  estado text NOT NULL DEFAULT 'pendiente',
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  isv15 numeric(12,2) NOT NULL DEFAULT 0,
  isv18 numeric(12,2) NOT NULL DEFAULT 0,
  descuento numeric(12,2) NOT NULL DEFAULT 0,
  total numeric(12,2) NOT NULL DEFAULT 0,
  notas text,
  usuario_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.compra_items (
  id text PRIMARY KEY,
  empresa_codigo text NOT NULL,
  empresa_id uuid,
  compra_id text NOT NULL,
  producto_id text,
  producto_codigo text,
  producto_nombre text NOT NULL,
  descripcion text,
  cantidad integer NOT NULL,
  precio_unitario numeric(12,2) NOT NULL,
  descuento numeric(12,2) NOT NULL DEFAULT 0,
  isv_rate numeric(4,2) NOT NULL DEFAULT 15,
  subtotal numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

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

CREATE INDEX IF NOT EXISTS idx_proveedores_empresa ON public.proveedores(empresa_codigo);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_empresa_fecha ON public.cotizaciones(empresa_codigo, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_ordenes_compra_empresa_fecha ON public.ordenes_compra(empresa_codigo, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_compras_empresa_fecha ON public.compras(empresa_codigo, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_cotizacion_items_parent ON public.cotizacion_items(empresa_codigo, cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_orden_compra_items_parent ON public.orden_compra_items(empresa_codigo, orden_compra_id);
CREATE INDEX IF NOT EXISTS idx_compra_items_parent ON public.compra_items(empresa_codigo, compra_id);

CREATE OR REPLACE FUNCTION public.pos_registrar_compra(
  p_empresa_codigo text,
  p_empresa_id uuid,
  p_compra jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id text := NULLIF(BTRIM(p_compra->>'id'), '');
  v_item jsonb;
  v_producto productos%ROWTYPE;
  v_codigo text;
  v_cantidad integer;
  v_costo numeric;
  v_nuevo_stock integer;
BEGIN
  IF COALESCE(BTRIM(p_empresa_codigo), '') = '' OR v_id IS NULL THEN
    RAISE EXCEPTION 'Empresa e identificador de compra son requeridos';
  END IF;
  IF jsonb_typeof(p_compra->'items') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'La recepción debe incluir productos';
  END IF;
  IF jsonb_array_length(p_compra->'items') = 0 THEN
    RAISE EXCEPTION 'La recepción debe incluir productos';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(UPPER(p_empresa_codigo) || ':COMPRA:' || v_id, 0));
  IF EXISTS (SELECT 1 FROM compras WHERE empresa_codigo = p_empresa_codigo AND id = v_id) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true, 'id', v_id);
  END IF;

  INSERT INTO compras (
    id, empresa_codigo, empresa_id, correlativo, proveedor_id, proveedor_nombre,
    orden_compra_id, numero_factura, fecha, fecha_vencimiento, estado,
    subtotal, isv15, isv18, descuento, total, notas, usuario_id, created_at, updated_at
  ) VALUES (
    v_id, p_empresa_codigo, p_empresa_id, p_compra->>'correlativo',
    p_compra->>'proveedor_id', COALESCE(p_compra->>'proveedor_nombre', ''),
    p_compra->>'orden_compra_id', p_compra->>'numero_factura',
    COALESCE((p_compra->>'fecha')::timestamptz, now()),
    (p_compra->>'fecha_vencimiento')::timestamptz,
    COALESCE(p_compra->>'estado', 'pendiente'),
    COALESCE((p_compra->>'subtotal')::numeric, 0),
    COALESCE((p_compra->>'isv15')::numeric, 0),
    COALESCE((p_compra->>'isv18')::numeric, 0),
    COALESCE((p_compra->>'descuento')::numeric, 0),
    COALESCE((p_compra->>'total')::numeric, 0),
    p_compra->>'notas', p_compra->>'usuario_id', now(), now()
  );

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_compra->'items') LOOP
    v_codigo := BTRIM(v_item->>'producto_codigo');
    v_cantidad := (v_item->>'cantidad')::integer;
    v_costo := COALESCE((v_item->>'precio_unitario')::numeric, 0);
    IF COALESCE(v_codigo, '') = '' OR v_cantidad IS NULL OR v_cantidad <= 0 OR v_costo < 0 THEN
      RAISE EXCEPTION 'Producto, cantidad o costo inválido en la recepción';
    END IF;
    SELECT * INTO v_producto FROM productos
      WHERE empresa_codigo = p_empresa_codigo
        AND (codigo = v_codigo OR barcode = v_codigo)
      ORDER BY CASE WHEN codigo = v_codigo THEN 0 ELSE 1 END
      LIMIT 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto no encontrado: %', v_codigo; END IF;

    v_nuevo_stock := COALESCE(v_producto.stock_actual, 0) + v_cantidad;
    UPDATE productos SET
      stock_actual = v_nuevo_stock,
      precio_compra = CASE
        WHEN v_nuevo_stock = 0 THEN v_costo
        ELSE ((COALESCE(v_producto.stock_actual, 0) * COALESCE(v_producto.precio_compra, 0)) + (v_cantidad * v_costo)) / v_nuevo_stock
      END,
      updated_at = now()
      WHERE id = v_producto.id;

    INSERT INTO compra_items (
      id, empresa_codigo, empresa_id, compra_id, producto_id, producto_codigo,
      producto_nombre, descripcion, cantidad, precio_unitario, descuento,
      isv_rate, subtotal, created_at
    ) VALUES (
      COALESCE(NULLIF(v_item->>'id', ''), gen_random_uuid()::text),
      p_empresa_codigo, p_empresa_id, v_id, v_producto.id::text,
      v_producto.codigo, COALESCE(v_item->>'producto_nombre', v_producto.nombre),
      v_item->>'descripcion', v_cantidad, v_costo,
      COALESCE((v_item->>'descuento')::numeric, 0),
      COALESCE((v_item->>'isv_rate')::numeric, 15),
      COALESCE((v_item->>'subtotal')::numeric, v_cantidad * v_costo), now()
    );
    INSERT INTO kardex (
      id, empresa_codigo, empresa_id, producto_id, tipo_movimiento,
      cantidad, referencia, notas
    ) VALUES (
      gen_random_uuid(), p_empresa_codigo, p_empresa_id, v_producto.id::text,
      'entrada', v_cantidad, p_compra->>'correlativo', 'Recepción de compra ' || v_id
    );
  END LOOP;
  RETURN jsonb_build_object('success', true, 'duplicate', false, 'id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_registrar_compra(text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_registrar_compra(text, uuid, jsonb) TO service_role;

-- Anula una recepción y revierte inventario + Kardex atómicamente. No permite
-- dejar el stock negativo ni revertir dos veces una misma compra.
CREATE OR REPLACE FUNCTION public.pos_anular_compra(
  p_empresa_codigo text,
  p_empresa_id uuid,
  p_compra_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_compra compras%ROWTYPE;
  v_item compra_items%ROWTYPE;
  v_producto productos%ROWTYPE;
BEGIN
  IF COALESCE(BTRIM(p_empresa_codigo), '') = '' OR COALESCE(BTRIM(p_compra_id), '') = '' THEN
    RAISE EXCEPTION 'Empresa e identificador de compra son requeridos';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(UPPER(p_empresa_codigo) || ':COMPRA:' || p_compra_id, 0));
  SELECT * INTO v_compra FROM compras
    WHERE empresa_codigo = p_empresa_codigo AND id = p_compra_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Compra no encontrada'; END IF;
  IF v_compra.estado = 'anulada' THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true, 'id', p_compra_id);
  END IF;
  IF v_compra.estado = 'pagada' THEN RAISE EXCEPTION 'Una compra pagada no se puede anular'; END IF;

  FOR v_item IN SELECT * FROM compra_items
    WHERE empresa_codigo = p_empresa_codigo AND compra_id = p_compra_id
    ORDER BY id
  LOOP
    SELECT * INTO v_producto FROM productos
      WHERE empresa_codigo = p_empresa_codigo
        AND (id::text = v_item.producto_id OR codigo = v_item.producto_codigo)
      ORDER BY CASE WHEN id::text = v_item.producto_id THEN 0 ELSE 1 END
      LIMIT 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto no encontrado al revertir: %', v_item.producto_nombre; END IF;
    IF COALESCE(v_producto.stock_actual, 0) < v_item.cantidad THEN
      RAISE EXCEPTION 'No se puede anular: % ya salió del inventario', v_item.producto_nombre;
    END IF;
    UPDATE productos SET stock_actual = COALESCE(stock_actual, 0) - v_item.cantidad, updated_at = now()
      WHERE id = v_producto.id;
    INSERT INTO kardex (
      id, empresa_codigo, empresa_id, producto_id, tipo_movimiento,
      cantidad, referencia, notas
    ) VALUES (
      gen_random_uuid(), p_empresa_codigo, p_empresa_id, v_producto.id::text,
      'salida', v_item.cantidad, v_compra.correlativo,
      'Anulación de compra ' || p_compra_id
    );
  END LOOP;
  UPDATE compras SET estado = 'anulada', updated_at = now()
    WHERE empresa_codigo = p_empresa_codigo AND id = p_compra_id;
  RETURN jsonb_build_object('success', true, 'duplicate', false, 'id', p_compra_id);
END;
$$;

REVOKE ALL ON FUNCTION public.pos_anular_compra(text, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_anular_compra(text, uuid, text) TO service_role;
