import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PortalPilotApp());
}

class PortalPilotApp extends StatelessWidget {
  const PortalPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortalPilot + Cyberyx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0EA5E9),
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFFF59E0B),
          tertiary: Color(0xFF10B981),
          surface: Color(0xFF111827),
          background: Color(0xFF0A0E17),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
