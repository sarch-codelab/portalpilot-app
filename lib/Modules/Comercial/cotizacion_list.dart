import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/comercial_forms_shared.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class CotizacionList extends StatefulWidget {
  const CotizacionList({super.key});

  @override
  State<CotizacionList> createState() => _CotizacionListState();
}

class _CotizacionListState extends State<CotizacionList> {
  final _service = ComercialService.instance;
  List<Cotizacione> _list = [];
  bool _loading = true;
  bool _errorRed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final descargadas = await _service.descargarCotizacionesDesdeApi();
    final items = await _service.getCotizaciones();
    if (!mounted) return;
    setState(() {
      _list = items;
      _errorRed = descargadas < 0;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CotizacionForm()));
    await _load();
  }

  Future<void> _verDetalle(Cotizacione c) async {
    final detalle = await _service.getCotizacion(c.id);
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
                    detalle.cotizacion.correlativo ?? 'Cotización',
                    style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                chipEstadoDocumento(
                  estado: detalle.cotizacion.estado,
                  etiqueta: EstadoCotizacion.etiqueta(detalle.cotizacion.estado),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detalle.cotizacion.proveedorNombre,
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
                    '${monedaL(i.precioUnitario)} c/u · ISV ${i.isvRate.toStringAsFixed(0)}%',
                    style: GoogleFonts.dmSans(fontSize: 11.5),
                  ),
                  trailing: Text(
                    monedaL(i.subtotal),
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            const Divider(height: 24),
            _filaTotales('Subtotal', detalle.cotizacion.subtotal),
            _filaTotales('ISV 15%', detalle.cotizacion.isv15),
            _filaTotales('ISV 18%', detalle.cotizacion.isv18),
            if (detalle.cotizacion.descuento > 0)
              _filaTotales('Descuento', -detalle.cotizacion.descuento),
            _filaTotales('Total', detalle.cotizacion.total, destacado: true),
            const SizedBox(height: 16),
            if (detalle.cotizacion.estado == EstadoCotizacion.borrador)
              FilledButton.icon(
                onPressed: () async {
                  await _service.enviarCotizacion(c.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Marcar como enviada'),
              ),
            if (detalle.cotizacion.estado == EstadoCotizacion.enviada)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      onPressed: () async {
                        await _service.aceptarCotizacion(c.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Aceptar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                      onPressed: () async {
                        await _service.rechazarCotizacion(c.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Rechazar'),
                    ),
                  ),
                ],
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
        title: const Text('Cotizaciones'),
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
                          icono: Icons.request_quote_outlined,
                          titulo: 'Sin cotizaciones',
                          mensaje:
                              'Crea la primera cotización con proveedor y líneas de productos. Se sincroniza sola con la nube.',
                          onNuevo: _openCreate,
                          etiquetaBoton: 'Nueva cotización',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _list[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: appPalette.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appPalette.borderLight),
                          ),
                          child: ListTile(
                            onTap: () => _verDetalle(c),
                            title: Text(
                              c.correlativo ?? 'Borrador',
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${c.proveedorNombre} · ${monedaL(c.total)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 11.5),
                            ),
                            trailing: chipEstadoDocumento(
                              estado: c.estado,
                              etiqueta: EstadoCotizacion.etiqueta(c.estado),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class CotizacionForm extends StatefulWidget {
  const CotizacionForm({super.key});

  @override
  State<CotizacionForm> createState() => _CotizacionFormState();
}

class _CotizacionFormState extends State<CotizacionForm> {
  final _service = ComercialService.instance;
  final _notasCtrl = TextEditingController();
  int _validezDias = 30;
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
      final cot = await _service.crearCotizacion(
        proveedorId: _proveedor!.id,
        items: _lineas.map((l) => (l.producto, l.cantidad, l.precio, l.descuento)).toList(),
        validezDias: _validezDias,
        notas: _notasCtrl.text,
      );
      Logger().audit(
        'crear',
        'cotizacion',
        cot.id,
        userId: AuthController.instance.email,
        module: 'comercial',
        changes: {'proveedor': _proveedor!.nombre, 'items': _lineas.length},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo crear la cotización: $e', error: true);
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
      appBar: AppBar(title: const Text('Nueva Cotización')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_proveedores.isEmpty)
                  Text(
                    'No hay proveedores. Crea uno en Comercial → Proveedores antes de cotizar.',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: appPalette.textMuted),
                  )
                else
                  DropdownButtonFormField<Proveedore>(
                    key: ValueKey('cotprov-${_proveedor?.id ?? ''}'),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _validezDias,
                  decoration: const InputDecoration(
                    labelText: 'Validez (días)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 días')),
                    DropdownMenuItem(value: 30, child: Text('30 días')),
                    DropdownMenuItem(value: 45, child: Text('45 días')),
                    DropdownMenuItem(value: 60, child: Text('60 días')),
                  ],
                  onChanged: (v) => setState(() => _validezDias = v ?? 30),
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
                          : const Text('Crear cotización'),
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
