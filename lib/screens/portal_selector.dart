import 'package:flutter/material.dart';
import 'login_portalpilot.dart';
import 'login_empresa.dart';

class PortalSelector extends StatelessWidget {
  const PortalSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF0A0B0F), Color(0xFF030408), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Título
                  const Text(
                    "PORTALPILOT",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Selecciona tu tipo de acceso",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 60),
                  
                  // Dos botones
                  if (isWide)
                    Row(
                      children: [
                        Expanded(child: _buildLoginCard(context)),
                        const SizedBox(width: 30),
                        Expanded(child: _buildEmpresaCard(context)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildLoginCard(context),
                        const SizedBox(height: 30),
                        _buildEmpresaCard(context),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return _buildCard(
      title: "LOGIN",
      subtitle: "PortalPilot",
      description: "Panel de Control Global para administradores del sistema.",
      icon: Icons.admin_panel_settings,
      gradientColors: const [Color(0xFF6366F1), Color(0xFF3B82F6)],
      buttonText: "ACCEDER AL PANEL GLOBAL",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPortalPilot()),
      ),
      features: const [
        "🌍 Ver todas las empresas",
        "📊 Dashboard global SaaS",
        "💰 Gestión de planes",
        "⚙️ Configuración del sistema",
      ],
    );
  }

  Widget _buildEmpresaCard(BuildContext context) {
    return _buildCard(
      title: "ACCESO CORPORATIVO",
      subtitle: "Portal de tu Empresa",
      description: "Acceso para empresas que contratan nuestro servicio.",
      icon: Icons.business_center,
      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      buttonText: "ACCEDER A MI EMPRESA",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginEmpresaScreen()),
      ),
      features: const [
        "🏢 Tu empresa, tus datos",
        "📈 Automatización y auditoría",
        "👥 Gestión de empleados",
        "📊 Reportes exclusivos",
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required List<Color> gradientColors,
    required String buttonText,
    required VoidCallback onTap,
    required List<String> features,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gradientColors.first.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: gradientColors.first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: features.map((feature) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: gradientColors.first.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: gradientColors.first.withOpacity(0.3)),
                    ),
                    child: Text(
                      feature,
                      style: TextStyle(fontSize: 10, color: gradientColors.first),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gradientColors.first,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}