import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/recepcion.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/devoluciones_proveedor.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/trazabilidad.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/lote_caducidad.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/multi_bodega.dart';

class SupplyChainHome extends StatefulWidget {
  const SupplyChainHome({super.key});

  @override
  State<SupplyChainHome> createState() => _SupplyChainHomeState();
}

class _SupplyChainHomeState extends State<SupplyChainHome> {
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
      moduleId: 'supply_chain',
      screenTitle: 'Supply Chain',
      moduleIcon: Icons.local_shipping_rounded,
      moduleColor: const Color(0xFF14B8A6),
      actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF14B8A6),
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
            Icons.inventory_rounded,
            'Recepción',
            'Recepción de mercancía de proveedores',
            const Color(0xFF14B8A6),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Recepcion()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.assignment_return_rounded,
            'Devoluciones a Proveedor',
            'Gestión de devoluciones y reembolsos',
            const Color(0xFFEF4444),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DevolucionesProveedor(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.qr_code_scanner_rounded,
            'Trazabilidad',
            'Seguimiento completo de productos',
            const Color(0xFF6366F1),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Trazabilidad()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.date_range_rounded,
            'Lote y Caducidad',
            'Control de lotes y fechas de vencimiento',
            const Color(0xFFF59E0B),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoteCaducidad()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.warehouse_rounded,
            'Multi-Bodega',
            'Gestión de múltiples almacenes',
            const Color(0xFF8B5CF6),
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MultiBodega()),
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
