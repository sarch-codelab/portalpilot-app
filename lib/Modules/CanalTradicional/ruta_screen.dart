import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_tradicional_service.dart';

/// Rutas de reparto / visita del Canal Tradicional.
/// CRUD de rutas y asignación de clientes a cada ruta.
class RutaScreen extends StatefulWidget {
  const RutaScreen({super.key});

  @override
  State<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends State<RutaScreen> {
  final _service = CanalTradicionalService.instance;

  bool _cargando = true;
  List<RutaInfo> _rutas = [];
  int _clientesSinRuta = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final rutas = await _service.getRutas();
    final clientesSinRuta = await _service.getClientesSinRuta();
    if (!mounted) return;
    setState(() {
      _rutas = rutas;
      _clientesSinRuta = clientesSinRuta.length;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFF97316),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.route_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'RUTAS',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearRuta,
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nueva Ruta',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF8B5CF6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildResumen(),
                  const SizedBox(height: 16),
                  if (_rutas.isEmpty)
                    _buildVacio()
                  else
                    ..._rutas.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildRutaCard(r),
                        )),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }

  Widget _buildResumen() {
    final clientesTotales = _rutas.fold<int>(0, (s, r) => s + r.clienteCount);
    return Row(
      children: [
        _buildResumenCard(
          'Rutas',
          '${_rutas.length}',
          Icons.route_rounded,
          const Color(0xFF8B5CF6),
        ),
        const SizedBox(width: 10),
        _buildResumenCard(
          'Clientes en rutas',
          '$clientesTotales',
          Icons.groups_rounded,
          const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 10),
        _buildResumenCard(
          'Sin ruta',
          '$_clientesSinRuta',
          Icons.person_off_rounded,
          const Color(0xFFF97316),
        ),
      ],
    );
  }

  Widget _buildResumenCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          const Icon(Icons.route_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin rutas configuradas',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creá rutas de reparto o visita y asigná clientes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildRutaCard(RutaInfo info) {
    final r = info.ruta;
    return GestureDetector(
      onTap: () => _detalleRuta(info),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${RutaFrecuencia.etiqueta(r.frecuencia)} · ${RutaFrecuencia.diaEtiqueta(r.diaSemana)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${info.clienteCount} cltes',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ],
            ),
            if (r.vendedor?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_rounded, color: Color(0xFF737373), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    r.vendedor!,
                    style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
                  ),
                ],
              ),
            ],
            if (r.descripcion?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                r.descripcion!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _detalleRuta(RutaInfo info) async {
    final clientesRuta = await _service.getClientesRuta(info.ruta.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              info.ruta.nombre,
              style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '${RutaFrecuencia.etiqueta(info.ruta.frecuencia)} · ${RutaFrecuencia.diaEtiqueta(info.ruta.diaSemana)}',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
            ),
            const SizedBox(height: 18),
            Text(
              'CLIENTES ASIGNADOS',
              style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFA3A3A3), letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            if (clientesRuta.isEmpty)
              Text(
                'Sin clientes asignados.',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
              )
            else
              ...clientesRuta.map((c) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF1F1F1F)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: Color(0xFF737373), size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.clienteNombre ?? c.clienteId,
                            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                          ),
                        ),
                        Text(
                          '#${c.orden + 1}',
                          style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _botonAccion(
                    Icons.groups_rounded,
                    'Asignar clientes',
                    const Color(0xFF8B5CF6),
                    () {
                      Navigator.pop(ctx);
                      _asignarClientes(info);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _botonAccion(
                    Icons.edit_rounded,
                    'Editar',
                    const Color(0xFF3B82F6),
                    () {
                      Navigator.pop(ctx);
                      _editarRuta(info);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _botonAccion(
                Icons.delete_rounded,
                'Eliminar ruta',
                const Color(0xFFEF4444),
                () {
                  Navigator.pop(ctx);
                  _eliminarRuta(info);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonAccion(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearRuta() async {
    final resultado = await _dialogRuta(null);
    if (resultado == null) return;

    await _service.crearRuta(
      nombre: resultado['nombre'],
      vendedor: resultado['vendedor'],
      frecuencia: resultado['frecuencia'],
      diaSemana: resultado['diaSemana'],
      descripcion: resultado['descripcion'],
    );
    _snack('Ruta creada.', const Color(0xFF8B5CF6));
    _cargar();
  }

  Future<void> _editarRuta(RutaInfo info) async {
    final r = info.ruta;
    final resultado = await _dialogRuta(
      {
        'nombre': r.nombre,
        'vendedor': r.vendedor,
        'frecuencia': r.frecuencia,
        'diaSemana': r.diaSemana,
        'descripcion': r.descripcion,
      },
    );
    if (resultado == null) return;

    await _service.actualizarRuta(
      id: r.id,
      nombre: resultado['nombre'],
      vendedor: resultado['vendedor'],
      frecuencia: resultado['frecuencia'],
      diaSemana: resultado['diaSemana'],
      descripcion: resultado['descripcion'],
    );
    _snack('Ruta actualizada.', const Color(0xFF8B5CF6));
    _cargar();
  }

  Future<Map<String, dynamic>?> _dialogRuta(Map<String, dynamic>? inicial) async {
    final nombreController = TextEditingController(text: inicial?['nombre'] ?? '');
    final vendedorController = TextEditingController(text: inicial?['vendedor'] ?? '');
    final descripcionController = TextEditingController(text: inicial?['descripcion'] ?? '');
    String frecuencia = inicial?['frecuencia'] ?? RutaFrecuencia.semanal;
    int? diaSemana = inicial?['diaSemana'];

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          inicial == null ? 'Nueva ruta' : 'Editar ruta',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Nombre de la ruta'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vendedorController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Vendedor / repartidor'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frecuencia,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Frecuencia'),
                  items: RutaFrecuencia.opciones
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(RutaFrecuencia.etiqueta(f)),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => frecuencia = v ?? RutaFrecuencia.semanal),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: diaSemana,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Día de visita'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Sin día fijo')),
                    ...List.generate(7, (i) {
                      return DropdownMenuItem<int?>(
                        value: i,
                        child: Text(RutaFrecuencia.diasSemana[i]),
                      );
                    }),
                  ],
                  onChanged: (v) => setDialogState(() => diaSemana = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  maxLines: 2,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Descripción (opcional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(ctx, {
                'nombre': nombre,
                'vendedor': vendedorController.text.trim().isEmpty
                    ? null
                    : vendedorController.text.trim(),
                'frecuencia': frecuencia,
                'diaSemana': diaSemana,
                'descripcion': descripcionController.text.trim().isEmpty
                    ? null
                    : descripcionController.text.trim(),
              });
            },
            child: Text('Guardar', style: GoogleFonts.dmSans(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _asignarClientes(RutaInfo info) async {
    final todos = await _service.getClientes();
    final actuales = await _service.getClientesRuta(info.ruta.id);
    if (!mounted) return;

    final idsActuales = actuales.map((c) => c.clienteId).toSet();
    final seleccionados = <String>{...idsActuales};

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clientes en ruta',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: todos.isEmpty
              ? Text(
                  'No hay clientes registrados.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
                )
              : ListView(
                  shrinkWrap: true,
                  children: todos.map((c) {
                    return CheckboxListTile(
                      value: seleccionados.contains(c.id),
                      activeColor: const Color(0xFF8B5CF6),
                      dense: true,
                      title: Text(
                        c.nombre,
                        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                      ),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          seleccionados.add(c.id);
                        } else {
                          seleccionados.remove(c.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _guardarAsignacion(info, seleccionados, todos);
            },
            child: Text('Guardar', style: GoogleFonts.dmSans(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarAsignacion(
    RutaInfo info,
    Set<String> seleccionados,
    List<Cliente> todos,
  ) async {
    final nombres = {
      for (final c in todos) c.id: c.nombre,
    };
    await _service.asignarClientesRuta(
      rutaId: info.ruta.id,
      clienteIds: seleccionados.toList(),
      nombresPorId: nombres,
    );
    _snack('Clientes asignados.', const Color(0xFF8B5CF6));
    _cargar();
  }

  Future<void> _eliminarRuta(RutaInfo info) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar ruta',
          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Text(
          '¿Eliminar "${info.ruta.nombre}"? También se quitarán sus clientes asignados.',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await _service.eliminarRuta(info.ruta.id);
    _snack('Ruta eliminada.', const Color(0xFFEF4444));
    _cargar();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373)),
      filled: true,
      fillColor: const Color(0xFF0F0F0F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
      ),
    );
  }

  void _snack(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.dmSans()),
        backgroundColor: color,
      ),
    );
  }
}
