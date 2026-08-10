import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/membresia_service.dart';

/// Gestión de planes de membresía (precio, descuento y vigencia).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _service = MembresiaService.instance;

  bool _cargando = true;
  List<Membresia> _planes = [];

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
    final planes = await _service.getMembresias();
    if (!mounted) return;
    setState(() {
      _planes = planes;
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
            color: Color(0xFF8B5CF6),
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
              child: const Icon(Icons.card_membership_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'PLANES',
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
        onPressed: () => _crearPlan(),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nuevo Plan',
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
                  if (_planes.isEmpty)
                    _buildVacio()
                  else
                    ..._planes.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildPlanCard(m),
                      ),
                    ),
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
          const Icon(Icons.card_membership_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin planes',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creá un plan para asignar membresías a tus socios.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Membresia m) {
    return GestureDetector(
      onTap: () => _detallePlan(m),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: m.activo
                ? const Color(0xFF262626)
                : const Color(0xFFEF4444).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFF8B5CF6), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.nombre,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'L.${m.precio.toStringAsFixed(2)} · '
                    '${m.vigenciaMeses} mes${m.vigenciaMeses == 1 ? '' : 'es'} · '
                    '${m.descuentoPorcentaje.toStringAsFixed(0)}% dcto',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF737373),
                    ),
                  ),
                  if (m.descripcion?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      m.descripcion!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF525252),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!m.activo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'INACTIVO',
                  style: GoogleFonts.dmSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _detallePlan(Membresia m) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
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
              m.nombre,
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'L.${m.precio.toStringAsFixed(2)} · ${m.vigenciaMeses} mes(es) · '
              '${m.descuentoPorcentaje.toStringAsFixed(0)}% descuento',
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
                      _editarPlan(m);
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
                      _eliminarPlan(m);
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

  Future<void> _crearPlan() async {
    final resultado = await _dialogPlan(null);
    if (resultado == null) return;
    try {
      await _service.crearMembresia(
        nombre: resultado['nombre'],
        descripcion: resultado['descripcion'],
        precio: resultado['precio'],
        descuentoPorcentaje: resultado['descuento'],
        vigenciaMeses: resultado['meses'],
      );
      _snack('Plan creado.', const Color(0xFF8B5CF6));
      _cargar();
    } catch (e) {
      _snack(e.toString().replaceFirst('Bad state: ', ''), const Color(0xFFEF4444));
    }
  }

  Future<void> _editarPlan(Membresia m) async {
    final resultado = await _dialogPlan({
      'nombre': m.nombre,
      'descripcion': m.descripcion,
      'precio': m.precio,
      'descuento': m.descuentoPorcentaje,
      'meses': m.vigenciaMeses,
      'activo': m.activo,
    });
    if (resultado == null) return;
    try {
      await _service.actualizarMembresia(
        id: m.id,
        nombre: resultado['nombre'],
        descripcion: resultado['descripcion'],
        precio: resultado['precio'],
        descuentoPorcentaje: resultado['descuento'],
        vigenciaMeses: resultado['meses'],
        activo: resultado['activo'],
      );
      _snack('Plan actualizado.', const Color(0xFF8B5CF6));
      _cargar();
    } catch (e) {
      _snack(e.toString().replaceFirst('Bad state: ', ''), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogPlan(Map<String, dynamic>? inicial) async {
    final nombreController = TextEditingController(text: inicial?['nombre'] ?? '');
    final descripcionController = TextEditingController(text: inicial?['descripcion'] ?? '');
    final precioController = TextEditingController(
      text: (inicial?['precio'] as double?)?.toStringAsFixed(2) ?? '0.00',
    );
    final descuentoController = TextEditingController(
      text: (inicial?['descuento'] as double?)?.toStringAsFixed(0) ?? '0',
    );
    final mesesController = TextEditingController(
      text: '${inicial?['meses'] ?? 1}',
    );
    bool activo = inicial?['activo'] ?? true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          inicial == null ? 'Nuevo plan' : 'Editar plan',
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
                  decoration: _inputDecoration('Nombre del plan'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Descripción'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Precio (L.)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: descuentoController,
                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Descuento %'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: mesesController,
                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Vigencia (meses)'),
                      ),
                    ),
                  ],
                ),
                if (inicial != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: activo,
                    activeTrackColor: const Color(0xFF8B5CF6),
                    title: Text(
                      'Activo',
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                    ),
                    onChanged: (v) => setDialogState(() => activo = v),
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
              final precio = double.tryParse(precioController.text.trim().replaceAll(',', ''));
              final dcto = double.tryParse(descuentoController.text.trim().replaceAll(',', ''));
              final meses = int.tryParse(mesesController.text.trim());
              if (nombre.isEmpty) return;
              Navigator.pop(ctx, {
                'nombre': nombre,
                'descripcion': descripcionController.text.trim().isEmpty
                    ? null
                    : descripcionController.text.trim(),
                'precio': (precio ?? 0).clamp(0, double.infinity),
                'descuento': (dcto ?? 0).clamp(0, 100),
                'meses': (meses ?? 1).clamp(1, 120),
                'activo': activo,
              });
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarPlan(Membresia m) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar plan',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Eliminar "${m.nombre}"?',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _service.eliminarMembresia(m.id);
      _snack('Plan eliminado.', const Color(0xFFEF4444));
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
