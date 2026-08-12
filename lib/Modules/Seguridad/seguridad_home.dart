import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Seguridad/roles_usuario.dart';
import 'package:portal_pilot_app/Modules/Seguridad/auditoria.dart';
import 'package:portal_pilot_app/Modules/Seguridad/configuracion_seguridad.dart';

class SeguridadHome extends StatefulWidget {
  const SeguridadHome({super.key});

  @override
  State<SeguridadHome> createState() => _SeguridadHomeState();
}

class _SeguridadHomeState extends State<SeguridadHome> {
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
            color: Color(0xFF6366F1),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.security_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'SEGURIDAD',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActionCard(
            Icons.admin_panel_settings_rounded,
            'Roles de Usuario',
            'Gestión granular de permisos por rol',
            const Color(0xFF6366F1),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RolesUsuario()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.history_rounded,
            'Auditoría',
            'Logs inmutables de acciones',
            const Color(0xFF10B981),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Auditoria()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.verified_user_rounded,
            'Configuración',
            '2FA, políticas de seguridad',
            const Color(0xFFF59E0B),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConfiguracionSeguridad(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark
              ? const Color(0xFF111111)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appThemeNotifier.isDark
                ? const Color(0xFF262626)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appThemeNotifier.isDark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: appThemeNotifier.isDark
                          ? const Color(0xFFA3A3A3)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: appThemeNotifier.isDark
                  ? const Color(0xFF525252)
                  : const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
