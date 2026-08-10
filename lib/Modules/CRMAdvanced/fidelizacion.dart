import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class Fidelizacion extends StatefulWidget {
  const Fidelizacion({super.key});

  @override
  State<Fidelizacion> createState() => _FidelizacionState();
}

class _FidelizacionState extends State<Fidelizacion> {
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFEC4899), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Fidelizacion Avanzada', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFEC4899),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.loyalty_rounded,
              size: 64,
              color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 16),
            Text(
              'Programas de Fidelizacion',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: appThemeNotifier.isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Funcionalidad en desarrollo',
              style: GoogleFonts.dmSans(
                color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
