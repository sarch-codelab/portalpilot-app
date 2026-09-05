import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Modules/MultiEmpresa/holding_filial.dart';
import 'package:portal_pilot_app/Modules/MultiEmpresa/consolidado_financiero.dart';
import 'package:portal_pilot_app/Modules/MultiEmpresa/tipo_cambio.dart';

class MultiEmpresaHome extends StatefulWidget {
  const MultiEmpresaHome({super.key});

  @override
  State<MultiEmpresaHome> createState() => _MultiEmpresaHomeState();
}

class _MultiEmpresaHomeState extends State<MultiEmpresaHome> {
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
      moduleId: 'multi_empresa',
      screenTitle: 'Multi-Empresa',
      moduleIcon: Icons.business_rounded,
      moduleColor: const Color(0xFFEC4899),
      actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFFEC4899),
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
            Icons.account_tree_rounded,
            'Holding y Filiales',
            'Gestión de empresas y subsidiarias',
            const Color(0xFFEC4899),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HoldingFilial()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.analytics_rounded,
            'Consolidado Financiero',
            'Reportes consolidados multi-empresa',
            const Color(0xFF8B5CF6),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConsolidadoFinanciero(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.currency_exchange_rounded,
            'Tipo de Cambio',
            'Conversión automática de monedas',
            const Color(0xFF10B981),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TipoCambio()),
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
