import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historial de ventas del POS, persistido en SharedPreferences (clave `ventas_pos`).
class PosHistorial extends StatefulWidget {
  const PosHistorial({super.key});

  @override
  State<PosHistorial> createState() => _PosHistorialState();
}

class _PosHistorialState extends State<PosHistorial> {
  List<Map<String, dynamic>> _ventas = [];
  String _filtro = 'Todas';

  static const Map<String, String> _filtros = {
    'Todas': 'all',
    'Hoy': 'hoy',
    'Esta Semana': 'semana',
    'Este Mes': 'mes',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final ventasJson = prefs.getString('ventas_pos') ?? '[]';
    final List<dynamic> ventas = jsonDecode(ventasJson);
    ventas.sort((a, b) => (b['fecha'] ?? '').toString().compareTo(a['fecha'] ?? ''));
    if (mounted) {
      setState(() => _ventas = List<Map<String, dynamic>>.from(ventas));
    }
  }

  List<Map<String, dynamic>> get _filtradas {
    final key = _filtros[_filtro] ?? 'all';
    final ahora = DateTime.now();
    return _ventas.where((v) {
      final fecha = DateTime.tryParse(v['fecha'] ?? '');
      if (fecha == null) return true;
      switch (key) {
        case 'hoy':
          return fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day;
        case 'semana':
          final diff = ahora.difference(fecha).inDays;
          return diff >= 0 && diff <= 7;
        case 'mes':
          return fecha.year == ahora.year && fecha.month == ahora.month;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _eliminarVenta(int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar venta', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text('¿Eliminar este registro de venta? Esta acción no se puede deshacer.', style: GoogleFonts.dmSans(color: const Color(0xFFA3A3A3))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: GoogleFonts.dmSans(color: const Color(0xFF737373)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Eliminar', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmar != true) return;

    final venta = _filtradas[index];
    final prefs = await SharedPreferences.getInstance();
    final lista = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('ventas_pos') ?? '[]'));
    lista.removeWhere((v) => v['fecha'] == venta['fecha'] && v['total'] == venta['total']);
    await prefs.setString('ventas_pos', jsonEncode(lista));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;
    final total = filtradas.fold<double>(0, (s, v) => s + ((v['total'] as num?)?.toDouble() ?? 0));
    final items = filtradas.fold<int>(0, (s, v) => s + ((v['cantidad_items'] as num?)?.toInt() ?? 0));

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
              child: const Icon(Icons.history_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text('HISTORIAL POS', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
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
            _buildSummary(total, items, filtradas.length),
            const SizedBox(height: 16),
            _buildFiltros(),
            const SizedBox(height: 12),
            if (filtradas.isEmpty)
              _buildVacio()
            else
              ...filtradas.map((v) => _buildVentaCard(v, filtradas.indexOf(v))),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(double total, int items, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF97316).withValues(alpha: 0.12), const Color(0xFFEA580C).withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildItem('Ventas', '$count', const Color(0xFFF97316)),
          _buildItem('Items', '$items', const Color(0xFF3B82F6)),
          _buildItem('Total', 'L.${_formatNumber(total)}', const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
      ],
    );
  }

  Widget _buildFiltros() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filtros.keys.map((f) {
          final selected = _filtro == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filtro = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFF97316).withValues(alpha: 0.15) : const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? const Color(0xFFF97316) : const Color(0xFF262626)),
                ),
                child: Text(f, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? const Color(0xFFF97316) : const Color(0xFF737373))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVentaCard(Map<String, dynamic> v, int index) {
    final fecha = DateTime.tryParse(v['fecha'] ?? '');
    final total = (v['total'] as num?)?.toDouble() ?? 0;
    final items = (v['cantidad_items'] as num?)?.toInt() ?? 0;
    final metodo = v['metodo_pago'] ?? 'efectivo';
    final detalles = List<Map<String, dynamic>>.from(v['items'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.receipt_rounded, color: Color(0xFFF97316), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fecha != null
                          ? '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} · ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                          : 'Sin fecha',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      '$items items · ${metodo.toUpperCase()}',
                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                    ),
                  ],
                ),
              ),
              Text('L.${_formatNumber(total)}', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _eliminarVenta(index),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
              ),
            ],
          ),
          if (detalles.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF262626), height: 1),
            const SizedBox(height: 6),
            ...detalles.take(4).map((d) {
              final nombre = d['nombre'] ?? 'Producto';
              final cant = (d['cantidad'] as num?)?.toInt() ?? 1;
              final precio = (d['precio'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('• $nombre', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFA3A3A3)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('$cant x L.${_formatNumber(precio)}', style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF525252))),
                  ],
                ),
              );
            }),
            if (detalles.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${detalles.length - 4} productos más', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF525252))),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: const Color(0xFF262626), size: 56),
          const SizedBox(height: 12),
          Text('Sin ventas en este período', style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFF737373))),
          const SizedBox(height: 4),
          Text('Las ventas realizadas en el terminal POS aparecerán aquí', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF525252))),
        ],
      ),
    );
  }

  String _formatNumber(double n) => n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
