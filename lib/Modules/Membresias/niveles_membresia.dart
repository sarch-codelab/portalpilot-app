import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class NivelesMembresia extends StatefulWidget {
  const NivelesMembresia({super.key});

  @override
  State<NivelesMembresia> createState() => _NivelesMembresiaState();
}

class _NivelesMembresiaState extends State<NivelesMembresia> {
  List<Map<String, dynamic>> _niveles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarNiveles();
  }

  Future<void> _cargarNiveles() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/membresias/planes');
      if (api.isSuccess(result)) {
        final data = result['planes'] ?? result['data'] ?? [];
        if (data is List && data.isNotEmpty && mounted) {
          setState(() {
            _niveles = data.map<Map<String, dynamic>>((p) {
              final plan = Map<String, dynamic>.from(p);
              return {
                'id': plan['id']?.toString() ?? '',
                'nombre':
                    plan['nombre'] ?? plan['name'] ?? 'Sin nombre',
                'puntos_minimos':
                    plan['puntos_minimos'] ?? plan['puntosMinimos'] ?? 0,
                'descuento': plan['descuento'] ?? 0,
                'beneficios': (plan['beneficios'] is List)
                    ? List<String>.from(plan['beneficios'])
                    : <String>[],
              };
            }).toList();
            _cargando = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando planes de membresía: $e');
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
            color: Color(0xFFCD7F32),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Niveles de Membresía',
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
              color: const Color(0xFFCD7F32),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCD7F32)))
          : _niveles.isEmpty
          ? Center(
              child: Text(
                'No hay niveles de membresía',
                style: GoogleFonts.dmSans(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFCD7F32),
              onRefresh: _cargarNiveles,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _niveles.length,
                itemBuilder: (context, index) {
                  final nivel = _niveles[index];
                  return _buildNivelCard(nivel, palette);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddNivelDialog();
        },
        backgroundColor: const Color(0xFFCD7F32),
        icon: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
        label: Text(
          'Nuevo Nivel',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNivelCard(Map<String, dynamic> nivel, ThemePalette palette) {
    final color = nivel['nombre'] == 'Oro'
        ? const Color(0xFFF59E0B)
        : nivel['nombre'] == 'Plata'
        ? const Color(0xFF9CA3AF)
        : const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      nivel['nombre'] == 'Oro'
                          ? Icons.emoji_events_rounded
                          : nivel['nombre'] == 'Plata'
                          ? Icons.stars_rounded
                          : Icons.verified_rounded,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    nivel['nombre'],
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${nivel['descuento']}% descuento',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${nivel['puntos_minimos']} puntos mínimos',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: appThemeNotifier.isDark
                  ? const Color(0xFFA3A3A3)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Beneficios:',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appThemeNotifier.isDark
                  ? const Color(0xFFA3A3A3)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          ...(nivel['beneficios'] as List<String>).map(
            (beneficio) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    beneficio,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: appThemeNotifier.isDark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNivelDialog() {
    final nombreController = TextEditingController();
    final puntosController = TextEditingController();
    final descuentoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Nuevo Nivel',
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
                labelText: 'Nombre del nivel',
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
            TextField(
              controller: puntosController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Puntos mínimos',
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
            TextField(
              controller: descuentoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Descuento (%)',
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
                _niveles.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'puntos_minimos': int.tryParse(puntosController.text) ?? 0,
                  'descuento': int.tryParse(descuentoController.text) ?? 0,
                  'beneficios': ['Beneficio personalizado'],
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD7F32),
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
