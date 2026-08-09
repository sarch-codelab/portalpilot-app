import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/CRM/ventas/venta_form.dart';

class VentasHome extends StatefulWidget {
  const VentasHome({super.key});

  @override
  State<VentasHome> createState() => _VentasHomeState();
}

class _VentasHomeState extends State<VentasHome> {
  List<Map<String, dynamic>> _ventas = [];
  String _filtroEstado = 'Todos';

  final Map<String, Color> _colores = {
    'cotizacion': const Color(0xFF3B82F6),
    'en_proceso': const Color(0xFFF59E0B),
    'ganada': const Color(0xFF10B981),
    'perdida': const Color(0xFFEF4444),
  };

  final Map<String, String> _labels = {
    'cotizacion': 'Cotización',
    'en_proceso': 'En Proceso',
    'ganada': 'Ganada',
    'perdida': 'Perdida',
  };

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _ventas = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('ventas_crm') ?? '[]')));
  }

  Future<void> _cambiarEstado(String id, String nuevoEstado) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('ventas_crm') ?? '[]'));
    final idx = list.indexWhere((v) => v['id'] == id);
    if (idx != -1) { list[idx]['estado'] = nuevoEstado; await prefs.setString('ventas_crm', jsonEncode(list)); }
    _cargar();
  }

  Future<void> _eliminar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('ventas_crm') ?? '[]'));
    list.removeWhere((v) => v['id'] == id);
    await prefs.setString('ventas_crm', jsonEncode(list));
    _cargar();
  }

  List<Map<String, dynamic>> get _filtradas {
    if (_filtroEstado == 'Todos') return _ventas;
    return _ventas.where((v) => v['estado'] == _filtroEstado).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('VENTAS', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const VentaForm())); _cargar(); },
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text('Nueva Venta', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              children: ['Todos', 'Cotización', 'En Proceso', 'Ganada', 'Perdida'].map((f) {
                final key = f == 'Todos' ? 'Todos' : f == 'Cotización' ? 'cotizacion' : f == 'En Proceso' ? 'en_proceso' : f.toLowerCase();
                final selected = _filtroEstado == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filtroEstado = key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? const Color(0xFFF59E0B) : const Color(0xFF262626)),
                      ),
                      child: Text(f, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? const Color(0xFFF59E0B) : const Color(0xFF737373))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _filtradas.isEmpty
                ? Center(child: Text('No hay ventas', style: GoogleFonts.dmSans(color: const Color(0xFF525252))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtradas.length,
                    itemBuilder: (_, i) {
                      final v = _filtradas[i];
                      final estado = v['estado'] ?? 'cotizacion';
                      final color = _colores[estado] ?? const Color(0xFF737373);
                      final monto = (v['monto'] as num?)?.toDouble() ?? 0.0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(v['cliente'] ?? 'Sin cliente', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(_labels[estado] ?? estado, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(v['descripcion'] ?? '', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('L.${monto.toStringAsFixed(2)}', style: GoogleFonts.dmMono(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B))),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: color, size: 18),
                                  color: const Color(0xFF1A1A1A),
                                  onSelected: (op) {
                                    if (op == 'delete') {
                                      _eliminar(v['id']);
                                    } else {
                                      _cambiarEstado(v['id'], op);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (estado != 'ganada') const PopupMenuItem(value: 'ganada', child: Text('Marcar Ganada', style: TextStyle(color: Color(0xFF10B981)))),
                                    if (estado != 'perdida') const PopupMenuItem(value: 'perdida', child: Text('Marcar Perdida', style: TextStyle(color: Color(0xFFEF4444)))),
                                    if (estado != 'en_proceso') const PopupMenuItem(value: 'en_proceso', child: Text('En Proceso', style: TextStyle(color: Color(0xFFF59E0B)))),
                                    const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Color(0xFFEF4444)))),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
