import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Modules/CRMAdvanced/leads_opportunities.dart';
import 'package:portal_pilot_app/Modules/CRMAdvanced/campanas_marketing.dart';
import 'package:portal_pilot_app/Modules/CRMAdvanced/segmentacion.dart';
import 'package:portal_pilot_app/Modules/CRMAdvanced/fidelizacion.dart';

class CRMAdvancedHome extends StatefulWidget {
  const CRMAdvancedHome({super.key});

  @override
  State<CRMAdvancedHome> createState() => _CRMAdvancedHomeState();
}

class _CRMAdvancedHomeState extends State<CRMAdvancedHome> {
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
      moduleId: 'crm_advanced',
      screenTitle: 'CRM Avanzado',
      moduleIcon: Icons.groups_rounded,
      moduleColor: const Color(0xFF8B5CF6),
      actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF8B5CF6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActionCard(
            Icons.people_outline_rounded,
            'Leads y Oportunidades',
            'Gestión de prospectos y pipeline de ventas',
            const Color(0xFF8B5CF6),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LeadsOpportunities(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.campaign_rounded,
            'Campañas de Marketing',
            'Campañas, emails automatizados',
            const Color(0xFF10B981),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CampanasMarketing(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.group_work_rounded,
            'Segmentación',
            'Segmentación de clientes por criterios',
            const Color(0xFFF59E0B),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Segmentacion()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.loyalty_rounded,
            'Fidelización Avanzada',
            'Programas de lealtad y retención',
            const Color(0xFFEC4899),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Fidelizacion()),
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
