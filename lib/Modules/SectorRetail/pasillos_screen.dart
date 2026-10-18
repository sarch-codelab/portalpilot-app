// lib/Modules/SectorRetail/pasillos_screen.dart
// Pasillos del sector retail (FASE 5).
//
// El backend tiene dos reglas que esta pantalla respeta y no esconde:
//  1. Un pasillo se DESACTIVA, no se borra: sus productos seguirian apuntando a
//     un pasillo inexistente. "Eliminar" en la UI significa desactivar.
//  2. Un pasillo con productos no se desactiva si eso dejaria huerfano el stock;
//     el servidor responde 409 y la pantalla muestra su mensaje.
//
// La consulta de productos y de stock la hace el servidor en /api/pasillos:
// cada pasillo trae productos y stock ya agregados.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:portal_pilot_app/Shared/services/operaciones_service.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_empty_state.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';

class PasillosScreen extends StatefulWidget {
  const PasillosScreen({super.key});

  @override
  State<PasillosScreen> createState() => _PasillosScreenState();
}

class _PasillosScreenState extends State<PasillosScreen> {
  final _servicio = OperacionesService.instance;

  List<Map<String, dynamic>> _pasillos = [];
  List<ProductoOperativo> _productosDelPasillo = const [];
  bool _cargando = true;
  String? _error;
  bool _sinPermiso = false;
  String _busqueda = '';
  String? _seleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await _servicio.pasillos();
    if (!mounted) return;
    setState(() {
      _pasillos = r.items;
      _cargando = false;
      _error = r.error;
      _sinPermiso = r.sinPermiso;
    });
    if (_seleccionado != null) await _cargarProductos(_seleccionado!);
  }

  /// Los productos del pasillo se piden filtrados al servidor: asi el conteo
  /// que muestra la tarjeta y la lista coinciden con la fuente de verdad.
  Future<void> _cargarProductos(String pasilloId) async {
    final r = await _servicio.productos(pasilloId: pasilloId);
    if (!mounted) return;
    setState(() {
      _seleccionado = pasilloId;
      _productosDelPasillo = r.items;
    });
  }

  List<Map<String, dynamic>> get _visibles {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return _pasillos;
    return _pasillos.where((p) {
      return (p['nombre'] ?? '').toString().toLowerCase().contains(q) ||
          (p['codigo'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  bool _activo(Map<String, dynamic> p) => p['activo'] != false;

  @override
  Widget build(BuildContext context) {
    return PPModuleScaffold(
      moduleId: 'retail_pasillos',
      screenTitle: 'Pasillos',
      moduleIcon: Icons.shelves,
      moduleColor: const Color(0xFF6A1B9A),
      loading: _cargando,
      onRefresh: _cargar,
      onNew: _error == null ? () => _formulario() : null,
      child: Column(
        children: [
          _barraBusqueda(),
          Expanded(
            child: _error != null
                ? _estadoError()
                : _visibles.isEmpty
                    ? _estadoVacio()
                    : _lista(),
          ),
        ],
      ),
    );
  }

  Widget _barraBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          hintText: 'Buscar pasillo por nombre o codigo',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _estadoError() {
    return Center(
      child: PPEmptyState(
        icon: _sinPermiso ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
        title: _sinPermiso ? 'No disponible en tu plan' : 'No se pudieron cargar los pasillos',
        message: _error!,
        action: FilledButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ),
    );
  }

  Widget _estadoVacio() {
    final hayDatos = _pasillos.isNotEmpty;
    return Center(
      child: PPEmptyState(
        icon: Icons.shelves,
        title: hayDatos ? 'Sin resultados' : 'Aun no tienes pasillos',
        message: hayDatos
            ? 'Ningun pasillo coincide con la busqueda.'
            : 'Crea tu primer pasillo para organizar el catalogo por ubicacion.',
        action: hayDatos
            ? null
            : FilledButton.icon(
                onPressed: _formulario,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo pasillo'),
              ),
      ),
    );
  }

  Widget _lista() {
    return LayoutBuilder(
      builder: (context, box) {
        // Dos columnas en tablet y escritorio, una en movil.
        final columnas = box.maxWidth >= 900
            ? 3
            : box.maxWidth >= 600
                ? 2
                : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columnas == 1 ? 2.4 : 1.7,
          ),
          itemCount: _visibles.length,
          itemBuilder: (context, i) => _tarjeta(_visibles[i]),
        );
      },
    );
  }

  Widget _tarjeta(Map<String, dynamic> p) {
    final activo = _activo(p);
    final productos = (p['productos'] ?? 0);
    final stock = (double.tryParse((p['stock'] ?? 0).toString()) ?? 0);
    final seleccionados = _seleccionado == p['id'];

    return Card(
      elevation: seleccionados ? 3 : 1,
      child: InkWell(
        onTap: () => _abrirProductos(p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shelves,
                      size: 18,
                      color: activo ? const Color(0xFF6A1B9A) : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (p['nombre'] ?? 'Sin nombre').toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: activo ? null : Colors.grey,
                        decoration: activo ? null : TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!activo)
                    const Chip(
                      label: Text('Inactivo', style: TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              if ((p['codigo'] ?? '').toString().isNotEmpty)
                Text((p['codigo']).toString(),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _dato('Productos', '$productos'),
                  _dato('Stock', _fmt(stock)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _formulario(existente: p),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Editar'),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12)),
                  ),
                  // El backend desactiva en vez de borrar: por eso el boton
                  // dice Desactivar y no Eliminar.
                  TextButton.icon(
                    onPressed: () => _alternar(p, activo),
                    icon: Icon(activo ? Icons.toggle_off_rounded : Icons.toggle_on_rounded, size: 16),
                    label: Text(activo ? 'Desactivar' : 'Reactivar'),
                    style: TextButton.styleFrom(
                      foregroundColor: activo ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }

  // ------------------------------------------------------------- acciones

  Future<void> _alternar(Map<String, dynamic> p, bool activo) async {
    final id = p['id'].toString();
    final r = activo ? await _servicio.desactivarPasillo(id) : await _servicio.reactivarPasillo(id);
    if (!mounted) return;
    if (r['error'] != null) {
      _aviso('No se pudo cambiar el estado: ${r['error']}', error: true);
      return;
    }
    _aviso(activo ? 'Pasillo desactivado.' : 'Pasillo reactivado.');
    await _cargar();
  }

  void _formulario({Map<String, dynamic>? existente}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _FormularioPasillo(
          existente: existente,
          onGuardar: _guardar,
        ),
      ),
    );
  }

  Future<void> _guardar({String? id, required String nombre, String? codigo}) async {
    final r = id == null
        ? await _servicio.crearPasillo(nombre: nombre, codigo: codigo)
        : await _servicio.editarPasillo(id, nombre: nombre, codigo: codigo);
    if (!mounted) return;
    if (r['error'] != null) {
      _aviso(r['error'].toString(), error: true);
      return;
    }
    Navigator.of(context).pop();
    _aviso(id == null ? 'Pasillo creado.' : 'Pasillo actualizado.');
    await _cargar();
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
    ));
  }

  // ------------------------------------------------------ panel de productos

  void _abrirProductos(Map<String, dynamic> p) {
    _seleccionado = p['id'].toString();
    _cargarProductos(_seleccionado!);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PanelProductos(
        pasillo: p,
        productos: _productosDelPasillo,
        onCerrar: () => setState(() {
          _seleccionado = null;
          _productosDelPasillo = const [];
        }),
      ),
    );
  }
}

class _PanelProductos extends StatelessWidget {
  final Map<String, dynamic> pasillo;
  final List<ProductoOperativo> productos;
  final VoidCallback onCerrar;

  const _PanelProductos({
    required this.pasillo,
    required this.productos,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Productos en ${(pasillo['nombre'] ?? '').toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${productos.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: productos.isEmpty
                ? const PPEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Sin productos',
                    message: 'Este pasillo aun no tiene productos asignados.',
                  )
                : ListView.builder(
                    itemCount: productos.length,
                    itemBuilder: (context, i) {
                      final pr = productos[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.qr_code_2_rounded, size: 20),
                        title: Text(pr.nombre, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [if (pr.codigo.isNotEmpty) pr.codigo, if (pr.categoria != null) pr.categoria!]
                              .join('  ·  '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('stock ${_fmt(pr.stock)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('L ${_fmt(pr.precioVenta)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCerrar,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioPasillo extends StatefulWidget {
  final Map<String, dynamic>? existente;
  final Future<void> Function({String? id, required String nombre, String? codigo}) onGuardar;

  const _FormularioPasillo({this.existente, required this.onGuardar});

  @override
  State<_FormularioPasillo> createState() => _FormularioPasilloState();
}

class _FormularioPasilloState extends State<_FormularioPasillo> {
  late final TextEditingController _nombre =
      TextEditingController(text: (widget.existente?['nombre'] ?? '').toString());
  late final TextEditingController _codigo =
      TextEditingController(text: (widget.existente?['codigo'] ?? '').toString());
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'El nombre del pasillo es obligatorio.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    await widget.onGuardar(
      id: widget.existente?['id']?.toString(),
      nombre: _nombre.text.trim(),
      codigo: _codigo.text.trim().isEmpty ? null : _codigo.text.trim(),
    );
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existente == null ? 'Nuevo pasillo' : 'Editar pasillo',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _nombre,
            autofocus: widget.existente == null,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              hintText: 'Ej: Pasillo 1 - Bebidas',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            decoration: const InputDecoration(
              labelText: 'Codigo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            TextButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_guardando ? 'Guardando' : 'Guardar'),
            ),
          ]),
        ],
      ),
    );
  }
}

String _fmt(dynamic v) {
  final n = double.tryParse(v?.toString() ?? '0') ?? 0;
  return NumberFormat('#,##0.##').format(n);
}