import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Modules/FiscalAdvanced/retenciones.dart';
import 'package:portal_pilot_app/Modules/FiscalAdvanced/libros_contables.dart';
import 'package:portal_pilot_app/Modules/FiscalAdvanced/facturacion_electronica.dart';

class FiscalAdvancedHome extends StatefulWidget {
  const FiscalAdvancedHome({super.key});

  @override
  State<FiscalAdvancedHome> createState() => _FiscalAdvancedHomeState();
}

class _FiscalAdvancedHomeState extends State<FiscalAdvancedHome> {
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
      moduleId: 'fiscal_advanced',
      screenTitle: 'Fiscal Avanzado',
      moduleIcon: Icons.gavel_rounded,
      moduleColor: const Color(0xFFDC2626),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActionCard(
            Icons.account_balance_wallet_rounded,
            'Retenciones',
            'Gestión de retenciones de impuestos (ISR, IVA)',
            const Color(0xFFDC2626),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Retenciones()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.menu_book_rounded,
            'Libros Contables',
            'Libros según normativa SAR Honduras',
            const Color(0xFF8B5CF6),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LibrosContables()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.receipt_long_rounded,
            'Facturación Electrónica',
            'Integración SAT - timbrado y XML',
            const Color(0xFF10B981),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FacturacionElectronica(),
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
