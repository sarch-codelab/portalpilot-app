import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class MargenesAnalisis extends StatefulWidget {
  const MargenesAnalisis({super.key});

  @override
  State<MargenesAnalisis> createState() => _MargenesAnalisisState();
}

class _MargenesAnalisisState extends State<MargenesAnalisis> {
  List<dynamic> _productos = [];
  List<dynamic> _compras = [];
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
      final prodResult = await api.get('/api/productos');
      final compResult = await api.get('/api/compras');
      if (mounted) {
        setState(() {
          _productos = api.isSuccess(prodResult) ? (prodResult['productos'] ?? []) : [];
          _compras = api.isSuccess(compResult) ? (compResult['compras'] ?? []) : [];
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  double _calcularMargen(dynamic producto) {
    final precio = (producto['precio_venta'] ?? 0).toDouble();
    final costo = (producto['costo'] ?? 0).toDouble();
    if (costo <= 0 || precio <= 0) return 0.0;
    return ((precio - costo) / precio * 100);
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
            color: Color(0xFFF59E0B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Análisis de Márgenes',
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
              color: const Color(0xFFF59E0B),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('MÁRGENES POR PRODUCTO'),
                const SizedBox(height: 12),
                if (_productos.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No hay productos registrados',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                      ),
                    ),
                  )
                else
                  ...(_productos.take(10).toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final margen = _calcularMargen(p);
                    final colors = [
                      const Color(0xFF6366F1), const Color(0xFF10B981), const Color(0xFFF59E0B),
                      const Color(0xFFEC4899), const Color(0xFF8B5CF6), const Color(0xFF14B8A6),
                    ];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProductMargin(
                        p['nombre'] ?? 'Sin nombre',
                        margen,
                        colors[idx % colors.length],
                      ),
                    );
                  })),
                const SizedBox(height: 24),
                _buildSectionHeader('RESUMEN DE COMPRAS'),
                const SizedBox(height: 12),
                if (_compras.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No hay compras registradas',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                      ),
                    ),
                  )
                else
                  ...(_compras.take(5).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['proveedor_nombre'] ?? 'Sin proveedor',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14, fontWeight: FontWeight.w600,
                                    color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  'Estado: ${c['estado'] ?? 'N/A'}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'L.${(c['total'] ?? 0).toStringAsFixed(0)}',
                            style: GoogleFonts.syne(
                              fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))),
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

  Widget _buildProductMargin(String producto, double margen, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appThemeNotifier.isDark
              ? const Color(0xFF262626)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            producto,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          Row(
            children: [
              Container(
                width: 100,
                height: 6,
                decoration: BoxDecoration(
                  color: appThemeNotifier.isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: margen / 25,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${margen.toStringAsFixed(1)}%',
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
