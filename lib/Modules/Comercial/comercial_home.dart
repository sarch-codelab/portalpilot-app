import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/Comercial/proveedor_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/cotizacion_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/orden_compra_list.dart';
import 'package:portal_pilot_app/Modules/Comercial/compras_list.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class ComercialHome extends StatefulWidget {
  const ComercialHome({super.key});

  @override
  State<ComercialHome> createState() => _ComercialHomeState();
}

class _ComercialHomeState extends State<ComercialHome> {
  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF6B7280), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF4B5563)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text('COMERCIAL', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF6B7280),
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
            Icons.people_outline,
            'Proveedores',
            'Gestión de proveedores y contactos',
            const Color(0xFF6B7280),
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProveedorList())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.request_quote_outlined,
            'Cotizaciones',
            'Cotizaciones a clientes',
            const Color(0xFFF43F5E),
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CotizacionList())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.inventory_2_outlined,
            'Órdenes de Compra',
            'Gestión de órdenes de compra',
            const Color(0xFF3B82F6),
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdenCompraList())),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.shopping_cart_outlined,
            'Compras',
            'Registro de compras',
            const Color(0xFF10B981),
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComprasList())),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
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
                      color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: appThemeNotifier.isDark ? const Color(0xFF525252) : const Color(0xFF9CA3AF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
