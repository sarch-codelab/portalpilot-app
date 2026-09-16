import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
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
  Widget build(BuildContext context) {    return PPModuleScaffold(
      moduleId: 'seguridad',
      screenTitle: 'Seguridad',
      moduleIcon: Icons.security_rounded,
      moduleColor: const Color(0xFF6366F1),
      child: ListView(
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
          color: appPalette.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appPalette.borderLight,
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
                          ? appPalette.textPrimary
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: appThemeNotifier.isDark
                          ? appPalette.textMuted
                          : appPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: appThemeNotifier.isDark
                  ? appPalette.bgTertiary
                  : appPalette.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
