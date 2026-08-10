import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class Fidelizacion extends StatefulWidget {
  const Fidelizacion({super.key});

  @override
  State<Fidelizacion> createState() => _FidelizacionState();
}

class _FidelizacionState extends State<Fidelizacion> {
  List<Map<String, dynamic>> _programas = [
    {'id': '1', 'nombre': 'Programa Oro', 'nivel': 'Premium', 'beneficios': 'Descuento 15%, Puntos dobles', 'clientes': 50},
    {'id': '2', 'nombre': 'Programa Plata', 'nivel': 'Regular', 'beneficios': 'Descuento 10%, Puntos normales', 'clientes': 150},
    {'id': '3', 'nombre': 'Programa Bronce', 'nivel': 'Basico', 'beneficios': 'Descuento 5%, Sin puntos extra', 'clientes': 300},
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFEC4899), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Fidelizacion Avanzada', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFEC4899),
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
        itemCount: _programas.length,
        itemBuilder: (context, index) {
          final programa = _programas[index];
          return _buildProgramaCard(programa, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProgramaDialog(),
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nuevo Programa', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildProgramaCard(Map<String, dynamic> programa, ThemePalette palette) {
    final nivelColor = programa['nivel'] == 'Premium' ? const Color(0xFF10B981) : 
                     programa['nivel'] == 'Regular' ? const Color(0xFF8B5CF6) : 
                     const Color(0xFFF59E0B);
    
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
                programa['nombre'],
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
                  programa['nivel'],
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
          Text(
            programa['beneficios'],
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${programa['clientes']} clientes activos',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFEC4899),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProgramaDialog() {
    final nombreController = TextEditingController();
    final nivelController = TextEditingController();
    final beneficiosController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Nuevo Programa', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del programa',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nivelController,
              decoration: InputDecoration(
                labelText: 'Nivel (Premium/Regular/Basico)',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: beneficiosController,
              decoration: InputDecoration(
                labelText: 'Beneficios',
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
                _programas.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'nivel': nivelController.text,
                  'beneficios': beneficiosController.text,
                  'clientes': 0,
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899)),
            child: Text('Guardar', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
