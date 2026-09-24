import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class Trazabilidad extends StatefulWidget {
  const Trazabilidad({super.key});

  @override
  State<Trazabilidad> createState() => _TrazabilidadState();
}

class _TrazabilidadState extends State<Trazabilidad> {
  final List<Map<String, dynamic>> _movimientos = [
    {
      'id': '1',
      'producto': 'Arroz Premium 5kg',
      'origen': 'Bodega Central',
      'destino': 'Tienda Norte',
      'fecha': '2026-08-10',
      'estado': 'Entregado',
    },
    {
      'id': '2',
      'producto': 'Aceite Vegetal 1L',
      'origen': 'Proveedor',
      'destino': 'Bodega Central',
      'fecha': '2026-08-09',
      'estado': 'En Transito',
    },
    {
      'id': '3',
      'producto': 'Leche Entera 1L',
      'origen': 'Bodega Central',
      'destino': 'Tienda Centro',
      'fecha': '2026-08-08',
      'estado': 'Entregado',
    },
  ];

  @override
  void initState() {
    super.initState();
    // No se muestran datos de ejemplo en producción. Esta pantalla se
    // habilitará al conectarla al backend de trazabilidad.
    _movimientos.clear();
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
            color: Color(0xFF14B8A6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trazabilidad de Productos',
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
        itemCount: _movimientos.length,
        itemBuilder: (context, index) {
          final movimiento = _movimientos[index];
          return _buildMovimientoCard(movimiento, palette);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: const Color(0xFF14B8A6),
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

  Widget _buildMovimientoCard(
    Map<String, dynamic> movimiento,
    ThemePalette palette,
  ) {
    final estadoColor = movimiento['estado'] == 'Entregado'
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

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
                movimiento['producto'],
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? appPalette.textPrimary : Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  movimiento['estado'],
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
              Expanded(child: _buildInfoRow('Origen', movimiento['origen'])),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoRow('Destino', movimiento['destino'])),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Fecha', movimiento['fecha']),
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
