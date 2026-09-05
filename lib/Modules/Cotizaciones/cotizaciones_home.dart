import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/cotizacion_list.dart';
import 'package:portal_pilot_app/Shared/services/pp_module_navigator.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';

/// Pantalla principal del módulo de Cotizaciones
class CotizacionesHome extends StatefulWidget {
  const CotizacionesHome({super.key});

  @override
  State<CotizacionesHome> createState() => _CotizacionesHomeState();
}

class _CotizacionesHomeState extends State<CotizacionesHome> {
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
    return PPModuleScaffold(
      moduleId: 'cotizaciones',
      screenTitle: 'Cotizaciones',
      moduleIcon: Icons.request_quote_rounded,
      moduleColor: const Color(0xFFF43F5E),
      actions: [
        IconButton(
          icon: Icon(
            appThemeNotifier.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: const Color(0xFFF43F5E),
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
            Icons.request_quote_outlined,
            'Cotizaciones',
            'Cotizaciones a clientes',
            const Color(0xFFF43F5E),
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CotizacionList())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.storefront_outlined,
            'Modulo Comercial',
            'Proveedores, ordenes de compra y compras',
            const Color(0xFF6B7280),
            () => PPModuleNavigator.pushById(context, 'comercial'),
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