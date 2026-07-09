import 'package:flutter/material.dart';
import 'package:portal_pilot_app/DB/db.dart';
import 'package:portal_pilot_app/launch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase usando la configuración del backend (/api/config)
  // Si falla, la app mostrará el splash igual, pero es recomendable manejar el error.
  try {
    await PortalPilotDB.initialize();
    print('✅ Supabase inicializado correctamente');
  } catch (e) {
    print('❌ Error al inicializar Supabase: $e');
  }

  runApp(const PortalPilotApp());
}

class PortalPilotApp extends StatelessWidget {
  const PortalPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Portal Pilot',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF8B5CF6),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SplashScreen(),
    );
  }
}