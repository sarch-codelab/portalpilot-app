import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/POS/pos_terminal.dart';
import 'package:portal_pilot_app/Modules/POS/pos_historial.dart';
import 'package:portal_pilot_app/Modules/POS/pos_reportes.dart';
import 'package:portal_pilot_app/Modules/Inventario/producto_list.dart';
import 'package:portal_pilot_app/Modules/CanalTradicional/fiado_screen.dart';
import 'package:portal_pilot_app/Modules/CanalTradicional/ruta_screen.dart';
import 'package:portal_pilot_app/Modules/Membresias/membresia_home.dart';

class PosHome extends StatefulWidget {
  const PosHome({super.key});

  @override
  State<PosHome> createState() => _PosHomeState();
}

class _PosHomeState extends State<PosHome> {
  int _totalVentas = 0;
  double _ventasHoy = 0.0;
  int _totalItems = 0;
  double _ticketPromedio = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final ventasJson = prefs.getString('ventas_pos') ?? '[]';
    final List<dynamic> ventas = jsonDecode(ventasJson);

    final ahora = DateTime.now();
    double ventasHoy = 0;
    int countHoy = 0;

    for (final v in ventas) {
      final fecha = DateTime.tryParse(v['fecha'] ?? '');
      final total = (v['total'] as num?)?.toDouble() ?? 0.0;
      if (fecha != null && fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day) {
        ventasHoy += total;
        countHoy++;
      }
    }

    final articulosJson = prefs.getString('productos_pos') ?? '[]';
    final List<dynamic> articulos = jsonDecode(articulosJson);

    setState(() {
      _totalVentas = ventas.length;
      _ventasHoy = ventasHoy;
      _totalItems = articulos.length;
      _ticketPromedio = countHoy > 0 ? ventasHoy / countHoy : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text('Punto de Venta', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PosTerminal()));
        },
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22),
        label: Text('Nueva Venta', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFFF97316),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildSectionTitle('Acciones Rápidas'),
            const SizedBox(height: 10),
            _buildActions(),
            const SizedBox(height: 20),
            _buildSectionTitle('Resumen del Día'),
            const SizedBox(height: 10),
            _buildDaySummary(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
      children: [
        _buildStatCard('Ventas Hoy', '$_totalVentas', Icons.receipt_rounded, const Color(0xFFF97316)),
        _buildStatCard('Ingresos', 'L.${_formatNumber(_ventasHoy)}', Icons.attach_money_rounded, const Color(0xFF10B981)),
        _buildStatCard('Artículos', '$_totalItems', Icons.inventory_rounded, const Color(0xFF3B82F6)),
        _buildStatCard('Ticket Prom.', 'L.${_formatNumber(_ticketPromedio)}', Icons.analytics_rounded, const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8));
  }

  Widget _buildActions() {
    return Column(
      children: [
        _buildActionRow(Icons.shopping_cart_rounded, 'Abrir Terminal POS', 'Realizar ventas y cobros', const Color(0xFFF97316), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PosTerminal()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.inventory_2_rounded, 'Inventario', 'Ver productos disponibles', const Color(0xFF3B82F6), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductoList()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.history_rounded, 'Historial', 'Ventas anteriores', const Color(0xFF10B981), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PosHistorial()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.analytics_rounded, 'Reportes', 'Estadísticas de ventas', const Color(0xFF8B5CF6), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PosReportes()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.account_balance_wallet_rounded, 'Fiado · Cuentas por Cobrar', 'Saldos, abonos y límites de crédito', const Color(0xFF10B981), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FiadoScreen()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.route_rounded, 'Rutas', 'Rutas de reparto y clientes asignados', const Color(0xFF8B5CF6), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RutaScreen()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.badge_rounded, 'Membresías', 'Socios, precios preferenciales y vigencias', const Color(0xFF8B5CF6), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MembresiaHome()));
        }),
      ],
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF262626))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total Ventas', '$_totalVentas', const Color(0xFFF97316)),
              _buildSummaryItem('Ingresos', 'L.${_formatNumber(_ventasHoy)}', const Color(0xFF10B981)),
              _buildSummaryItem('Ticket Prom.', 'L.${_formatNumber(_ticketPromedio)}', const Color(0xFF3B82F6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF737373))),
      ],
    );
  }

  String _formatNumber(double n) => n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
