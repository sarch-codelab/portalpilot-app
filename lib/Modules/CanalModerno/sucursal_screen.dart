import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_moderno_service.dart';

/// Gestión de sucursales del Canal Moderno.
class SucursalScreen extends StatefulWidget {
  const SucursalScreen({super.key});

  @override
  State<SucursalScreen> createState() => _SucursalScreenState();
}

class _SucursalScreenState extends State<SucursalScreen> {
  final _service = CanalModernoService.instance;

  bool _cargando = true;
  List<Sucursale> _sucursales = [];

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
    final sucursales = await _service.getSucursales();
    if (!mounted) return;
    setState(() {
      _sucursales = sucursales;
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
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'SUCURSALES',
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
        onPressed: () => _crearSucursal(),
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nueva Sucursal',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (_sucursales.isEmpty)
                    _buildVacio()
                  else
                    ..._sucursales.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildSucursalCard(s),
                        )),
                  const SizedBox(height: 80),
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
          const Icon(Icons.storefront_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin sucursales',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creá tu primera sucursal para gestionar inventario por punto de venta.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildSucursalCard(Sucursale s) {
    return GestureDetector(
      onTap: () => _detalleSucursal(s),
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Código: ${s.codigo ?? '-'} · Bodega: ${_service.bodegaDe(s)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.esPrincipal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PRINCIPAL',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            if (s.encargado?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_rounded, color: Color(0xFF737373), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    s.encargado!,
                    style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
                  ),
                ],
              ),
            ],
            if (s.direccion?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFF737373), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.direccion!,
                      style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _detalleSucursal(Sucursale s) async {
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
              s.nombre,
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Código: ${s.codigo ?? '-'} · ${s.activo ? 'Activa' : 'Inactiva'}',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _botonAccion(
                    Icons.edit_rounded,
                    'Editar',
                    const Color(0xFF3B82F6),
                    () {
                      Navigator.pop(ctx);
                      _editarSucursal(s);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _botonAccion(
                    Icons.delete_rounded,
                    'Eliminar',
                    const Color(0xFFEF4444),
                    () {
                      Navigator.pop(ctx);
                      _eliminarSucursal(s);
                    },
                  ),
                ),
              ],
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
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearSucursal() async {
    final resultado = await _dialogSucursal(null);
    if (resultado == null) return;
    try {
      await _service.crearSucursal(
        nombre: resultado['nombre'],
        codigo: resultado['codigo'],
        direccion: resultado['direccion'],
        telefono: resultado['telefono'],
        encargado: resultado['encargado'],
      );
      _snack('Sucursal creada.', const Color(0xFF3B82F6));
      _cargar();
    } catch (e) {
      _snack(e.toString().replaceFirst('Bad state: ', ''), const Color(0xFFEF4444));
    }
  }

  Future<void> _editarSucursal(Sucursale s) async {
    final resultado = await _dialogSucursal(
      {
        'nombre': s.nombre,
        'codigo': s.codigo,
        'direccion': s.direccion,
        'telefono': s.telefono,
        'encargado': s.encargado,
        'esPrincipal': s.esPrincipal,
        'activo': s.activo,
      },
    );
    if (resultado == null) return;
    try {
      await _service.actualizarSucursal(
        id: s.id,
        nombre: resultado['nombre'],
        codigo: resultado['codigo'],
        direccion: resultado['direccion'],
        telefono: resultado['telefono'],
        encargado: resultado['encargado'],
        esPrincipal: resultado['esPrincipal'],
        activo: resultado['activo'],
      );
      _snack('Sucursal actualizada.', const Color(0xFF3B82F6));
      _cargar();
    } catch (e) {
      _snack(e.toString().replaceFirst('Bad state: ', ''), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogSucursal(Map<String, dynamic>? inicial) async {
    final nombreController = TextEditingController(text: inicial?['nombre'] ?? '');
    final codigoController = TextEditingController(text: inicial?['codigo'] ?? '');
    final direccionController = TextEditingController(text: inicial?['direccion'] ?? '');
    final telefonoController = TextEditingController(text: inicial?['telefono'] ?? '');
    final encargadoController = TextEditingController(text: inicial?['encargado'] ?? '');
    bool esPrincipal = inicial?['esPrincipal'] ?? false;
    bool activo = inicial?['activo'] ?? true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          inicial == null ? 'Nueva sucursal' : 'Editar sucursal',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
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
                  decoration: _inputDecoration('Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codigoController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Código / bodega'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: direccionController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Dirección'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Teléfono'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: encargadoController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Encargado'),
                ),
                if (inicial != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: activo,
                    activeTrackColor: const Color(0xFF3B82F6),
                    title: Text(
                      'Activa',
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                    ),
                    onChanged: (v) => setDialogState(() => activo = v),
                  ),
                  SwitchListTile(
                    value: esPrincipal,
                    activeTrackColor: const Color(0xFF3B82F6),
                    title: Text(
                      'Sucursal principal',
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                    ),
                    onChanged: (v) => setDialogState(() => esPrincipal = v),
                  ),
                ],
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
                'codigo': codigoController.text.trim().isEmpty
                    ? null
                    : codigoController.text.trim(),
                'direccion': direccionController.text.trim().isEmpty
                    ? null
                    : direccionController.text.trim(),
                'telefono': telefonoController.text.trim().isEmpty
                    ? null
                    : telefonoController.text.trim(),
                'encargado': encargadoController.text.trim().isEmpty
                    ? null
                    : encargadoController.text.trim(),
                'esPrincipal': esPrincipal,
                'activo': activo,
              });
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarSucursal(Sucursale s) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar sucursal',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Eliminar "${s.nombre}"?',
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

    try {
      await _service.eliminarSucursal(s.id);
      _snack('Sucursal eliminada.', const Color(0xFFEF4444));
      _cargar();
    } catch (e) {
      _snack(e.toString().replaceFirst('Bad state: ', ''), const Color(0xFFEF4444));
    }
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
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
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
