import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class CierresMensuales extends StatefulWidget {
  const CierresMensuales({super.key});

  @override
  State<CierresMensuales> createState() => _CierresMensualesState();
}

class _CierresMensualesState extends State<CierresMensuales> {
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
        title: Text('Cierres Mensuales', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMonthCard('Agosto 2026', true, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildMonthCard('Julio 2026', true, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildMonthCard('Junio 2026', true, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildMonthCard('Mayo 2026', true, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildMonthCard('Abril 2026', false, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildMonthCard(String mes, bool cerrado, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mes,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    cerrado ? Icons.check_circle_rounded : Icons.pending_rounded,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cerrado ? 'Cerrado' : 'En proceso',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              _showMonthDetails(mes);
            },
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: const Text('Ver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthDetails(String mes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        title: Text('Detalle: $mes', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: appThemeNotifier.isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Ingresos', 'L.1,250,000'),
            _buildDetailRow('Gastos', 'L.850,000'),
            _buildDetailRow('Ganancia Neta', 'L.400,000'),
            _buildDetailRow('ISV Pagado', 'L.187,500'),
            _buildDetailRow('ISR Retenido', 'L.62,500'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte generado'), backgroundColor: Color(0xFF10B981)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: Text('Generar Reporte', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w600,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}