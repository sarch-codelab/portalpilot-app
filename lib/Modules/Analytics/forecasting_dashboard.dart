import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class ForecastingDashboard extends StatefulWidget {
  const ForecastingDashboard({super.key});

  @override
  State<ForecastingDashboard> createState() => _ForecastingDashboardState();
}

class _ForecastingDashboardState extends State<ForecastingDashboard> {
  Map<String, dynamic> _kpis = {};
  List<dynamic> _usage7d = [];
  List<dynamic> _gastosCategoria = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/dashboard/summary');
      if (api.isSuccess(result)) {
        if (mounted) {
          setState(() {
            _kpis = result['kpis'] ?? {};
            _usage7d = result['usage7d'] ?? [];
            _gastosCategoria = result['gastosCategoria'] ?? [];
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
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
            color: Color(0xFFEC4899),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Forecasting',
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
              color: const Color(0xFFEC4899),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)))
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
                    _buildForecastCard(
                      'Ingresos del Mes',
                      'L.${(_kpis['ingresoMes'] ?? 0).toStringAsFixed(0)}',
                      'Gastos: L.${(_kpis['gastoMes'] ?? 0).toStringAsFixed(0)}',
                      const Color(0xFF10B981),
                      Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildForecastCard(
                      'Inventario',
                      '${_kpis['productosCount'] ?? 0} productos',
                      '${_kpis['lowStock'] ?? 0} con stock bajo',
                      const Color(0xFF6366F1),
                      Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildForecastCard(
                      'Transacciones Hoy',
                      '${_kpis['transaccionesHoy'] ?? 0}',
                      'Movimientos del día',
                      const Color(0xFFF59E0B),
                      Icons.receipt_long_rounded,
                    ),
                    if (_gastosCategoria.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('GASTOS POR CATEGORÍA'),
                      const SizedBox(height: 12),
                      ...(_gastosCategoria.take(4).map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildChannelForecast(
                          g['categoria'] ?? 'Otro',
                          'L.${(g['monto'] ?? 0).toStringAsFixed(0)}',
                          '',
                          const Color(0xFFF59E0B),
                        ),
                      ))),
                    ],
                    if (_usage7d.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('ACTIVIDAD ÚLTIMOS 7 DÍAS'),
                      const SizedBox(height: 12),
                      ...(_usage7d.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildChannelForecast(
                          d['label'] ?? '',
                          '${d['facturas'] ?? 0} facturas',
                          '${d['transacciones'] ?? 0} transacciones',
                          const Color(0xFF10B981),
                        ),
                      ))),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: appThemeNotifier.isDark
            ? const Color(0xFFA3A3A3)
            : const Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildForecastCard(
    String title,
    String forecast,
    String change,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
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
                  forecast,
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelForecast(
    String canal,
    String forecast,
    String growth,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            canal,
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                forecast,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    growth,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
