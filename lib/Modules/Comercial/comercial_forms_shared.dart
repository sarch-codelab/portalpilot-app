// Widgets compartidos del módulo Comercial.
// Los usan cotizaciones, órdenes de compra y compras para que "Nuevo"
// funcione de verdad: proveedor real + líneas de productos con cantidad,
// precio y descuento (antes se creaban documentos sin items y el servicio
// rechazaba la operación).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

String monedaL(double v) => 'L ${v.toStringAsFixed(2)}';

Color colorEstadoDocumento(String estado) {
  switch (estado) {
    case 'aceptada':
    case 'recibida':
    case 'pagada':
      return const Color(0xFF10B981);
    case 'enviada':
    case 'parcial':
      return const Color(0xFF3B82F6);
    case 'rechazada':
    case 'cancelada':
    case 'anulada':
      return const Color(0xFFEF4444);
    case 'vencida':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFFA3A3A3);
  }
}

Widget chipEstadoDocumento({required String estado, required String etiqueta}) {
  final color = colorEstadoDocumento(estado);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      etiqueta,
      style: GoogleFonts.dmSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

/// Línea de producto de un documento comercial.
class LineaProductoDoc {
  final Producto producto;
  final int cantidad;
  final double precio;
  final double descuento; // porcentaje

  const LineaProductoDoc({
    required this.producto,
    required this.cantidad,
    required this.precio,
    this.descuento = 0,
  });

  double get subtotal => precio * cantidad * (1 - descuento / 100);

  LineaProductoDoc copyWith({int? cantidad, double? precio, double? descuento}) =>
      LineaProductoDoc(
        producto: producto,
        cantidad: cantidad ?? this.cantidad,
        precio: precio ?? this.precio,
        descuento: descuento ?? this.descuento,
      );
}

/// Estado vacío consistente para las listas de Comercial.
class ComercialVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final VoidCallback? onNuevo;
  final String etiquetaBoton;

  const ComercialVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.onNuevo,
    this.etiquetaBoton = 'Crear el primero',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: appPalette.textMuted),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: appPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted),
          ),
          if (onNuevo != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNuevo,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(etiquetaBoton),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selector de producto + alta de líneas (cantidad / precio / descuento %).
class SelectorLineasProducto extends StatefulWidget {
  final ValueChanged<List<LineaProductoDoc>> onChanged;

  const SelectorLineasProducto({super.key, required this.onChanged});

  @override
  State<SelectorLineasProducto> createState() => _SelectorLineasProductoState();
}

class _SelectorLineasProductoState extends State<SelectorLineasProducto> {
  List<Producto> _productos = [];
  bool _cargando = true;
  Producto? _seleccionado;
  final _cantidadCtrl = TextEditingController(text: '1');
  final _precioCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController(text: '0');
  final List<LineaProductoDoc> _lineas = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await LocalDatabaseService.instance
          .getProductos(AuthController.instance.empresaCodigo);
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _notificar() => widget.onChanged(List<LineaProductoDoc>.from(_lineas));

  void _agregarLinea() {
    final p = _seleccionado;
    if (p == null) return;
    final cant = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    if (cant <= 0) return;
    final precio = double.tryParse(_precioCtrl.text.trim().replaceAll(',', '')) ??
        p.precioVenta;
    final dcto =
        (double.tryParse(_descuentoCtrl.text.trim()) ?? 0).clamp(0, 100).toDouble();
    final existente = _lineas.indexWhere((l) => l.producto.id == p.id);
    setState(() {
      if (existente >= 0) {
        _lineas[existente] = _lineas[existente].copyWith(
          cantidad: _lineas[existente].cantidad + cant,
          precio: precio,
          descuento: dcto,
        );
      } else {
        _lineas.add(LineaProductoDoc(
          producto: p,
          cantidad: cant,
          precio: precio,
          descuento: dcto,
        ));
      }
      _seleccionado = null;
      _cantidadCtrl.text = '1';
      _precioCtrl.clear();
      _descuentoCtrl.text = '0';
    });
    _notificar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_productos.isEmpty) {
      return Text(
        'No hay productos en Inventario para agregar líneas. Crea productos primero.',
        style: GoogleFonts.dmSans(fontSize: 12.5, color: appPalette.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Producto>(
          key: ValueKey('linea-${_seleccionado?.id ?? ''}'),
          initialValue: _seleccionado,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Producto',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          items: [
            for (final p in _productos)
              DropdownMenuItem(
                value: p,
                child: Text(
                  '${p.nombre}  ·  ${monedaL(p.precioVenta)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (p) {
            setState(() {
              _seleccionado = p;
              if (p != null && _precioCtrl.text.trim().isEmpty) {
                _precioCtrl.text = p.precioVenta.toStringAsFixed(2);
              }
            });
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cantidadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cant.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio L',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _descuentoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Dcto %',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _seleccionado == null ? null : _agregarLinea,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Agregar línea',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_lineas.isEmpty)
          Text(
            'Sin líneas todavía: elige un producto y presiona +.',
            style: GoogleFonts.dmSans(fontSize: 12, color: appPalette.textMuted),
          )
        else
          ..._lineas.asMap().entries.map((e) {
            final i = e.key;
            final l = e.value;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${l.cantidad} × ${l.producto.nombre}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${monedaL(l.precio)} c/u${l.descuento > 0 ? ' · -${l.descuento.toStringAsFixed(0)}%' : ''}',
                style: GoogleFonts.dmSans(fontSize: 11.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monedaL(l.subtotal),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() => _lineas.removeAt(i));
                      _notificar();
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }
}
