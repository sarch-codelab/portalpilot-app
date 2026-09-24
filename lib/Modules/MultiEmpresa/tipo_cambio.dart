import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class TipoCambio extends StatefulWidget {
  const TipoCambio({super.key});

  @override
  State<TipoCambio> createState() => _TipoCambioState();
}

class _TipoCambioState extends State<TipoCambio> {
  final List<Map<String, dynamic>> _tasas = [
    {'moneda': 'USD', 'compra': 24.50, 'venta': 24.75, 'fecha': '2026-08-10'},
    {'moneda': 'EUR', 'compra': 26.80, 'venta': 27.10, 'fecha': '2026-08-10'},
  ];

  @override
  void initState() {
    super.initState();
    // No publicar tasas codificadas como si fueran cotizaciones vigentes.
    _tasas.clear();
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
            color: Color(0xFF10B981),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tipo de Cambio',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
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
        onPressed: null,
        backgroundColor: const Color(0xFF10B981),
        icon: Icon(Icons.add_rounded, color: appPalette.cardColor),
        label: Text(
          'Integración pendiente',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: appPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTasaCard(Map<String, dynamic> tasa, ThemePalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appPalette.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appPalette.borderLight,
        ),
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
                  color: appThemeNotifier.isDark ? appPalette.textPrimary : Colors.black,
                ),
              ),
              Text(
                tasa['fecha'],
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: appThemeNotifier.isDark
                      ? appPalette.textMuted
                      : appPalette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Compra',
                  'L.${tasa['compra'].toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow(
                  'Venta',
                  'L.${tasa['venta'].toStringAsFixed(2)}',
                ),
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
            color: appThemeNotifier.isDark
                ? appPalette.textMuted
                : appPalette.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appThemeNotifier.isDark ? appPalette.textPrimary : Colors.black,
          ),
        ),
      ],
    );
  }
}