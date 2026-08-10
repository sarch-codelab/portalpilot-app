import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class HoldingFilial extends StatefulWidget {
  const HoldingFilial({super.key});

  @override
  State<HoldingFilial> createState() => _HoldingFilialState();
}

class _HoldingFilialState extends State<HoldingFilial> {
  List<Map<String, dynamic>> _empresas = [
    {'id': '1', 'nombre': 'Holding Principal', 'tipo': 'Holding', 'estado': 'Activo'},
    {'id': '2', 'nombre': 'Supermercados Norte S.A.', 'tipo': 'Filial', 'estado': 'Activo'},
    {'id': '3', 'nombre': 'Distribuidora Centro', 'tipo': 'Filial', 'estado': 'Activo'},
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
        title: Text('Holding y Filiales', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
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
        itemCount: _empresas.length,
        itemBuilder: (context, index) {
          final empresa = _empresas[index];
          return _buildEmpresaCard(empresa, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmpresaDialog(),
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nueva Empresa', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildEmpresaCard(Map<String, dynamic> empresa, ThemePalette palette) {
    final tipoColor = empresa['tipo'] == 'Holding' ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6);
    
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
                empresa['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tipoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  empresa['tipo'],
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tipoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Estado', empresa['estado']),
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

  void _showAddEmpresaDialog() {
    final nombreController = TextEditingController();
    final tipoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Nueva Empresa', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de la empresa',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tipoController,
              decoration: InputDecoration(
                labelText: 'Tipo (Holding/Filial)',
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
                _empresas.add({
                  'id': DateTime.now().toString(),
                  'nombre': nombreController.text,
                  'tipo': tipoController.text,
                  'estado': 'Activo',
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
