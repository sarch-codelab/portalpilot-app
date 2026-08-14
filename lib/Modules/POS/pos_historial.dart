import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

/// Historial de ventas del POS, persistido en la base de datos local (Drift)
/// mediante las tablas `pos_ventas` y `pos_venta_items`.
class PosHistorial extends StatefulWidget {
  const PosHistorial({super.key});

  @override
  State<PosHistorial> createState() => _PosHistorialState();
}

class _PosHistorialState extends State<PosHistorial> {
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final AuthController _auth = AuthController.instance;

  List<PosVenta> _ventas = [];
  Map<String, List<PosVentaItem>> _itemsPorVenta = {};
  bool _cargando = true;
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
    setState(() => _cargando = true);
    try {
      final db = _localDb.database;
      final ventas = await (db.select(db.posVentas)
            ..where((v) => v.empresaId.equals(_auth.empresaCodigo))
            ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
          .get();

      final ids = ventas.map((v) => v.id).toList();
      Map<String, List<PosVentaItem>> itemsMap = {};
      if (ids.isNotEmpty) {
        final items = await (db.select(db.posVentaItems)
              ..where((i) => i.ventaId.isIn(ids))
              ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
            .get();
        for (final i in items) {
          itemsMap.putIfAbsent(i.ventaId, () => []).add(i);
        }
      }

      if (mounted) {
        setState(() {
          _ventas = ventas;
          _itemsPorVenta = itemsMap;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando historial POS: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<PosVenta> get _filtradas {
    final key = _filtros[_filtro] ?? 'all';
    final ahora = DateTime.now();
    return _ventas.where((v) {
      final fecha = v.createdAt;
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

  Future<void> _eliminarVenta(PosVenta venta) async {
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

    final db = _localDb.database;
    await db.transaction(() async {
      await (db.delete(db.posVentaItems)..where((i) => i.ventaId.equals(venta.id))).go();
      await (db.delete(db.posVentas)..where((v) => v.id.equals(venta.id))).go();
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;
    final total = filtradas.fold<double>(0, (s, v) => s + v.total);
    final items = filtradas.fold<int>(0, (s, v) => s + (_itemsPorVenta[v.id]?.fold<int>(0, (a, i) => a + i.cantidad) ?? 0));

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
            if (_cargando)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
              )
            else if (filtradas.isEmpty)
              _buildVacio()
            else
              ...filtradas.map((v) => _buildVentaCard(v)),
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

  Widget _buildVentaCard(PosVenta v) {
    final fecha = v.createdAt;
    final total = v.total;
    final detalles = _itemsPorVenta[v.id] ?? [];
    final items = detalles.fold<int>(0, (a, i) => a + i.cantidad);
    final metodo = v.metodoPago;

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
                      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} · ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      '${v.correlativo ?? ''} · $items items · ${metodo.toUpperCase()}',
                      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF737373)),
                    ),
                  ],
                ),
              ),
              Text('L.${_formatNumber(total)}', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _eliminarVenta(v),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
              ),
            ],
          ),
          if (detalles.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF262626), height: 1),
            const SizedBox(height: 6),
            ...detalles.take(4).map((d) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('• ${d.productoNombre}', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFA3A3A3)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${d.cantidad} x L.${_formatNumber(d.precioUnitario)}', style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF525252))),
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
