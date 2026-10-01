import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/proveedor_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/cotizacion_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/orden_compra_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/compras_list.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';

class ComercialHome extends StatefulWidget {
  const ComercialHome({super.key});

  @override
  State<ComercialHome> createState() => _ComercialHomeState();
}

class _ComercialHomeState extends State<ComercialHome> {
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
      moduleId: 'comercial',
      screenTitle: 'Comercial',
      moduleIcon: Icons.storefront_rounded,
      moduleColor: appPalette.textMuted,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDashboardHeader(),
          const SizedBox(height: 18),
          _buildActionCard(
            Icons.people_outline,
            'Proveedores',
            'Gestión de proveedores y contactos',
            appPalette.textMuted,
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProveedorList())),
          ),
          const SizedBox(height: 12),
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
            Icons.inventory_2_outlined,
            'Órdenes de Compra',
            'Gestión de órdenes de compra',
            const Color(0xFF3B82F6),
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OrdenCompraList())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.shopping_cart_outlined,
            'Compras',
            'Registro de compras',
            const Color(0xFF10B981),
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ComprasList())),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    // Icono de marca PNG centrado sobre el título (mismo patrón que
    // Inventario/POS: primero la portada visual, luego el dashboard).
    final logoSize =
        (MediaQuery.sizeOf(context).shortestSide * 0.2).clamp(92.0, 128.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'img/Iconos/Comercial.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Comercial',
          style: GoogleFonts.syne(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Compras, proveedores, cotizaciones y órdenes',
          style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted),
        ),
      ],
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
