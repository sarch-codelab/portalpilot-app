import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class FacturacionElectronica extends StatefulWidget {
  const FacturacionElectronica({super.key});

  @override
  State<FacturacionElectronica> createState() => _FacturacionElectronicaState();
}

class _FacturacionElectronicaState extends State<FacturacionElectronica> {
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
          'Facturación Electrónica',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: appPalette.borderLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Integración SAT',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: appThemeNotifier.isDark ? appPalette.textPrimary : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Timbrado y generación XML',
              style: GoogleFonts.dmSans(
                color: appThemeNotifier.isDark
                    ? appPalette.textMuted
                    : appPalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
