import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PortalPilotApp());
}

class PortalPilotApp extends StatelessWidget {
  const PortalPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortalPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0B0F),
      ),
      home: const SplashScreen(),
    );
  }
}
