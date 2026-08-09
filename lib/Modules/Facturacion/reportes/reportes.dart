import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  List<Map<String, dynamic>> _facturas = [];
  String _periodoSeleccionado = 'Hoy';
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
    final prefs = await SharedPreferences.getInstance();
    final facturasJson = prefs.getString('facturas') ?? '[]';
    setState(() => _facturas = List<Map<String, dynamic>>.from(jsonDecode(facturasJson)));
  }

  List<Map<String, dynamic>> _facturasFiltradas() {
    final ahora = DateTime.now();
    DateTime inicio;
    DateTime fin = ahora.add(const Duration(days: 1));

    switch (_periodoSeleccionado) {
      case 'Hoy':
        inicio = DateTime(ahora.year, ahora.month, ahora.day);
        break;
      case 'Ayer':
        inicio = DateTime(ahora.year, ahora.month, ahora.day - 1);
        fin = DateTime(ahora.year, ahora.month, ahora.day);
        break;
      case 'Esta Semana':
        inicio = ahora.subtract(Duration(days: ahora.weekday - 1));
        inicio = DateTime(inicio.year, inicio.month, inicio.day);
        break;
      case 'Este Mes':
        inicio = DateTime(ahora.year, ahora.month, 1);
        break;
      case 'Últimos 30 Días':
        inicio = ahora.subtract(const Duration(days: 30));
        break;
      case 'Rango':
        inicio = _fechaInicio;
        fin = _fechaFin.add(const Duration(days: 1));
        break;
      default:
        inicio = DateTime(ahora.year, ahora.month, 1);
    }

    return _facturas.where((f) {
      final fecha = DateTime.tryParse(f['fecha'] ?? '');
      if (fecha == null) return false;
      return fecha.isAfter(inicio) && fecha.isBefore(fin);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _facturasFiltradas();
    final emitidas = filtradas.where((f) => f['estado'] == 'emitida').length;
    final anuladas = filtradas.where((f) => f['estado'] == 'anulada').length;
    final totalVentas = filtradas.fold(0.0, (sum, f) => sum + ((f['total'] as num?)?.toDouble() ?? 0.0));
    final totalIsv = filtradas.fold(0.0, (sum, f) {
      return sum + ((f['isv_15'] as num?)?.toDouble() ?? 0.0) + ((f['isv_18'] as num?)?.toDouble() ?? 0.0);
    });

    final Map<String, double> ventasPorCliente = {};
    for (final f in filtradas) {
      final cliente = f['cliente_nombre'] ?? 'Sin nombre';
      ventasPorCliente[cliente] = (ventasPorCliente[cliente] ?? 0) + ((f['total'] as num?)?.toDouble() ?? 0.0);
    }

    final sortedClientes = ventasPorCliente.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF10B981), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'REPORTES',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPeriodoSelector(),
          const SizedBox(height: 16),
          _buildStatsCards(emitidas, anuladas, totalVentas, totalIsv),
          const SizedBox(height: 20),
          _buildSectionTitle('Top Clientes'),
          const SizedBox(height: 10),
          if (sortedClientes.isEmpty)
            _buildEmptyCard()
          else
            ...sortedClientes.take(10).map((e) => _buildClienteRow(e.key, e.value, totalVentas)),
          const SizedBox(height: 20),
          _buildSectionTitle('Detalle ISV por Período'),
          const SizedBox(height: 10),
          _buildISVDetalle(filtradas),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPeriodoSelector() {
    final periodos = ['Hoy', 'Ayer', 'Esta Semana', 'Este Mes', 'Últimos 30 Días', 'Rango'];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: periodos.map((p) {
          final selected = _periodoSeleccionado == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _periodoSeleccionado = p);
                if (p == 'Rango') _seleccionarRango();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? const Color(0xFF10B981) : const Color(0xFF262626),
                  ),
                ),
                child: Text(
                  p,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? const Color(0xFF10B981) : const Color(0xFF737373),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _seleccionarRango() async {
    final inicio = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              surface: Color(0xFF1A1A1A),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A1A1A)),
          ),
          child: child!,
        );
      },
    );

    if (inicio != null && mounted) {
      final fin = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: inicio,
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF10B981),
                surface: Color(0xFF1A1A1A),
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A1A1A)),
            ),
            child: child!,
          );
        },
      );

      if (fin != null) {
        setState(() {
          _fechaInicio = inicio;
          _fechaFin = fin;
        });
      }
    }
  }

  Widget _buildStatsCards(int emitidas, int anuladas, double totalVentas, double totalIsv) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _buildMiniStat('Facturas', '$emitidas', const Color(0xFF10B981)),
        _buildMiniStat('Anuladas', '$anuladas', const Color(0xFFEF4444)),
        _buildMiniStat('Ventas', 'L.${totalVentas.toStringAsFixed(2)}', const Color(0xFF3B82F6)),
        _buildMiniStat('ISV Total', 'L.${totalIsv.toStringAsFixed(2)}', const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
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
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Center(
        child: Text(
          'No hay datos para este período',
          style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
        ),
      ),
    );
  }

  Widget _buildClienteRow(String nombre, double monto, double totalGeneral) {
    final porcentaje = totalGeneral > 0 ? (monto / totalGeneral * 100) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            child: Text(
              nombre[0].toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: porcentaje / 100,
                  backgroundColor: const Color(0xFF262626),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'L.${monto.toStringAsFixed(2)}',
                style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                '${porcentaje.toStringAsFixed(1)}%',
                style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildISVDetalle(List<Map<String, dynamic>> facturas) {
    final isv15 = facturas.fold(0.0, (sum, f) => sum + ((f['isv_15'] as num?)?.toDouble() ?? 0.0));
    final isv18 = facturas.fold(0.0, (sum, f) => sum + ((f['isv_18'] as num?)?.toDouble() ?? 0.0));
    final totalIsv = isv15 + isv18;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          _buildISVRow('ISV 15% (Bienes gravados)', isv15, totalIsv > 0 ? isv15 / totalIsv : 0, const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _buildISVRow('ISV 18% (Bebidas/Tabaco)', isv18, totalIsv > 0 ? isv18 / totalIsv : 0, const Color(0xFFF59E0B)),
          const Divider(color: Color(0xFF262626), height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ISV a declarar',
                style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              Text(
                'L.${totalIsv.toStringAsFixed(2)}',
                style: GoogleFonts.dmMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildISVRow(String label, double monto, double porcentaje, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3))),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: porcentaje,
                backgroundColor: const Color(0xFF262626),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'L.${monto.toStringAsFixed(2)}',
          style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
