import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/Inventario/producto_form.dart';
import 'package:portal_pilot_app/Modules/Inventario/producto_list.dart';
import 'package:portal_pilot_app/Modules/Inventario/kardex.dart';
import 'package:portal_pilot_app/Modules/Inventario/bodegas.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/canal_moderno_home.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class InventarioHome extends StatefulWidget {
  const InventarioHome({super.key});

  @override
  State<InventarioHome> createState() => _InventarioHomeState();
}

class _InventarioHomeState extends State<InventarioHome> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _bodegas = [];
  int _totalProductos = 0;
  int _stockBajo = 0;
  double _valorInventario = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    appThemeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(() {});
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final productosJson = prefs.getString('productos') ?? '[]';
    final bodegasJson = prefs.getString('bodegas') ?? '["General"]';
    final List<dynamic> productos = jsonDecode(productosJson);
    final List<dynamic> bodegas = jsonDecode(bodegasJson);

    int stockBajo = 0;
    double valor = 0.0;

    for (final p in productos) {
      final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
      final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
      final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
      if (stock <= minimo && minimo > 0) stockBajo++;
      valor += stock * precio;
    }

    setState(() {
      _productos = List<Map<String, dynamic>>.from(productos);
      _bodegas = List<String>.from(bodegas).map((b) => {'nombre': b}).toList();
      _totalProductos = productos.length;
      _stockBajo = stockBajo;
      _valorInventario = valor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final productosBajo = _productos.where((p) {
      final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
      final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
      return stock <= minimo && minimo > 0;
    }).toList();

    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'INVENTARIO',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFF59E0B),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductoForm()));
          _cargarDatos();
        },
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nuevo Producto',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFFF59E0B),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 16),
            if (productosBajo.isNotEmpty) ...[
              _buildAlertBanner(productosBajo.length),
              const SizedBox(height: 16),
            ],
            _buildSectionTitle('Acciones Rápidas'),
            const SizedBox(height: 10),
            _buildActions(),
            const SizedBox(height: 20),
            _buildSectionTitle('Últimos Productos'),
            const SizedBox(height: 10),
            _buildRecentProducts(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Productos', '$_totalProductos', Icons.inventory_2_rounded, const Color(0xFFF59E0B)),
        _buildStatCard('Stock Bajo', '$_stockBajo', Icons.warning_amber_rounded, const Color(0xFFEF4444)),
        _buildStatCard('Bodegas', '${_bodegas.length}', Icons.warehouse_rounded, const Color(0xFF3B82F6)),
        _buildStatCard('Valor', 'L.${_formatNumber(_valorInventario)}', Icons.attach_money_rounded, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
          Text(
            value,
            style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count producto${count > 1 ? 's' : ''} con stock bajo',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  'Revisa el inventario para reabastecer',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFA3A3A3)),
                ),
              ],
            ),
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

  Widget _buildActions() {
    return Column(
      children: [
        _buildActionRow(Icons.add_circle_outline_rounded, 'Nuevo Producto', 'Agregar producto al catálogo', const Color(0xFFF59E0B), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductoForm()));
          _cargarDatos();
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.list_alt_rounded, 'Ver Catálogo', 'Lista completa de productos', const Color(0xFF3B82F6), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductoList()));
          _cargarDatos();
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.swap_horiz_rounded, 'Kardex', 'Historial de movimientos de stock', const Color(0xFF10B981), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const KardexScreen()));
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.warehouse_rounded, 'Bodegas', 'Gestionar almacenes', const Color(0xFF8B5CF6), () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const BodegasScreen()));
          _cargarDatos();
        }),
        const SizedBox(height: 8),
        _buildActionRow(Icons.account_balance_rounded, 'Canal Moderno', 'Multi-sucursal, transferencias y consolidado', const Color(0xFF0EA5E9), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CanalModernoHome()));
        }),
      ],
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF737373))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF404040), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProducts() {
    final recientes = List<Map<String, dynamic>>.from(_productos)
      ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    if (recientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Center(
          child: Text('No hay productos registrados', style: GoogleFonts.dmSans(color: const Color(0xFF525252))),
        ),
      );
    }

    return Column(
      children: recientes.take(5).map((p) {
        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final minimo = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
        final bajo = stock <= minimo && minimo > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bajo ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (bajo ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  bajo ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
                  color: bajo ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['nombre'] ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      '${p['codigo'] ?? 'S/C'}  •  ${p['categoria'] ?? 'Sin categoría'}',
                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Stock: $stock',
                    style: GoogleFonts.dmMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: bajo ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'L.${precio.toStringAsFixed(2)}',
                    style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
