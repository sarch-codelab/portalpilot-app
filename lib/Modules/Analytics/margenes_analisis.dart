import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class MargenesAnalisis extends StatefulWidget {
  const MargenesAnalisis({super.key});

  @override
  State<MargenesAnalisis> createState() => _MargenesAnalisisState();
}

class _MargenesAnalisisState extends State<MargenesAnalisis> {
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Análisis de Márgenes', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFF59E0B),
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
          _buildSectionHeader('MÁRGENES POR CANAL'),
          const SizedBox(height: 12),
          _buildMarginCard('Canal Tradicional', 12.5, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildMarginCard('Canal Moderno', 15.2, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildMarginCard('Membresías', 18.7, const Color(0xFF8B5CF6)),
          const SizedBox(height: 24),
          _buildSectionHeader('MÁRGENES POR PRODUCTO'),
          const SizedBox(height: 12),
          _buildProductMargin('Arroz Premium 5kg', 15.0, const Color(0xFF6366F1)),
          const SizedBox(height: 12),
          _buildProductMargin('Frijol Negro 1kg', 18.5, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildProductMargin('Azúcar 5kg', 12.0, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildProductMargin('Aceite 1L', 22.0, const Color(0xFFEC4899)),
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
        color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildMarginCard(String canal, double margen, Color color) {
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
                canal,
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Margen promedio',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${margen.toStringAsFixed(1)}%',
              style: GoogleFonts.syne(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductMargin(String producto, double margen, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            producto,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          Row(
            children: [
              Container(
                width: 100,
                height: 6,
                decoration: BoxDecoration(
                  color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: margen / 25,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${margen.toStringAsFixed(1)}%',
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}