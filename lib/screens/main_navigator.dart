import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/oculis_sidebar.dart';
import 'dashboard_screen.dart';
import 'automation_screen.dart';
import 'security_screen.dart';
import 'fleet_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  
  String _userName = "Usuario";
  String _userEmail = "";
  String _empresaNombre = "Mi Empresa";
  String _empresaPlan = "Pro";

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AutomationScreen(),
    const SecurityScreen(),
    const FleetScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _userName = prefs.getString('userName') ?? 'Usuario';
          _userEmail = prefs.getString('userEmail') ?? '';
          _empresaNombre = prefs.getString('empresaNombre') ?? 'Mi Empresa';
          _empresaPlan = prefs.getString('empresaPlan') ?? 'Pro';
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0F),
      body: Row(
        children: [
          OculisSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            userName: _userName,
            userEmail: _userEmail,
            empresaNombre: _empresaNombre,
            empresaPlan: _empresaPlan,
          ),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}