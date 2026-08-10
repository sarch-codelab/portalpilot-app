import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class InventarioTienda extends StatefulWidget {
  const InventarioTienda({super.key});

  @override
  State<InventarioTienda> createState() => _InventarioTiendaState();
}

class _InventarioTiendaState extends State<InventarioTienda> {
  List<Map<String, dynamic>> _tiendas = [
    {'id': '1', 'nombre': 'Pulpería Centro', 'tipo': 'tradicional', 'stock_total': 450},
    {'id': '2', 'nombre': 'Supermercado Norte', 'tipo': 'moderno', 'stock_total': 1200},
    {'id': '3', 'nombre': 'Pulpería Sur', 'tipo': 'tradicional', 'stock_total': 320},
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
        title: Text('Inventario por Tienda', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
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
        itemCount: _tiendas.length,
        itemBuilder: (context, index) {
          final tienda = _tiendas[index];
          return _buildTiendaCard(tienda, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddTiendaDialog();
        },
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Agregar Tienda', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildTiendaCard(Map<String, dynamic> tienda, ThemePalette palette) {
    final color = tienda['tipo'] == 'tradicional' ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
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
                tienda['nombre'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tienda['tipo'].toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
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
                'Stock Total',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                ),
              ),
              Text(
                '${tienda['stock_total']} unidades',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: tienda['stock_total'] / 1500,
            backgroundColor: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  void _showAddTiendaDialog() {
    final nombreController = TextEditingController();
    String tipoSeleccionado = 'tradicional';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          title: Text('Agregar Tienda', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la tienda',
                  labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                  border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tipoSeleccionado,
                items: const [
                  DropdownMenuItem(value: 'tradicional', child: Text('Canal Tradicional')),
                  DropdownMenuItem(value: 'moderno', child: Text('Canal Moderno')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tipoSeleccionado = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Tipo de canal',
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
                  _tiendas.add({
                    'id': DateTime.now().toString(),
                    'nombre': nombreController.text,
                    'tipo': tipoSeleccionado,
                    'stock_total': 0,
                  });
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              child: Text('Guardar', style: GoogleFonts.dmSans(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}