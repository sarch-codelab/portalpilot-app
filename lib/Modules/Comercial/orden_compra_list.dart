import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';

class OrdenCompraList extends StatefulWidget {
  const OrdenCompraList({super.key});

  @override
  State<OrdenCompraList> createState() => _OrdenCompraListState();
}

class _OrdenCompraListState extends State<OrdenCompraList> {
  final _service = ComercialService.instance;
  List<OrdenesCompraData> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.getOrdenesCompra();
    setState(() {
      _list = items;
      _loading = false;
    });
  }

  void _openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdenCompraForm()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Órdenes de compra')),
      floatingActionButton: FloatingActionButton(onPressed: _openCreate, child: const Icon(Icons.add)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final o = _list[i];
          return ListTile(
            title: Text(o.correlativo ?? '---'),
            subtitle: Text('${o.proveedorId ?? ''} • ${o.total.toStringAsFixed(2)}'),
            trailing: Text(o.estado ?? ''),
          );
        },
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
  final _notas = TextEditingController();

  Future<void> _save() async {
    final proveedores = await _service.getProveedores();
    if (proveedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crear primero un proveedor')));
      return;
    }
    final proveedor = proveedores.first;
    final items = <(Producto, int, double, double)>[]; // placeholder
    await _service.crearOrdenCompra(proveedorId: proveedor.id, items: items, notas: _notas.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Orden de Compra')),
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