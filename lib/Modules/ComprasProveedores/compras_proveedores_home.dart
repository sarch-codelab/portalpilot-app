import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/compras_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/orden_compra_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/proveedor_list.dart';
import 'package:portal_pilot_app/Shared/services/pp_module_navigator.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';

/// Pantalla principal del módulo de Compras y Proveedores
class ComprasProveedoresHome extends StatefulWidget {
  const ComprasProveedoresHome({super.key});

  @override
  State<ComprasProveedoresHome> createState() => _ComprasProveedoresHomeState();
}

class _ComprasProveedoresHomeState extends State<ComprasProveedoresHome> {
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
      moduleId: 'compras_proveedores',
      screenTitle: 'Compras y Proveedores',
      moduleIcon: Icons.shopping_cart_rounded,
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
            Icons.people_outline,
            'Proveedores',
            'Gestión de proveedores y contactos',
            const Color(0xFF14B8A6),
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProveedorList())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.inventory_2_outlined,
            'Ordenes de Compra',
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
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.storefront_outlined,
            'Modulo Comercial',
            'Cotizaciones y gestión comercial completa',
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