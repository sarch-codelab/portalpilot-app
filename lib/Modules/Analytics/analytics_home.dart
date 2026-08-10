import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Analytics/dashboard_gerencial.dart';
import 'package:portal_pilot_app/Modules/Analytics/kpis_dashboard.dart';
import 'package:portal_pilot_app/Modules/Analytics/margenes_analisis.dart';
import 'package:portal_pilot_app/Modules/Analytics/forecasting_dashboard.dart';

class AnalyticsHome extends StatefulWidget {
  const AnalyticsHome({super.key});

  @override
  State<AnalyticsHome> createState() => _AnalyticsHomeState();
}

class _AnalyticsHomeState extends State<AnalyticsHome> {
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF6366F1), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text('ANALYTICS & BI', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF6366F1),
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
          _buildActionCard(
            Icons.dashboard_rounded,
            'Dashboard Gerencial',
            'Vista ejecutiva del negocio',
            const Color(0xFF6366F1),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardGerencial())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.assessment_rounded,
            'KPIs Dashboard',
            'Indicadores clave de rendimiento',
            const Color(0xFF10B981),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KPIsDashboard())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.trending_up_rounded,
            'Análisis de Márgenes',
            'Márgenes por canal y producto',
            const Color(0xFFF59E0B),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MargenesAnalisis())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.show_chart_rounded,
            'Forecasting',
            'Pronósticos y proyecciones',
            const Color(0xFFEC4899),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForecastingDashboard())),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: appThemeNotifier.isDark ? const Color(0xFF525252) : const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}