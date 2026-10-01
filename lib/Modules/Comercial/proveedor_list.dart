import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/comercial_forms_shared.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/comercial_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class ProveedorList extends StatefulWidget {
  const ProveedorList({super.key});

  @override
  State<ProveedorList> createState() => _ProveedorListState();
}

class _ProveedorListState extends State<ProveedorList> {
  final _service = ComercialService.instance;
  List<Proveedore> _proveedores = [];
  bool _loading = true;
  bool _errorRed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Datos en vivo: baja lo que haya en la nube y luego lee la BD local.
    final descargados = await _service.descargarProveedoresDesdeApi();
    final list = await _service.getProveedores();
    if (!mounted) return;
    setState(() {
      _proveedores = list;
      _errorRed = descargados < 0;
      _loading = false;
    });
  }

  void _openForm([Proveedore? p]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProveedorForm(proveedor: p)));
    await _load();
  }

  Future<void> _confirmarEliminar(Proveedore p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text('¿Eliminar a ${p.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.eliminarProveedor(p.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Bad state: ', ''),
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proveedores'),
        actions: [
          if (_errorRed)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.cloud_off_rounded, size: 18),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _proveedores.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
                        ComercialVacio(
                          icono: Icons.local_shipping_outlined,
                          titulo: 'Sin proveedores',
                          mensaje:
                              'Crea tu primer proveedor o conéctate para descargar los que ya tengas en la nube.',
                          onNuevo: () => _openForm(),
                          etiquetaBoton: 'Nuevo proveedor',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _proveedores.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _proveedores[i];
                        final extras = <String>[
                          if ((p.telefono ?? '').isNotEmpty) p.telefono!,
                          if ((p.rtn ?? '').isNotEmpty) 'RTN ${p.rtn}',
                          'Pago a ${p.condicionesPago} días',
                        ].join(' · ');
                        return Container(
                          decoration: BoxDecoration(
                            color: appPalette.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appPalette.borderLight),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: appPalette.textMuted.withValues(alpha: 0.15),
                              child: Text(
                                p.nombre.isEmpty ? '?' : p.nombre[0].toUpperCase(),
                                style: GoogleFonts.syne(fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              extras,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 11.5),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _openForm(p),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: Color(0xFFEF4444),
                                  ),
                                  onPressed: () => _confirmarEliminar(p),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
  bool _guardando = false;
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
    setState(() => _guardando = true);
    try {
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
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar: $e', style: GoogleFonts.dmSans()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
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
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              TextFormField(controller: _contacto, decoration: const InputDecoration(labelText: 'Contacto')),
              TextFormField(controller: _telefono, decoration: const InputDecoration(labelText: 'Teléfono')),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              TextFormField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección')),
              TextFormField(controller: _rtn, decoration: const InputDecoration(labelText: 'RTN')),
              DropdownButtonFormField<int>(
                initialValue: _condicionesPago,
                decoration: const InputDecoration(labelText: 'Condiciones de pago (días)'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Contado')),
                  DropdownMenuItem(value: 15, child: Text('15 días')),
                  DropdownMenuItem(value: 30, child: Text('30 días')),
                  DropdownMenuItem(value: 60, child: Text('60 días')),
                  DropdownMenuItem(value: 90, child: Text('90 días')),
                ],
                onChanged: (v) => setState(() => _condicionesPago = v ?? 30),
              ),
              TextFormField(controller: _notas, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _guardando ? null : _save,
                child: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    _direccion.dispose();
    _rtn.dispose();
    _contacto.dispose();
    _notas.dispose();
    super.dispose();
  }
}
