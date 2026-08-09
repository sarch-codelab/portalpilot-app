import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reportes del POS: KPIs, ventas por método de pago, top productos
/// y ventas de los últimos 7 días. Datos reales de `ventas_pos`.
class PosReportes extends StatefulWidget {
  const PosReportes({super.key});

  @override
  State<PosReportes> createState() => _PosReportesState();
}

class _PosReportesState extends State<PosReportes> {
  List<Map<String, dynamic>> _ventas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final ventasJson = prefs.getString('ventas_pos') ?? '[]';
    final List<dynamic> ventas = jsonDecode(ventasJson);
    if (mounted) {
      setState(() => _ventas = List<Map<String, dynamic>>.from(ventas));
    }
  }

  double get _totalIngresos => _ventas.fold<double>(0, (s, v) => s + ((v['total'] as num?)?.toDouble() ?? 0));

  double get _totalHoy {
    final hoy = DateTime.now();
    return _ventas.fold<double>(0, (s, v) {
      final f = DateTime.tryParse(v['fecha'] ?? '');
      if (f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
        return s + ((v['total'] as num?)?.toDouble() ?? 0);
      }
      return s;
    });
  }

  double get _ticketPromedio => _ventas.isEmpty ? 0 : _totalIngresos / _ventas.length;

  Map<String, double> get _porMetodo {
    final map = <String, double>{};
    for (final v in _ventas) {
      final metodo = (v['metodo_pago'] ?? 'efectivo').toString();
      map[metodo] = (map[metodo] ?? 0) + ((v['total'] as num?)?.toDouble() ?? 0);
    }
    return map;
  }

  Map<String, int> get _topProductos {
    final map = <String, int>{};
    for (final v in _ventas) {
      final items = List<Map<String, dynamic>>.from(v['items'] ?? []);
      for (final item in items) {
        final nombre = (item['nombre'] ?? 'Producto').toString();
        map[nombre] = (map[nombre] ?? 0) + ((item['cantidad'] as num?)?.toInt() ?? 1);
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted.take(5)) e.key: e.value};
  }

  List<Map<String, dynamic>> get _ventasPorDia {
    final map = <String, double>{};
    for (var i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      map['${d.day}/${d.month}'] = 0.0;
    }
    for (final v in _ventas) {
      final f = DateTime.tryParse(v['fecha'] ?? '');
      if (f == null) continue;
      final diff = DateTime.now().difference(DateTime(f.year, f.month, f.day)).inDays;
      if (diff >= 0 && diff <= 6) {
        final key = '${f.day}/${f.month}';
        map[key] = (map[key] ?? 0) + ((v['total'] as num?)?.toDouble() ?? 0);
      }
    }
    return map.entries.map((e) => {'dia': e.key, 'total': e.value}).toList();
  }

  @override
  Widget build(BuildContext context) {
    final top = _topProductos;
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildKpis(),
            const SizedBox(height: 16),
            _buildSection('VENTAS ÚLTIMOS 7 DÍAS'),
            const SizedBox(height: 10),
            _buildGraficoBarras(maxDia),
            const SizedBox(height: 20),
            _buildSection('TOP PRODUCTOS'),
            const SizedBox(height: 10),
            if (top.isEmpty) _buildEmpty('Aún no hay ventas registradas') else _buildTopProductos(top),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
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

  Widget _buildTopProductos(Map<String, int> top) {
    final max = top.values.isEmpty ? 1 : top.values.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: top.entries.map((e) {
          final pct = e.value / max;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(e.key, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF262626),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${e.value}', style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFF97316))),
              ],
            ),
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
