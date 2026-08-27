import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class KPIsDashboard extends StatefulWidget {
  const KPIsDashboard({super.key});

  @override
  State<KPIsDashboard> createState() => _KPIsDashboardState();
}

class _KPIsDashboardState extends State<KPIsDashboard> {
  Map<String, dynamic> _kpis = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (mounted) {
      setState(() => _cargando = true);
    }
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/dashboard/summary');
      if (api.isSuccess(result)) {
        if (mounted) {
          setState(() {
            _kpis = result['kpis'] ?? {};
            _cargando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _cargando = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
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
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF10B981),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'KPIs Dashboard',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF10B981),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _kpis.isEmpty
              ? Center(
                  child: Text(
                    'No hay datos disponibles',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildKPICard(
                      'Facturas Emitidas',
                      '${_kpis['facturasCount'] ?? 0}',
                      'Total: L.${(_kpis['facturasTotal'] ?? 0).toStringAsFixed(0)}',
                      const Color(0xFF10B981),
                      Icons.receipt_long_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      'Ingresos del Mes',
                      'L.${(_kpis['ingresoMes'] ?? 0).toStringAsFixed(0)}',
                      'Gastos: L.${(_kpis['gastoMes'] ?? 0).toStringAsFixed(0)}',
                      const Color(0xFF6366F1),
                      Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      'Balance del Mes',
                      'L.${(_kpis['balanceMes'] ?? 0).toStringAsFixed(0)}',
                      (_kpis['balanceMes'] ?? 0) >= 0 ? ' positivo' : ' negativo',
                      (_kpis['balanceMes'] ?? 0) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      Icons.account_balance_wallet_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      'Transacciones Hoy',
                      '${_kpis['transaccionesHoy'] ?? 0}',
                      'Hoy',
                      const Color(0xFFF59E0B),
                      Icons.point_of_sale_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      'Productos en Inventario',
                      '${_kpis['productosCount'] ?? 0}',
                      '${_kpis['lowStock'] ?? 0} con stock bajo',
                      const Color(0xFF8B5CF6),
                      Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      'Usuarios Activos',
                      '${_kpis['usuariosActivos'] ?? 0}',
                      'Cuenta activa',
                      const Color(0xFF14B8A6),
                      Icons.people_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildKPICard(
                      'Facturas Pendientes',
                      '${_kpis['facturasPendientes'] ?? 0}',
                      'Por cobrar',
                      const Color(0xFFEF4444),
                      Icons.pending_actions_rounded,
                    ),
                  ],
                ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    String change,
    Color color,
    IconData icon,
  ) {
    final isPositive = change.contains('+');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: appThemeNotifier.isDark
                        ? const Color(0xFFA3A3A3)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.syne(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: appThemeNotifier.isDark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
