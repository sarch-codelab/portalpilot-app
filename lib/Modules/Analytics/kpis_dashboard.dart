import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class KPIsDashboard extends StatefulWidget {
  const KPIsDashboard({super.key});

  @override
  State<KPIsDashboard> createState() => _KPIsDashboardState();
}

class _KPIsDashboardState extends State<KPIsDashboard> {
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
            color: Color(0xFF10B981),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'KPIs Dashboard',
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
              color: const Color(0xFF10B981),
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
          _buildKPICard(
            'Ventas Totales',
            'L.1,250,000',
            '+15.3%',
            const Color(0xFF10B981),
            Icons.trending_up_rounded,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'MÃ¡rgenes',
            '15.0%',
            '+2.1%',
            const Color(0xFF6366F1),
            Icons.percent_rounded,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'Ticket Promedio',
            'L.148',
            '+8.5%',
            const Color(0xFFF59E0B),
            Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'SatisfacciÃ³n Cliente',
            '92%',
            '+3.2%',
            const Color(0xFFEC4899),
            Icons.sentiment_satisfied_rounded,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'RotaciÃ³n Inventario',
            '4.2x',
            '+0.8x',
            const Color(0xFF8B5CF6),
            Icons.sync_rounded,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'RetenciÃ³n Clientes',
            '78%',
            '+5.4%',
            const Color(0xFF14B8A6),
            Icons.people_rounded,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            'Costo Operativo',
            'L.850,000',
            '-3.2%',
            const Color(0xFFEF4444),
            Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    String change,
    Color color,
    IconData icon,
  ) {
    final isPositive = change.contains('+');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: appThemeNotifier.isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.syne(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: appThemeNotifier.isDark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
