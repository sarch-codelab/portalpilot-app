import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class CampanasMarketing extends StatefulWidget {
  const CampanasMarketing({super.key});

  @override
  State<CampanasMarketing> createState() => _CampanasMarketingState();
}

class _CampanasMarketingState extends State<CampanasMarketing> {
  List<Map<String, dynamic>> _campanas = [
    {'id': '1', 'nombre': 'Promo Verano 2026', 'tipo': 'Descuento', 'estado': 'Activa', 'fecha_inicio': '2026-08-01', 'fecha_fin': '2026-08-31'},
    {'id': '2', 'nombre': 'Fidelizacion Clientes', 'tipo': 'Puntos Dobles', 'estado': 'Programada', 'fecha_inicio': '2026-09-01', 'fecha_fin': '2026-09-30'},
    {'id': '3', 'nombre': 'Lanzamiento Producto', 'tipo': 'Email Marketing', 'estado': 'Completada', 'fecha_inicio': '2026-07-15', 'fecha_fin': '2026-07-31'},
  ];

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF10B981), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Campanas de Marketing', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF10B981),
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
        itemCount: _campanas.length,
        itemBuilder: (context, index) {
          final campana = _campanas[index];
          return _buildCampanaCard(campana, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCampanaDialog(),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nueva Campana', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildCampanaCard(Map<String, dynamic> campana, ThemePalette palette) {
    final estadoColor = campana['estado'] == 'Activa' ? const Color(0xFF10B981) : 
                     campana['estado'] == 'Programada' ? const Color(0xFFF59E0B) : 
                     const Color(0xFF6366F1);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                campana['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  campana['estado'],
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Tipo', campana['tipo']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow('Inicio', campana['fecha_inicio']),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Fin', campana['fecha_fin']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  void _showAddCampanaDialog() {
    final nombreController = TextEditingController();
    final tipoController = TextEditingController();
    final fechaInicioController = TextEditingController();
    final fechaFinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Nueva Campana', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de la campana',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tipoController,
              decoration: InputDecoration(
                labelText: 'Tipo (Descuento/Puntos/Email)',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fechaInicioController,
              decoration: InputDecoration(
                labelText: 'Fecha inicio (YYYY-MM-DD)',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fechaFinController,
              decoration: InputDecoration(
                labelText: 'Fecha fin (YYYY-MM-DD)',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _campanas.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'tipo': tipoController.text,
                  'estado': 'Programada',
                  'fecha_inicio': fechaInicioController.text,
                  'fecha_fin': fechaFinController.text,
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: Text('Guardar', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
