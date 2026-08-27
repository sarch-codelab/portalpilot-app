import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class Promociones extends StatefulWidget {
  const Promociones({super.key});

  @override
  State<Promociones> createState() => _PromocionesState();
}

class _PromocionesState extends State<Promociones> {
  List<Map<String, dynamic>> _promociones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarPromociones();
  }

  Future<void> _cargarPromociones() async {
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/promociones');
      if (api.isSuccess(res)) {
        final data = res['promociones'] ?? res['data'];
        if (data is List && mounted) {
          setState(() {
            _promociones = data.cast<Map<String, dynamic>>();
            _cargando = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[Promociones] Error cargando promociones: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Promociones',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFFF59E0B),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : _promociones.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    size: 64,
                    color: appThemeNotifier.isDark
                        ? const Color(0xFF525252)
                        : const Color(0xFFD1D5DB),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay promociones registradas',
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color:
                          appThemeNotifier.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu primera promoción para comenzar',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: appThemeNotifier.isDark
                          ? const Color(0xFFA3A3A3)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _promociones.length,
              itemBuilder: (context, index) {
                final promo = _promociones[index];
                return _buildPromoCard(promo, palette);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddPromoDialog();
        },
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nueva Promoción',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard(Map<String, dynamic> promo, ThemePalette palette) {
    final activo = promo['activo'] == true;
    final tipo = '${promo['tipo'] ?? 'general'}';
    final descuento = (promo['descuento'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appThemeNotifier.isDark
              ? const Color(0xFF262626)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activo
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              activo ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: activo
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo['nombre'],
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: appThemeNotifier.isDark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tipo.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$descuento% descuento',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: appThemeNotifier.isDark
                            ? const Color(0xFFA3A3A3)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: activo,
            onChanged: (value) {
              setState(() {
                promo['activo'] = value;
              });
            },
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  void _showAddPromoDialog() {
    final nombreController = TextEditingController();
    String tipoSeleccionado = 'bundle';
    double descuento = 10.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: appThemeNotifier.isDark
              ? const Color(0xFF111111)
              : Colors.white,
          title: Text(
            'Nueva Promoción',
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la promoción',
                  labelStyle: TextStyle(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: appThemeNotifier.isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tipoSeleccionado,
                items: const [
                  DropdownMenuItem(
                    value: 'bundle',
                    child: Text('Bundle (2x1, 3x2)'),
                  ),
                  DropdownMenuItem(
                    value: 'volumen',
                    child: Text('Volumen (>5kg, >10 unidades)'),
                  ),
                  DropdownMenuItem(
                    value: 'combo',
                    child: Text('Combo (productos relacionados)'),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tipoSeleccionado = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Tipo de promoción',
                  labelStyle: TextStyle(
                    color: appThemeNotifier.isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: appThemeNotifier.isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Descuento: ${descuento.toInt()}%',
                style: GoogleFonts.dmSans(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
              ),
              Slider(
                value: descuento,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (value) {
                  setDialogState(() {
                    descuento = value;
                  });
                },
                activeColor: const Color(0xFFF59E0B),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _promociones.add({
                    'id': DateTime.now().toString(),
                    'nombre': nombreController.text,
                    'tipo': tipoSeleccionado,
                    'descuento': descuento.toInt(),
                    'activo': true,
                  });
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
              ),
              child: Text(
                'Guardar',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
