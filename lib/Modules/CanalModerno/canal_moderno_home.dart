import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/consolidado_screen.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/sucursal_screen.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/transferencia_screen.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/stock_consolidado.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/cadenas_franquicias.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/precios_centralizados.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/reportes_cadena.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_moderno_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

/// Hub del Canal Moderno: multi-sucursal, transferencias y consolidado.
class CanalModernoHome extends StatefulWidget {
  const CanalModernoHome({super.key});

  @override
  State<CanalModernoHome> createState() => _CanalModernoHomeState();
}

class _CanalModernoHomeState extends State<CanalModernoHome> {
  final _service = CanalModernoService.instance;

  int _sucursales = 0;
  int _enTransito = 0;
  double _valorInventario = 0.0;

  @override
  void initState() {
    super.initState();
    _cargar();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
    super.dispose();
  }

  Future<void> _cargar() async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final c = await _service.getConsolidado();
    if (!mounted) return;
    setState(() {
      _sucursales = c.totalSucursales;
      _enTransito = c.enTransito;
      _valorInventario = c.valorInventario;
    });
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
            color: Color(0xFFF97316),
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
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'CANAL MODERNO',
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
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFF3B82F6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildResumen(),
            const SizedBox(height: 16),
            Text(
              'GESTIÓN',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildAccion(
              Icons.storefront_rounded,
              'Sucursales',
              'Multi-sucursal: creá y gestioná puntos de venta',
              const Color(0xFF3B82F6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SucursalScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.swap_horiz_rounded,
              'Transferencias',
              'Traslados de inventario entre sucursales',
              const Color(0xFFF97316),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransferenciaScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.dashboard_rounded,
              'Consolidado',
              'Reporte agregado de toda la empresa',
              const Color(0xFF10B981),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConsolidadoScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.inventory_2_rounded,
              'Stock Consolidado',
              'Ver inventario total distribuido entre canales',
              const Color(0xFF8B5CF6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockConsolidado()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.business_rounded,
              'Cadenas y Franquicias',
              'Gestión de cadenas y franquicias',
              const Color(0xFFEC4899),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CadenasFranquicias()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.price_check_rounded,
              'Precios Centralizados',
              'Centralización de precios',
              const Color(0xFF6366F1),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PreciosCentralizados()),
              ),
            ),
            const SizedBox(height: 8),
            _buildAccion(
              Icons.bar_chart_rounded,
              'Reportes por Cadena',
              'Reportes consolidados por cadena',
              const Color(0xFF14B8A6),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportesCadena()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    return Row(
      children: [
        _buildResumenCard(
          'Sucursales',
          '$_sucursales',
          Icons.storefront_rounded,
          const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 10),
        _buildResumenCard(
          'En tránsito',
          '$_enTransito',
          Icons.local_shipping_rounded,
          const Color(0xFFF97316),
        ),
        const SizedBox(width: 10),
        _buildResumenCard(
          'Inventario',
          'L.${_format(_valorInventario)}',
          Icons.inventory_2_rounded,
          const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildResumenCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccion(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF737373),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  String _format(double v) => v.toStringAsFixed(0);
}
