import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class PuntosRecompensas extends StatefulWidget {
  const PuntosRecompensas({super.key});

  @override
  State<PuntosRecompensas> createState() => _PuntosRecompensasState();
}

class _PuntosRecompensasState extends State<PuntosRecompensas> {
  List<Map<String, dynamic>> _socios = [
    {
      'id': '1',
      'nombre': 'Juan Pérez',
      'puntos': 2450,
      'nivel': 'Oro',
      'beneficios': ['5% descuento', 'Acceso prioritario'],
    },
    {
      'id': '2',
      'nombre': 'María García',
      'puntos': 1200,
      'nivel': 'Plata',
      'beneficios': ['3% descuento', 'Promociones exclusivas'],
    },
    {
      'id': '3',
      'nombre': 'Carlos López',
      'puntos': 850,
      'nivel': 'Bronce',
      'beneficios': ['2% descuento'],
    },
  ];

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
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
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Puntos y Recompensas',
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
              color: const Color(0xFF8B5CF6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _socios.length,
        itemBuilder: (context, index) {
          final socio = _socios[index];
          return _buildSocioCard(socio, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddPointsDialog();
        },
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
        label: Text(
          'Agregar Puntos',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSocioCard(Map<String, dynamic> socio, ThemePalette palette) {
    final nivelColor = socio['nivel'] == 'Oro'
        ? const Color(0xFFF59E0B)
        : socio['nivel'] == 'Plata'
        ? const Color(0xFF9CA3AF)
        : const Color(0xFFCD7F32);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                socio['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: nivelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  socio['nivel'],
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: nivelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${socio['puntos']} puntos',
                style: GoogleFonts.syne(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showRedeemDialog(socio);
                },
                icon: const Icon(Icons.redeem_rounded, size: 16),
                label: const Text('Canjear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beneficios activos:',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appThemeNotifier.isDark
                      ? const Color(0xFFA3A3A3)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              ...(socio['beneficios'] as List<String>).map(
                (beneficio) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        beneficio,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: appThemeNotifier.isDark
                              ? const Color(0xFFA3A3A3)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddPointsDialog() {
    final puntosController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Agregar Puntos',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: puntosController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad de puntos',
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Funcionalidad en desarrollo'),
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
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

  void _showRedeemDialog(Map<String, dynamic> socio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Canjear Puntos',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Tienes ${socio['puntos']} puntos disponibles. ¿Cuántos deseas canjear?',
          style: GoogleFonts.dmSans(
            color: appThemeNotifier.isDark
                ? const Color(0xFFA3A3A3)
                : const Color(0xFF6B7280),
          ),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Funcionalidad en desarrollo'),
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: Text(
              'Canjear',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
