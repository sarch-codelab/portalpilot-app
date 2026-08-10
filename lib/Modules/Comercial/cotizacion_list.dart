import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';

class CotizacionList extends StatefulWidget {
  const CotizacionList({super.key});

  @override
  State<CotizacionList> createState() => _CotizacionListState();
}

class _CotizacionListState extends State<CotizacionList> {
  final _service = ComercialService.instance;
  List<Cotizacione> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.getCotizaciones();
    setState(() {
      _list = items;
      _loading = false;
    });
  }

  void _openCreate() async {
    // For now open a simple create flow that uses crearCotizacion with minimal data
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CotizacionForm()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cotizaciones')),
      floatingActionButton: FloatingActionButton(onPressed: _openCreate, child: const Icon(Icons.add)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final c = _list[i];
          return ListTile(
            title: Text(c.correlativo ?? '---'),
            subtitle: Text('${c.proveedorNombre} • ${c.total.toStringAsFixed(2)}'),
            trailing: Text(c.estado ?? ''),
          );
        },
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
  String _proveedorId = '';
  final _notas = TextEditingController();

  Future<void> _save() async {
    // Minimal create: no items, just create a placeholder cotización
    final proveedores = await _service.getProveedores();
    if (proveedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crear primero un proveedor')));
      return;
    }
    final proveedor = proveedores.first;
    final productos = <(Producto, int, double, double)>[]; // empty items — not ideal but placeholder
    await _service.crearCotizacion(proveedorId: proveedor.id, items: productos, notas: _notas.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Cotización')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextFormField(controller: _notas, decoration: const InputDecoration(labelText: 'Notas')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Crear')),
          ],
        ),
      ),
    );
  }
}