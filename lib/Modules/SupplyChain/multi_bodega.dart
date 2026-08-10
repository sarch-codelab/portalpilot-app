import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class MultiBodega extends StatefulWidget {
  const MultiBodega({super.key});

  @override
  State<MultiBodega> createState() => _MultiBodegaState();
}

class _MultiBodegaState extends State<MultiBodega> {
  List<Map<String, dynamic>> _bodegas = [
    {'id': '1', 'nombre': 'Bodega Central', 'ubicacion': 'Tegucigalpa', 'capacidad': 5000, 'ocupacion': 3200, 'estado': 'Activa'},
    {'id': '2', 'nombre': 'Bodega Norte', 'ubicacion': 'San Pedro Sula', 'capacidad': 3000, 'ocupacion': 2100, 'estado': 'Activa'},
    {'id': '3', 'nombre': 'Bodega Sur', 'ubicacion': 'Choluteca', 'capacidad': 2000, 'ocupacion': 1200, 'estado': 'Activa'},
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF8B5CF6), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Multi-Bodega', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
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
        itemCount: _bodegas.length,
        itemBuilder: (context, index) {
          final bodega = _bodegas[index];
          return _buildBodegaCard(bodega, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBodegaDialog(),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nueva Bodega', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildBodegaCard(Map<String, dynamic> bodega, ThemePalette palette) {
    final ocupacionPorcentaje = (bodega['ocupacion'] / bodega['capacidad'] * 100).round();
    final ocupacionColor = ocupacionPorcentaje > 80 ? const Color(0xFFEF4444) : 
                           ocupacionPorcentaje > 60 ? const Color(0xFFF59E0B) : 
                           const Color(0xFF10B981);
    
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
                bodega['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bodega['estado'],
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Ubicacion', bodega['ubicacion']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow('Capacidad', '${bodega['capacidad']} uds'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ocupacion',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    '$ocupacionPorcentaje%',
                    style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ocupacionColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: bodega['ocupacion'] / bodega['capacidad'],
                backgroundColor: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(ocupacionColor),
              ),
            ],
          ),
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

  void _showAddBodegaDialog() {
    final nombreController = TextEditingController();
    final ubicacionController = TextEditingController();
    final capacidadController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Nueva Bodega', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de la bodega',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ubicacionController,
              decoration: InputDecoration(
                labelText: 'Ubicacion',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacidadController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Capacidad (unidades)',
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
                _bodegas.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'ubicacion': ubicacionController.text,
                  'capacidad': int.tryParse(capacidadController.text) ?? 0,
                  'ocupacion': 0,
                  'estado': 'Activa',
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: Text('Guardar', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
