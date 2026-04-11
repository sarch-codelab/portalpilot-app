import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final List<String> _titles = [
    'Dashboard',
    'Automation Studio',
    'Security & Forensics',
    'Fleet Management',
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
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: const Color(0xFF0F1118),
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Text(
                  'PORTALPILOT',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EA5E9)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tech Solutions',
                  style: TextStyle(fontSize: 11, color: Color(0xFF0EA5E9)),
                ),
                const SizedBox(height: 30),
                _buildNavItem(0, 'Dashboard', Icons.dashboard),
                _buildNavItem(1, 'Automation', Icons.account_tree),
                _buildNavItem(2, 'Security', Icons.shield),
                _buildNavItem(3, 'Fleet', Icons.business),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 8),
                          const Text('Empleado'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                size: 18, color: Colors.white54),
                            onPressed: () => _logout(context),
                            tooltip: 'Cerrar Sesión',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Plan: Enterprise',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: const Color(0xFF111827),
                  child: Row(
                    children: [
                      Text(
                        _titles[_selectedIndex],
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'SISTEMA OPERATIVO',
                          style:
                              TextStyle(fontSize: 10, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF0EA5E9) : Colors.white54),
      title: Text(title,
          style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
      tileColor: isSelected ? const Color(0xFF0EA5E9).withOpacity(0.1) : null,
      onTap: () => setState(() => _selectedIndex = index),
    );
  }
}
