import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';

class ProveedorList extends StatefulWidget {
  const ProveedorList({super.key});

  @override
  State<ProveedorList> createState() => _ProveedorListState();
}

class _ProveedorListState extends State<ProveedorList> {
  final _service = ComercialService.instance;
  List<Proveedore> _proveedores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getProveedores();
    setState(() {
      _proveedores = list;
      _loading = false;
    });
  }

  void _openForm([Proveedore? p]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProveedorForm(proveedor: p)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _proveedores.length,
              itemBuilder: (context, i) {
                final p = _proveedores[i];
                return ListTile(
                  title: Text(p.nombre),
                  subtitle: Text(p.telefono ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openForm(p),
                  ),
                );
              },
            ),
    );
  }
}

class ProveedorForm extends StatefulWidget {
  final Proveedore? proveedor;
  const ProveedorForm({super.key, this.proveedor});

  @override
  State<ProveedorForm> createState() => _ProveedorFormState();
}

class _ProveedorFormState extends State<ProveedorForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _direccion = TextEditingController();
  final _rtn = TextEditingController();
  final _contacto = TextEditingController();
  final _notas = TextEditingController();
  int _condicionesPago = 30;
  final _service = ComercialService.instance;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedor;
    if (p != null) {
      _nombre.text = p.nombre;
      _telefono.text = p.telefono ?? '';
      _email.text = p.email ?? '';
      _direccion.text = p.direccion ?? '';
      _rtn.text = p.rtn ?? '';
      _contacto.text = p.contacto ?? '';
      _notas.text = p.notas ?? '';
      _condicionesPago = p.condicionesPago;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.proveedor == null) {
      await _service.crearProveedor(
        nombre: _nombre.text,
        contacto: _contacto.text,
        telefono: _telefono.text,
        email: _email.text,
        direccion: _direccion.text,
        rtn: _rtn.text,
        condicionesPago: _condicionesPago,
        notas: _notas.text,
      );
    } else {
      await _service.actualizarProveedor(
        id: widget.proveedor!.id,
        nombre: _nombre.text,
        contacto: _contacto.text,
        telefono: _telefono.text,
        email: _email.text,
        direccion: _direccion.text,
        rtn: _rtn.text,
        condicionesPago: _condicionesPago,
        notas: _notas.text,
        activo: true,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.proveedor == null ? 'Nuevo proveedor' : 'Editar proveedor')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre'), validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              TextFormField(controller: _contacto, decoration: const InputDecoration(labelText: 'Contacto')),
              TextFormField(controller: _telefono, decoration: const InputDecoration(labelText: 'Teléfono')),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              TextFormField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección')),
              TextFormField(controller: _rtn, decoration: const InputDecoration(labelText: 'RTN')),
              TextFormField(controller: _notas, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _save, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}
