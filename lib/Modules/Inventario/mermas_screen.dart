// lib/Modules/Inventario/mermas_screen.dart
// Mermas e inventario fisico (FASE 5).
//
// Esta pantalla NO calcula nada: el costo unitario, el descuento de stock, el
// movimiento de kardex y el ISV los aplica el backend al registrar. Aqui se
// capturan los datos que el usuario conoce y se muestran los resultados que el
// servidor devuelve, incluidos los rechazos (stock insuficiente, motivo vacio).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:portal_pilot_app/Shared/services/operaciones_service.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_empty_state.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';

/// Tipos que acepta el backend. La lista NO es negociable: si el servidor
/// agrega un tipo nuevo, esta pantalla lo dira al recargar y no al inventar.
const List<String> tiposMerma = [
  'merma',
  'desperdicio',
  'vencimiento',
  'robo',
  'dano',
  'devolucion',
  'ajuste',
];

class MermasScreen extends StatefulWidget {
  const MermasScreen({super.key});

  @override
  State<MermasScreen> createState() => _MermasScreenState();
}

class _MermasScreenState extends State<MermasScreen> {
  final _servicio = OperacionesService.instance;

  List<Map<String, dynamic>> _mermas = [];
  List<ProductoOperativo> _productos = [];
  Map<String, dynamic>? _resumen;
  bool _cargando = true;
  String? _error;
  bool _sinPermiso = false;

  // Filtros. El rango de fechas lo resuelve el servidor con desde/hasta.
  String _busqueda = '';
  String _tipoFiltro = '';
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _fechaIso(DateTime? d) => d == null ? '' : d.toIso8601String().substring(0, 10);

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultados = await Future.wait([
      _servicio.mermas(desde: _fechaIso(_desde), hasta: _fechaIso(_hasta)),
      _servicio.resumenMermas(desde: _fechaIso(_desde), hasta: _fechaIso(_hasta)),
      _servicio.productos(),
    ]);

    final lista = resultados[0] as ListaOperativa<Map<String, dynamic>>;
    final resumen = resultados[1] as ListaOperativa<Map<String, dynamic>>;
    final productos = resultados[2] as ListaOperativa<ProductoOperativo>;

    if (!mounted) return;
    setState(() {
      _mermas = lista.items;
      _resumen = resumen.items.isEmpty ? null : resumen.items.first;
      _productos = productos.items;
      _cargando = false;
      if (lista.hayError) {
        _error = lista.error;
        _sinPermiso = lista.sinPermiso;
      } else {
        _sinPermiso = false;
      }
    });
  }

  /// El buscador y el filtro por tipo se aplican sobre lo que ya trajo el
  /// servidor; el rango de fechas si va al backend.
  List<Map<String, dynamic>> get _visibles {
    final q = _busqueda.trim().toLowerCase();
    return _mermas.where((m) {
      if (_tipoFiltro.isNotEmpty && (m['tipo'] ?? '') != _tipoFiltro) return false;
      if (q.isEmpty) return true;
      final texto = [
        m['producto_nombre'],
        m['motivo'],
        m['usuario_nombre'],
        m['tipo'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return texto.contains(q);
    }).toList();
  }

  String _etiquetaTipo(String t) {
    if (t.isEmpty) return 'Merma';
    return t[0].toUpperCase() + t.substring(1);
  }

  Color _colorTipo(String t) {
    switch (t) {
      case 'robo':
        return const Color(0xFFD32F2F);
      case 'vencimiento':
        return const Color(0xFFF57C00);
      case 'ajuste':
        return const Color(0xFF7B1FA2);
      case 'devolucion':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PPModuleScaffold(
      moduleId: 'inventario',
      screenTitle: 'Mermas',
      moduleIcon: Icons.report_gmailerrorred_rounded,
      moduleColor: const Color(0xFFD32F2F),
      loading: _cargando,
      onRefresh: _cargar,
      onNew: _sinPermiso || _error != null ? null : () => _abrirFormulario(),
      child: Column(
        children: [
          _barraResumen(),
          _barraFiltros(),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _barraResumen() {
    if (_resumen == null) return const SizedBox.shrink();
    final d = _resumen!;
    final costo = (double.tryParse(d['costo_total']?.toString() ?? '0') ?? 0);
    final unidades = (double.tryParse(d['unidades_perdidas']?.toString() ?? '0') ?? 0);
    final eventos = d['total_eventos'];

    Widget tarjeta(String etiqueta, String valor, Color color) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(etiqueta, style: TextStyle(fontSize: 11, color: color)),
              const SizedBox(height: 2),
              Text(
                valor,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          tarjeta('Eventos', '${eventos ?? 0}', const Color(0xFF1565C0)),
          tarjeta('Unidades perdidas', _fmt(unidades, decimales: 2),
              const Color(0xFFEF6C00)),
          tarjeta('Costo perdido', 'L ${_fmt(costo, decimales: 2)}',
              const Color(0xFFC62828)),
        ],
      ),
    );
  }

  Widget _barraFiltros() {
    final compacto = MediaQuery.sizeOf(context).width < 700;
    final campo = TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        hintText: 'Buscar producto, motivo o usuario',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    final tipo = DropdownButtonFormField<String>(
      initialValue: _tipoFiltro,
      isDense: true,
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos los tipos')),
        ...tiposMerma.map((t) => DropdownMenuItem(value: t, child: Text(_etiquetaTipo(t)))),
      ],
      onChanged: (v) => setState(() => _tipoFiltro = v ?? ''),
    );
    final fechas = OutlinedButton.icon(
      icon: const Icon(Icons.date_range_rounded, size: 18),
      label: Text(_desde == null && _hasta == null
          ? 'Fechas'
          : '${_desde == null ? '…' : _fechaCorta(_desde!)} - ${_hasta == null ? '…' : _fechaCorta(_hasta!)}'),
      onPressed: _elegirRango,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: compacto
          ? Column(children: [
              campo,
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: tipo),
                const SizedBox(width: 8),
                fechas,
              ]),
            ])
          : Row(children: [
              Expanded(flex: 3, child: campo),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: tipo),
              const SizedBox(width: 8),
              fechas,
            ]),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return Center(
        child: PPEmptyState(
          icon: _sinPermiso ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: _sinPermiso ? 'No disponible en tu plan' : 'No se pudieron cargar las mermas',
          message: _error!,
          action: FilledButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ),
      );
    }

    final filas = _visibles;
    if (filas.isEmpty) {
      return Center(
        child: PPEmptyState(
          icon: Icons.inventory_2_outlined,
          title: _mermas.isEmpty ? 'Sin mermas registradas' : 'Sin resultados',
          message: _mermas.isEmpty
              ? 'Registra la primera merma para empezar a controlar las perdidas.'
              : 'Ninguna merma coincide con los filtros aplicados.',
          action: _mermas.isEmpty
              ? FilledButton.icon(
                  onPressed: _abrirFormulario,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar merma'),
                )
              : null,
        ),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      itemCount: filas.length,
      itemBuilder: (context, i) => _tarjeta(filas[i], ancho),
    );
  }

  Widget _tarjeta(Map<String, dynamic> m, double ancho) {
    final tipo = (m['tipo'] ?? '').toString();
    final color = _colorTipo(tipo);
    final cantidad = double.tryParse(m['cantidad']?.toString() ?? '0') ?? 0;
    final costo = double.tryParse(m['costo_total']?.toString() ?? '0') ?? 0;
    final fecha = m['fecha'] ?? m['created_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(Icons.remove_circle_outline_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (m['producto_nombre'] ?? 'Producto eliminado').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_etiquetaTipo(tipo),
                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmt(cantidad, decimales: 2)} unidad(es)  ·  L ${_fmt(costo, decimales: 2)}',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (m['motivo'] ?? 'Sin motivo').toString(),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (fecha != null) _fechaHora(fecha.toString()),
                      if ((m['usuario_nombre'] ?? '').toString().isNotEmpty)
                        (m['usuario_nombre']).toString(),
                      if (m['stock_antes'] != null)
                        'stock ${_fmtNum(m['stock_antes'])} → ${_fmtNum(m['stock_despues'])}',
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ formulario

  void _abrirFormulario() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _FormularioMerma(
          productos: _productos,
          onRegistrar: _registrar,
        ),
      ),
    );
  }

  Future<void> _registrar({
    required ProductoOperativo producto,
    required String cantidad,
    required String tipo,
    required String motivo,
    String? notas,
  }) async {
    final r = await _servicio.registrarMerma(
      productoId: producto.id,
      cantidad: cantidad,
      tipo: tipo,
      motivo: motivo,
      notas: notas,
    );
    if (!mounted) return;
    if (r['error'] != null) {
      _aviso('No se pudo registrar: ${r['error']}', esError: true);
      return;
    }
    Navigator.of(context).pop();
    _aviso('Merma registrada. Stock y kardex actualizados en el servidor.');
    await _cargar();
  }

  void _aviso(String texto, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: esError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
    ));
  }

  Future<void> _elegirRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: (_desde != null && _hasta != null)
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
    );
    if (rango == null) return;
    setState(() {
      _desde = rango.start;
      _hasta = rango.end;
    });
    await _cargar();
  }

  String _fechaCorta(DateTime d) => DateFormat('dd/MM').format(d);
  String _fechaHora(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso.length > 16 ? iso.substring(0, 16) : iso;
    }
  }
}

String _fmt(dynamic v, {int decimales = 2}) {
  final n = double.tryParse(v?.toString() ?? '0') ?? 0;
  return NumberFormat('#,##0.${'0' * decimales}').format(n);
}

String _fmtNum(dynamic v) {
  final n = double.tryParse(v?.toString() ?? '0') ?? 0;
  return n == n.truncateToDouble() ? n.toStringAsFixed(0) : n.toString();
}

/// Formulario de registro. El unico campos que se validan aqui es el motivo
/// (lo exige el backend para auditar la perdida); el resto lo responde el
/// servidor con su mensaje original.
class _FormularioMerma extends StatefulWidget {
  final List<ProductoOperativo> productos;
  final Future<void> Function({
    required ProductoOperativo producto,
    required String cantidad,
    required String tipo,
    required String motivo,
    String? notas,
  }) onRegistrar;

  const _FormularioMerma({required this.productos, required this.onRegistrar});

  @override
  State<_FormularioMerma> createState() => _FormularioMermaState();
}

class _FormularioMermaState extends State<_FormularioMerma> {
  final _motivo = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  final _notas = TextEditingController();
  ProductoOperativo? _producto;
  String _tipo = 'merma';
  bool _guardando = false;
  String? _errorLocal;

  @override
  void dispose() {
    _motivo.dispose();
    _cantidad.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _errorLocal = null);

    if (_producto == null) {
      setState(() => _errorLocal = 'Selecciona el producto que se perdio.');
      return;
    }
    final cant = double.tryParse(_cantidad.text.replaceAll(',', '.'));
    if (cant == null || cant <= 0) {
      setState(() => _errorLocal = 'La cantidad debe ser un numero mayor a 0.');
      return;
    }
    if (_motivo.text.trim().isEmpty) {
      setState(() => _errorLocal = 'El motivo es obligatorio para auditar la perdida.');
      return;
    }
    // Aviso temprano de stock, sin supplantar al backend: el sigue siendo la
    // fuente de verdad y es quien bloquea la operacion.
    if (cant > _producto!.stock) {
      setState(() => _errorLocal =
          'Ojo: el producto muestra ${_fmt(_producto!.stock)} en stock y pediste $cant. '
          'Si el servidor tiene otro valor, el sera el que cuenta.');
      return;
    }

    setState(() => _guardando = true);
    await widget.onRegistrar(
      producto: _producto!,
      cantidad: _cantidad.text.trim().replaceAll(',', '.'),
      tipo: _tipo,
      motivo: _motivo.text.trim(),
      notas: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
    );
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final sinProductos = widget.productos.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar merma',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'El descuento de stock y el movimiento de kardex los aplica el servidor al guardar.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (sinProductos)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No hay productos activos para registrar mermas. Carga primero tu catalogo.',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              DropdownButtonFormField<ProductoOperativo>(
                isExpanded: true,
                initialValue: _producto,
                decoration: const InputDecoration(
                  labelText: 'Producto *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.productos
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.nombre}  ·  stock ${_fmt(p.stock)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _producto = v),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _cantidad,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: tiposMerma
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t[0].toUpperCase() + t.substring(1))))
                      .toList(),
                  onChanged: (v) => setState(() => _tipo = v ?? 'merma'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo *',
                hintText: 'Ej: producto vencido enRevision de bodega',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorLocal != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.3)),
                ),
                child: Text(_errorLocal!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFC62828))),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              TextButton(
                onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _guardando || sinProductos ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_guardando ? 'Guardando' : 'Registrar'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}