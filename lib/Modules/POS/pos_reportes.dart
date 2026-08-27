import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PosReportes extends StatefulWidget {
  const PosReportes({super.key});

  @override
  State<PosReportes> createState() => _PosReportesState();
}

class _PosReportesState extends State<PosReportes> {
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() { _cargando = true; _error = null; });

    try {
      final api = ApiService.instance;
      final result = await api.get('/api/pos/ventas', queryParams: {'limit': '200'});

      if (result != null && api.isSuccess(result)) {
        final ventas = result['ventas'] ?? [];
        if (mounted) {
          setState(() {
            _ventas = List<Map<String, dynamic>>.from(
              (ventas is List) ? ventas.map((v) => Map<String, dynamic>.from(v)) : [],
            );
            _cargando = false;
          });
        }
      } else {
        // API failed — fall back to SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final ventasJson = prefs.getString('ventas_pos') ?? '[]';
          final ventasList = List<Map<String, dynamic>>.from(jsonDecode(ventasJson).map((v) => Map<String, dynamic>.from(v)));
          if (mounted) {
            setState(() {
              _ventas = ventasList;
              _cargando = false;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _error = 'Error cargando ventas';
              _cargando = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando reportes POS: $e');
      if (mounted) {
        setState(() {
          _error = 'Error de conexión';
          _cargando = false;
        });
      }
    }
  }

  double get _totalIngresos => _ventas.fold<double>(0, (s, v) => s + ((v['monto'] as num?)?.toDouble() ?? 0));

  double get _totalHoy {
    final hoy = DateTime.now();
    return _ventas.fold<double>(0, (s, v) {
      final f = DateTime.tryParse(v['fecha'] ?? v['created_at'] ?? '');
      if (f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
        return s + ((v['monto'] as num?)?.toDouble() ?? 0);
      }
      return s;
    });
  }

  double get _ticketPromedio => _ventas.isEmpty ? 0 : _totalIngresos / _ventas.length;

  Map<String, double> get _porMetodo {
    final map = <String, double>{};
    for (final v in _ventas) {
      final metodo = (v['metodo_pago'] ?? 'efectivo').toString();
      map[metodo] = (map[metodo] ?? 0) + ((v['monto'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }

  List<Map<String, dynamic>> get _ventasPorDia {
    final map = <String, double>{};
    for (var i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      map['${d.day}/${d.month}'] = 0.0;
    }
    for (final v in _ventas) {
      final f = DateTime.tryParse(v['fecha'] ?? v['created_at'] ?? '');
      if (f == null) continue;
      final diff = DateTime.now().difference(DateTime(f.year, f.month, f.day)).inDays;
      if (diff >= 0 && diff <= 6) {
        final key = '${f.day}/${f.month}';
        map[key] = (map[key] ?? 0) + ((v['monto'] as num?)?.toDouble() ?? 0);
      }
    }
    return map.entries.map((e) => {'dia': e.key, 'total': e.value}).toList();
  }

  @override
  Widget build(BuildContext context) {
    final porMetodo = _porMetodo;
    final maxMetodo = porMetodo.values.isEmpty ? 1.0 : porMetodo.values.reduce((a, b) => a > b ? a : b);
    final maxDia = _ventasPorDia.fold<double>(0, (m, d) => ((d['total'] as num?)?.toDouble() ?? 0) > m ? (d['total'] as num?)!.toDouble() : m);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF97316), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text('REPORTES POS', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFFF97316),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: const Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: GoogleFonts.dmSans(color: const Color(0xFFEF4444))),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildKpis(),
                      const SizedBox(height: 16),
                      _buildSection('VENTAS ÚLTIMOS 7 DÍAS'),
                      const SizedBox(height: 10),
                      _buildGraficoBarras(maxDia),
                      const SizedBox(height: 20),
                      _buildSection('MÉTODO DE PAGO'),
                      const SizedBox(height: 10),
                      if (porMetodo.isEmpty) _buildEmpty('Sin datos de método de pago') else _buildPorMetodo(porMetodo, maxMetodo),
                      const SizedBox(height: 30),
                    ],
                  ),
      ),
    );
  }

  Widget _buildKpis() {
    final wide = MediaQuery.of(context).size.width >= 600;
    return GridView.count(
      crossAxisCount: wide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: wide ? 2.6 : 1.5,
      children: [
        _buildKpi('Ventas Totales', '${_ventas.length}', Icons.receipt_long_rounded, const Color(0xFFF97316)),
        _buildKpi('Ingresos Hoy', 'L.${_formatNumber(_totalHoy)}', Icons.today_rounded, const Color(0xFF10B981)),
        _buildKpi('Ingresos Totales', 'L.${_formatNumber(_totalIngresos)}', Icons.attach_money_rounded, const Color(0xFF3B82F6)),
        _buildKpi('Ticket Promedio', 'L.${_formatNumber(_ticketPromedio)}', Icons.speed_rounded, const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _buildKpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(title, style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8));
  }

  Widget _buildGraficoBarras(double maxDia) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _ventasPorDia.map((d) {
          final total = (d['total'] as num?)?.toDouble() ?? 0;
          final altura = maxDia > 0 ? (total / maxDia) : 0.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total > 0 ? 'L.${_formatCompact(total)}' : '',
                style: GoogleFonts.dmMono(fontSize: 9, color: const Color(0xFF10B981)),
              ),
              const SizedBox(height: 4),
              Container(
                height: 80 * (altura.clamp(0.04, 1.0)),
                width: 22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [const Color(0xFFF97316), const Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(d['dia'].toString(), style: GoogleFonts.spaceGrotesk(fontSize: 10, color: const Color(0xFF737373))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPorMetodo(Map<String, double> porMetodo, double max) {
    const labels = {
      'efectivo': 'Efectivo',
      'tarjeta': 'Tarjeta',
      'transferencia': 'Transferencia',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: porMetodo.entries.map((e) {
          final pct = max > 0 ? e.value / max : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(labels[e.key] ?? e.key, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF262626),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('L.${_formatNumber(e.value)}', style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Center(
        child: Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373))),
      ),
    );
  }

  String _formatNumber(double n) => n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _formatCompact(double n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toStringAsFixed(0);
}
