import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class TipoCambio extends StatefulWidget {
  const TipoCambio({super.key});

  @override
  State<TipoCambio> createState() => _TipoCambioState();
}

class _TipoCambioState extends State<TipoCambio> {
  List<Map<String, dynamic>> _tasas = [
    {'moneda': 'USD', 'compra': 24.50, 'venta': 24.75, 'fecha': '2026-08-10'},
    {'moneda': 'EUR', 'compra': 26.80, 'venta': 27.10, 'fecha': '2026-08-10'},
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
        title: Text('Tipo de Cambio', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
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
        itemCount: _tasas.length,
        itemBuilder: (context, index) {
          final tasa = _tasas[index];
          return _buildTasaCard(tasa, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTasaDialog(),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nueva Tasa', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildTasaCard(Map<String, dynamic> tasa, ThemePalette palette) {
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
                tasa['moneda'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                tasa['fecha'],
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Compra', 'L.${tasa['compra'].toStringAsFixed(2)}'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow('Venta', 'L.${tasa['venta'].toStringAsFixed(2)}'),
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

  void _showAddTasaDialog() {
    final monedaController = TextEditingController();
    final compraController = TextEditingController();
    final ventaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Nueva Tasa', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: monedaController,
              decoration: InputDecoration(
                labelText: 'Moneda (USD/EUR)',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: compraController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tasa Compra (L.)',
                labelStyle: TextStyle(color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280)),
                border: OutlineInputBorder(borderSide: BorderSide(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ventaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tasa Venta (L.)',
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
                _tasas.add({
                  'moneda': monedaController.text,
                  'compra': double.tryParse(compraController.text) ?? 0.0,
                  'venta': double.tryParse(ventaController.text) ?? 0.0,
                  'fecha': DateTime.now().toString().substring(0, 10),
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
