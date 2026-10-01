import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/comercial_forms_shared.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class OrdenCompraList extends StatefulWidget {
  const OrdenCompraList({super.key});

  @override
  State<OrdenCompraList> createState() => _OrdenCompraListState();
}

class _OrdenCompraListState extends State<OrdenCompraList> {
  final _service = ComercialService.instance;
  List<OrdenesCompraData> _list = [];
  bool _loading = true;
  bool _errorRed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final descargadas = await _service.descargarOrdenesCompraDesdeApi();
    final items = await _service.getOrdenesCompra();
    if (!mounted) return;
    setState(() {
      _list = items;
      _errorRed = descargadas < 0;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdenCompraForm()));
    await _load();
  }

  Future<void> _verDetalle(OrdenesCompraData o) async {
    final detalle = await _service.getOrdenCompra(o.id);
    if (!mounted || detalle == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detalle.orden.correlativo ?? 'Orden de compra',
                    style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                chipEstadoDocumento(
                  estado: detalle.orden.estado,
                  etiqueta: EstadoOrdenCompra.etiqueta(detalle.orden.estado),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detalle.orden.proveedorNombre,
              style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted),
            ),
            const SizedBox(height: 12),
            if (detalle.items.isEmpty)
              Text(
                'Sin líneas registradas.',
                style: GoogleFonts.dmSans(fontSize: 12.5, color: appPalette.textMuted),
              )
            else
              ...detalle.items.map(
                (i) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${i.cantidad} × ${i.productoNombre}',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${monedaL(i.precioUnitario)} c/u',
                    style: GoogleFonts.dmSans(fontSize: 11.5),
                  ),
                  trailing: Text(
                    monedaL(i.subtotal),
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            const Divider(height: 24),
            _filaTotales('Subtotal', detalle.orden.subtotal),
            _filaTotales('Total', detalle.orden.total, destacado: true),
            const SizedBox(height: 16),
            if (detalle.orden.estado == EstadoOrdenCompra.borrador)
              FilledButton.icon(
                onPressed: () async {
                  await _service.enviarOrdenCompra(o.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar al proveedor'),
              ),
            if (detalle.orden.estado == EstadoOrdenCompra.borrador ||
                detalle.orden.estado == EstadoOrdenCompra.enviada)
              const SizedBox(height: 8),
            if (detalle.orden.estado == EstadoOrdenCompra.borrador ||
                detalle.orden.estado == EstadoOrdenCompra.enviada)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                onPressed: () async {
                  await _service.cancelarOrdenCompra(o.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                },
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar orden'),
              ),
            if (detalle.orden.estado == EstadoOrdenCompra.enviada)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Registra la recepción en Compras para aumentar el stock.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: appPalette.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
    await _load();
  }

  Widget _filaTotales(String label, double valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: destacado ? 14 : 12.5,
                fontWeight: destacado ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            monedaL(valor),
            style: GoogleFonts.dmSans(
              fontSize: destacado ? 15 : 13,
              fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Órdenes de compra'),
        actions: [
          if (_errorRed)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.cloud_off_rounded, size: 18),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _openCreate, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _list.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
                        ComercialVacio(
                          icono: Icons.assignment_outlined,
                          titulo: 'Sin órdenes de compra',
                          mensaje:
                              'Crea la primera orden para pedir mercancía a un proveedor. Puedes enviarla y cancelarla desde aquí.',
                          onNuevo: _openCreate,
                          etiquetaBoton: 'Nueva orden',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final o = _list[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: appPalette.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appPalette.borderLight),
                          ),
                          child: ListTile(
                            onTap: () => _verDetalle(o),
                            title: Text(
                              o.correlativo ?? 'Orden',
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${o.proveedorNombre} · ${monedaL(o.total)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 11.5),
                            ),
                            trailing: chipEstadoDocumento(
                              estado: o.estado,
                              etiqueta: EstadoOrdenCompra.etiqueta(o.estado),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class OrdenCompraForm extends StatefulWidget {
  const OrdenCompraForm({super.key});

  @override
  State<OrdenCompraForm> createState() => _OrdenCompraFormState();
}

class _OrdenCompraFormState extends State<OrdenCompraForm> {
  final _service = ComercialService.instance;
  final _notasCtrl = TextEditingController();
  List<Proveedore> _proveedores = [];
  Proveedore? _proveedor;
  List<LineaProductoDoc> _lineas = const [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  Future<void> _cargarProveedores() async {
    await _service.descargarProveedoresDesdeApi();
    final provs = await _service.getProveedores();
    if (!mounted) return;
    setState(() {
      _proveedores = provs;
      _cargando = false;
    });
  }

  double get _totalLineas => _lineas.fold(0, (s, l) => s + l.subtotal);

  Future<void> _guardar() async {
    if (_proveedor == null) {
      _aviso('Elige un proveedor');
      return;
    }
    if (_lineas.isEmpty) {
      _aviso('Agrega al menos un producto');
      return;
    }
    setState(() => _guardando = true);
    try {
      final orden = await _service.crearOrdenCompra(
        proveedorId: _proveedor!.id,
        items: _lineas.map((l) => (l.producto, l.cantidad, l.precio, l.descuento)).toList(),
        notas: _notasCtrl.text,
      );
      Logger().audit(
        'crear',
        'orden_compra',
        orden.id,
        userId: AuthController.instance.email,
        module: 'comercial',
        changes: {'proveedor': _proveedor!.nombre, 'items': _lineas.length},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo crear la orden: $e', error: true);
    }
  }

  void _aviso(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.dmSans()),
        backgroundColor: error ? const Color(0xFFEF4444) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Orden de Compra')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_proveedores.isEmpty)
                  Text(
                    'No hay proveedores. Crea uno en Comercial → Proveedores antes de ordenar.',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: appPalette.textMuted),
                  )
                else
                  DropdownButtonFormField<Proveedore>(
                    key: ValueKey('ocprov-${_proveedor?.id ?? ''}'),
                    initialValue: _proveedor,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: [
                      for (final p in _proveedores)
                        DropdownMenuItem(
                          value: p,
                          child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (p) => setState(() => _proveedor = p),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Líneas de productos',
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SelectorLineasProducto(
                  onChanged: (lineas) => setState(() => _lineas = lineas),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${monedaL(_totalLineas)}',
                        style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear orden'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }
}
