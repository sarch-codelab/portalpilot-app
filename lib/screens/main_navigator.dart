import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/oculis_sidebar.dart';
import 'dashboard_screen.dart';
import 'automation_screen.dart';
import 'security_screen.dart';
import 'fleet_screen.dart';
import 'splash_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AutomationScreen(),
    const SecurityScreen(),
    const FleetScreen(),
  ];

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SplashScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0F),
      body: Stack(
        children: [
          // Fondo con estrellas y cometas (lo puedes añadir aquí o en cada pantalla)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomCenter,
                radius: 1.2,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.12),
                  const Color(0xFF3B82F6).withOpacity(0.05),
                  const Color(0xFF0A0B0F),
                  const Color(0xFF0A0B0F),
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          // Sidebar Oculis + Contenido
          Row(
            children: [
              // Sidebar reutilizable
              OculisSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),

              // Contenido principal
              Expanded(
                child: _screens[_selectedIndex],
              ),
            ],
          ),

          // Botón de logout flotante (opcional)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: () => _logout(context),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.logout, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
