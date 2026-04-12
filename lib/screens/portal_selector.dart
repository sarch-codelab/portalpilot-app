import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
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
            radius: 1.5,
            colors: [
              Color(0xFF0A0B0F),
              Color(0xFF0F1118),
              Color(0xFF05080F),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.auto_awesome,
                            size: 40, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInDown(
                    delay: const Duration(milliseconds: 100),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                      ).createShader(bounds),
                      child: Text(
                        'PORTALPILOT',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Selecciona tu tipo de acceso',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FadeInLeft(
                            delay: const Duration(milliseconds: 300),
                            child: _buildPortalCard(
                              title: 'LOGIN',
                              subtitle: 'PortalPilot',
                              description:
                                  'Panel de Control Global para administradores del sistema.',
                              icon: Icons.admin_panel_settings,
                              gradientColors: const [
                                Color(0xFF6366F1),
                                Color(0xFF3B82F6)
                              ],
                              buttonText: 'ACCEDER AL PANEL GLOBAL',
                              onTap: () => _navigateTo(
                                  context, const LoginPortalPilot()),
                              features: const [
                                '🌍 Ver todas las empresas',
                                '📊 Dashboard global SaaS',
                                '💰 Gestión de planes',
                                '⚙️ Configuración del sistema',
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                        Expanded(
                          child: FadeInRight(
                            delay: const Duration(milliseconds: 400),
                            child: _buildPortalCard(
                              title: 'ACCESO CORPORATIVO',
                              subtitle: 'Portal de tu Empresa',
                              description:
                                  'Acceso para empresas que contratan nuestro servicio.',
                              icon: Icons.business_center,
                              gradientColors: const [
                                Color(0xFF8B5CF6),
                                Color(0xFF6D28D9)
                              ],
                              buttonText: 'ACCEDER A MI EMPRESA',
                              onTap: () => _navigateTo(
                                  context, const LoginEmpresaScreen()),
                              features: const [
                                '🏢 Tu empresa, tus datos',
                                '📈 Automatización y auditoría',
                                '👥 Gestión de empleados',
                                '📊 Reportes exclusivos',
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        FadeInUp(
                          delay: const Duration(milliseconds: 300),
                          child: _buildPortalCard(
                            title: 'LOGIN',
                            subtitle: 'PortalPilot',
                            description:
                                'Panel de Control Global para administradores del sistema.',
                            icon: Icons.admin_panel_settings,
                            gradientColors: const [
                              Color(0xFF6366F1),
                              Color(0xFF3B82F6)
                            ],
                            buttonText: 'ACCEDER AL PANEL GLOBAL',
                            onTap: () =>
                                _navigateTo(context, const LoginPortalPilot()),
                            features: const [
                              '🌍 Ver todas las empresas',
                              '📊 Dashboard global SaaS',
                              '💰 Gestión de planes',
                              '⚙️ Configuración del sistema',
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        FadeInUp(
                          delay: const Duration(milliseconds: 450),
                          child: _buildPortalCard(
                            title: 'ACCESO CORPORATIVO',
                            subtitle: 'Portal de tu Empresa',
                            description:
                                'Acceso para empresas que contratan nuestro servicio.',
                            icon: Icons.business_center,
                            gradientColors: const [
                              Color(0xFF8B5CF6),
                              Color(0xFF6D28D9)
                            ],
                            buttonText: 'ACCEDER A MI EMPRESA',
                            onTap: () => _navigateTo(
                                context, const LoginEmpresaScreen()),
                            features: const [
                              '🏢 Tu empresa, tus datos',
                              '📈 Automatización y auditoría',
                              '👥 Gestión de empleados',
                              '📊 Reportes exclusivos',
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 60),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: Text(
                      'SaaS Enterprise - Software como Servicio',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white24,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortalCard({
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
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
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
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
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
                Divider(color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: features
                      .map((feature) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: gradientColors.first.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: gradientColors.first.withOpacity(0.3)),
                            ),
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: gradientColors.first,
                              ),
                            ),
                          ))
                      .toList(),
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

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
