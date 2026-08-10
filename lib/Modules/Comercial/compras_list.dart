import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';

class ComprasList extends StatefulWidget {
  const ComprasList({super.key});

  @override
  State<ComprasList> createState() => _ComprasListState();
}

class _ComprasListState extends State<ComprasList> {
  final _service = ComercialService.instance;
  List<Compra> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.getCompras();
    setState(() {
      _list = items;
      _loading = false;
    });
  }

  void _openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompraForm()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      floatingActionButton: FloatingActionButton(onPressed: _openCreate, child: const Icon(Icons.add)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final c = _list[i];
          return ListTile(
            title: Text(c.correlativo ?? '---'),
            subtitle: Text('${c.proveedorId ?? ''} • ${c.total.toStringAsFixed(2)}'),
            trailing: Text(c.estado ?? ''),
          );
        },
      ),
    );
  }
}

class CompraForm extends StatefulWidget {
  const CompraForm({super.key});

  @override
  State<CompraForm> createState() => _CompraFormState();
}

class _CompraFormState extends State<CompraForm> {
  final _service = ComercialService.instance;
  final _notas = TextEditingController();

  Future<void> _save() async {
    final proveedores = await _service.getProveedores();
    if (proveedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crear primero un proveedor')));
      return;
    }
    final proveedor = proveedores.first;
    final items = <(Producto, int, double, double)>[]; // placeholder
    await _service.crearCompra(proveedorId: proveedor.id, items: items, notas: _notas.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Compra')),
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
