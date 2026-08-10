import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/membresia_service.dart';

/// Precios preferenciales por socio y producto.
class PrecioScreen extends StatefulWidget {
  const PrecioScreen({super.key});

  @override
  State<PrecioScreen> createState() => _PrecioScreenState();
}

class _PrecioScreenState extends State<PrecioScreen> {
  final _service = MembresiaService.instance;

  bool _cargando = true;
  List<Socio> _socios = [];
  String? _socioId;
  List<SocioPrecio> _precios = [];

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
    final socios = await _service.getSocios();
    List<SocioPrecio> precios = [];
    if (_socioId != null) {
      precios = await _service.getPreciosPreferenciales(socioId: _socioId);
    }
    if (!mounted) return;
    setState(() {
      _socios = socios;
      _precios = precios;
      _cargando = false;
    });
  }

  void _seleccionarSocio(String? id) {
    setState(() => _socioId = id);
    _cargar();
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
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_offer_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'PRECIOS PREF.',
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
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildSocioSelector(),
                  const SizedBox(height: 20),
                  if (_socioId == null)
                    _buildSeleccionaSocio()
                  else ...[
                    Text(
                      'PRODUCTOS CON PRECIO ESPECIAL',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF525252),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_precios.isEmpty)
                      _buildSinPrecios()
                    else
                      ..._precios.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPrecioCard(p),
                        ),
                      ),
                    const SizedBox(height: 90),
                  ],
                ],
              ),
      ),
      floatingActionButton: _socioId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _agregarPrecio(),
              backgroundColor: const Color(0xFF10B981),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              label: Text(
                'Agregar',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildSocioSelector() {
    return GestureDetector(
      onTap: () {
        if (_socios.isEmpty) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF141414),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _socios
                  .map(
                    (s) => ListTile(
                      leading: const Icon(Icons.person_rounded,
                          color: Color(0xFF10B981)),
                      title: Text(
                        s.nombre,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        s.telefono ?? s.email ?? s.documento ?? 'Socio',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF737373),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _seleccionarSocio(s.id);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            Icon(
              _socioId != null
                  ? Icons.check_circle_rounded
                  : Icons.person_rounded,
              color: _socioId != null
                  ? const Color(0xFF10B981)
                  : const Color(0xFF404040),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _socioId == null
                  ? Text(
                      'Seleccionar socio',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    )
                  : Text(
                      _nombreSocio(_socioId!),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  String _nombreSocio(String id) {
    for (final s in _socios) {
      if (s.id == id) return s.nombre;
    }
    return 'Socio';
  }

  Widget _buildSeleccionaSocio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_offer_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Seleccioná un socio',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Para asignar precios preferenciales por producto.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildSinPrecios() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Text(
        'Sin precios preferenciales para este socio.',
        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
      ),
    );
  }

  Widget _buildPrecioCard(SocioPrecio p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_offer_rounded,
                color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.productoNombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'L.${p.precioPreferencial.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _quitarPrecio(p),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarPrecio() async {
    final productos = await LocalDatabaseService.instance
        .getProductos(AuthController.instance.empresaCodigo);
    if (!mounted) return;
    if (productos.isEmpty) {
      _snack('No hay productos disponibles.', const Color(0xFFEF4444));
      return;
    }
    final resultado = await _dialogPrecio(productos);
    if (resultado == null) return;
    try {
      await _service.asignarPrecioPreferencial(
        socioId: _socioId!,
        producto: resultado['producto'],
        precio: resultado['precio'],
      );
      _snack('Precio preferencial asignado.', const Color(0xFF10B981));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
    }
  }

  Future<Map<String, dynamic>?> _dialogPrecio(List<Producto> productos) async {
    Producto? producto;
    final precioController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Precio preferencial',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: null,
                  hint: Text('Seleccionar producto',
                      style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373))),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  decoration: _inputDecoration('Producto'),
                  items: productos
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.nombre} · L.${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    producto = productos.firstWhere((p) => p.id == v);
                    if (precioController.text.trim().isEmpty) {
                      precioController.text = producto!.precioVenta.toStringAsFixed(2);
                    }
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precioController,
                  style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Precio (L.)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
            ),
            TextButton(
              onPressed: () {
                final precio = double.tryParse(precioController.text.trim().replaceAll(',', ''));
                if (producto == null || precio == null || precio <= 0) return;
                Navigator.pop(ctx, {'producto': producto, 'precio': precio});
              },
              child: Text(
                'Guardar',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quitarPrecio(SocioPrecio p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quitar precio',
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Quitar el precio preferencial de "${p.productoNombre}"?',
          style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.dmSans(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, quitar',
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
      await _service.eliminarPrecioPreferencial(p.id);
      _snack('Precio preferencial eliminado.', const Color(0xFFEF4444));
      _cargar();
    } catch (e) {
      _snack(_mensajeError(e), const Color(0xFFEF4444));
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
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
  }

  String _mensajeError(Object e) {
    var msg = e.toString();
    msg = msg.replaceFirst('Bad state: ', '');
    msg = msg.replaceFirst('Invalid argument(s): ', '');
    return msg;
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
