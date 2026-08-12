import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class ForecastingDashboard extends StatefulWidget {
  const ForecastingDashboard({super.key});

  @override
  State<ForecastingDashboard> createState() => _ForecastingDashboardState();
}

class _ForecastingDashboardState extends State<ForecastingDashboard> {
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
            color: Color(0xFFEC4899),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Forecasting',
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
              color: const Color(0xFFEC4899),
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
          _buildForecastCard(
            'Ventas Mensuales',
            'L.1,450,000',
            '+16.0%',
            const Color(0xFF10B981),
            Icons.trending_up_rounded,
          ),
          const SizedBox(height: 12),
          _buildForecastCard(
            'Inventario Requerido',
            'L.420,000',
            '+8.5%',
            const Color(0xFF6366F1),
            Icons.inventory_2_rounded,
          ),
          const SizedBox(height: 12),
          _buildForecastCard(
            'Demanda Estimada',
            '+12.3%',
            '+2.1%',
            const Color(0xFFF59E0B),
            Icons.people_rounded,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('PROYECCIONES POR CANAL'),
          const SizedBox(height: 12),
          _buildChannelForecast(
            'Canal Tradicional',
            'L.520,000',
            '+18.5%',
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _buildChannelForecast(
            'Canal Moderno',
            'L.720,000',
            '+14.2%',
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildChannelForecast(
            'Membresías',
            'L.210,000',
            '+25.0%',
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: appThemeNotifier.isDark
            ? const Color(0xFFA3A3A3)
            : const Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildForecastCard(
    String title,
    String forecast,
    String change,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
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
                  forecast,
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelForecast(
    String canal,
    String forecast,
    String growth,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            canal,
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                forecast,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    growth,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
