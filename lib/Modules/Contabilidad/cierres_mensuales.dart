import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class CierresMensuales extends StatefulWidget {
  const CierresMensuales({super.key});

  @override
  State<CierresMensuales> createState() => _CierresMensualesState();
}

class _CierresMensualesState extends State<CierresMensuales> {
  List<dynamic> _transacciones = [];
  bool _cargando = true;
  Map<String, dynamic> _kpis = {};
  double _tasaISV = 0.15;
  double _tasaISR = 0.05;

  static const List<String> _nombresMeses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/dashboard/summary');
      if (api.isSuccess(result)) {
        _kpis = Map<String, dynamic>.from(result['kpis'] ?? {});
      }
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('transacciones') ?? '[]';
      _transacciones = jsonDecode(json) as List<dynamic>;
      _cargarTasasImpuestos(prefs);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  void _cargarTasasImpuestos(SharedPreferences prefs) {
    try {
      final json = prefs.getString('impuestos_config');
      if (json == null) return;
      final impuestos = jsonDecode(json) as List<dynamic>;
      for (final impuesto in impuestos) {
        if (impuesto is! Map) continue;
        final nombre = (impuesto['nombre'] ?? '').toString().toUpperCase();
        final tasa = (impuesto['tasa'] as num?)?.toDouble();
        if (tasa == null) continue;
        if (nombre.contains('ISV')) _tasaISV = tasa / 100;
        if (nombre.contains('ISR')) _tasaISR = tasa / 100;
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _generarMeses() {
    final ahora = DateTime.now();
    return List.generate(6, (i) {
      final fecha = DateTime(ahora.year, ahora.month - i);
      return {
        'fecha': fecha,
        'nombre': '${_nombresMeses[fecha.month - 1]} ${fecha.year}',
        'actual': i == 0,
      };
    });
  }

  Map<String, double> _calcularResumenMes(DateTime mes) {
    double ingresos = 0;
    double gastos = 0;
    for (final t in _transacciones) {
      if (t is! Map) continue;
      final fecha = DateTime.tryParse(t['fecha']?.toString() ?? '');
      if (fecha == null || fecha.year != mes.year || fecha.month != mes.month) {
        continue;
      }
      final monto = (t['monto'] as num?)?.toDouble() ?? 0.0;
      if ((t['tipo'] ?? '').toString().toLowerCase() == 'ingreso') {
        ingresos += monto;
      } else {
        gastos += monto;
      }
    }
    final ahora = DateTime.now();
    if (mes.year == ahora.year &&
        mes.month == ahora.month &&
        ingresos == 0 &&
        gastos == 0) {
      ingresos = (_kpis['ingresoMes'] as num?)?.toDouble() ?? 0.0;
      gastos = (_kpis['gastoMes'] as num?)?.toDouble() ?? 0.0;
    }
    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'ganancia': ingresos - gastos,
      'isv': ingresos * _tasaISV,
      'isr': ingresos * _tasaISR,
    };
  }

  String _formatoLempiras(double valor) {
    final negativo = valor < 0;
    final partes = valor.abs().toStringAsFixed(2).split('.');
    final enteros = partes[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'L.${negativo ? '-' : ''}$enteros.${partes[1]}';
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
            color: Color(0xFF8B5CF6),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cierres Mensuales',
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
              color: const Color(0xFF8B5CF6),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final mesInfo in _generarMeses()) ...[
                  _buildMonthCard(mesInfo),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _buildMonthCard(Map<String, dynamic> mesInfo) {
    final mes = mesInfo['nombre'] as String;
    final cerrado = !(mesInfo['actual'] as bool);
    final color = cerrado ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mes,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    cerrado
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cerrado ? 'Cerrado' : 'En proceso',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              _showMonthDetails(mesInfo);
            },
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: const Text('Ver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthDetails(Map<String, dynamic> mesInfo) {
    final mes = mesInfo['nombre'] as String;
    final resumen = _calcularResumenMes(mesInfo['fecha'] as DateTime);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appThemeNotifier.isDark
            ? const Color(0xFF111111)
            : Colors.white,
        title: Text(
          'Detalle: $mes',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: appThemeNotifier.isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(
              'Ingresos',
              _formatoLempiras(resumen['ingresos']!),
            ),
            _buildDetailRow('Gastos', _formatoLempiras(resumen['gastos']!)),
            _buildDetailRow(
              'Ganancia Neta',
              _formatoLempiras(resumen['ganancia']!),
            ),
            _buildDetailRow(
              'ISV Pagado (${(_tasaISV * 100).toStringAsFixed(1)}%)',
              _formatoLempiras(resumen['isv']!),
            ),
            _buildDetailRow(
              'ISR Retenido (${(_tasaISR * 100).toStringAsFixed(1)}%)',
              _formatoLempiras(resumen['isr']!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generarReporte(mes, resumen);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: Text(
              'Generar Reporte',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _generarReporte(String mes, Map<String, double> resumen) {
    final buffer = StringBuffer()
      ..writeln('=== CIERRE MENSUAL - $mes ===')
      ..writeln('Ingresos: ${_formatoLempiras(resumen['ingresos']!)}')
      ..writeln('Gastos: ${_formatoLempiras(resumen['gastos']!)}')
      ..writeln('Ganancia Neta: ${_formatoLempiras(resumen['ganancia']!)}')
      ..writeln('ISV Pagado: ${_formatoLempiras(resumen['isv']!)}')
      ..writeln('ISR Retenido: ${_formatoLempiras(resumen['isr']!)}');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reporte copiado al portapapeles'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: appThemeNotifier.isDark
                  ? const Color(0xFFA3A3A3)
                  : const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w600,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
