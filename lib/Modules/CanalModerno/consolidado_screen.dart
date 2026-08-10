import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/canal_moderno_service.dart';

/// Reporte consolidado de toda la empresa (Canal Moderno).
class ConsolidadoScreen extends StatefulWidget {
  const ConsolidadoScreen({super.key});

  @override
  State<ConsolidadoScreen> createState() => _ConsolidadoScreenState();
}

class _ConsolidadoScreenState extends State<ConsolidadoScreen> {
  final _service = CanalModernoService.instance;

  bool _cargando = true;
  Consolidado? _consolidado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _service.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );
    final c = await _service.getConsolidado();
    if (!mounted) return;
    setState(() {
      _consolidado = c;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _consolidado;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFF97316),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'CONSOLIDADO',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1A1A1A),
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildKPIs(c),
                  const SizedBox(height: 20),
                  Text(
                    'VENTAS POR MÉTODO',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF525252),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildVentasPorMetodo(c),
                  const SizedBox(height: 20),
                  Text(
                    'POR SUCURSAL (${c?.totalSucursales ?? 0})',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF525252),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (c == null || c.porSucursal.isEmpty)
                    _buildVacio()
                  else
                    ...c.porSucursal.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildSucursalCard(s),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildKPIs(Consolidado? c) {
    final ventas = c?.ventasTotales ?? 0.0;
    final valor = c?.valorInventario ?? 0.0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VENTAS TOTALES',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'L.${_format(ventas)}',
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildKpi('Productos', '${c?.totalProductos ?? 0}', Icons.inventory_2_rounded),
            const SizedBox(width: 10),
            _buildKpi('Stock', '${c?.stockTotal ?? 0}', Icons.warehouse_rounded),
            const SizedBox(width: 10),
            _buildKpi('En tránsito', '${c?.enTransito ?? 0}', Icons.local_shipping_rounded),
          ],
        ),
        const SizedBox(height: 10),
        _buildValorBar(valor),
      ],
    );
  }

  Widget _buildKpi(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF10B981), size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: const Color(0xFF737373),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValorBar(double valor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.savings_rounded,
                color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VALOR DEL INVENTARIO',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: const Color(0xFF525252),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'L.${_format(valor)}',
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasPorMetodo(Consolidado? c) {
    final porMetodo = c?.ventasPorMetodo ?? const <String, double>{};
    if (porMetodo.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Text(
          'Sin ventas registradas.',
          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
        ),
      );
    }
    const colores = [
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFF97316),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
    ];
    var i = 0;
    final entries = porMetodo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: entries.map((e) {
          final color = colores[i % colores.length];
          i++;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.key.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'L.${_format(e.value)}',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVacio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          const Icon(Icons.dashboard_rounded, color: Color(0xFF404040), size: 36),
          const SizedBox(height: 10),
          Text(
            'Sin sucursales',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creá sucursales para ver el consolidado de la empresa.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  Widget _buildSucursalCard(ConsolidadoSucursal s) {
    final color = s.sucursal.esPrincipal
        ? const Color(0xFF10B981)
        : const Color(0xFF3B82F6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  s.sucursal.esPrincipal
                      ? Icons.star_rounded
                      : Icons.storefront_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.sucursal.nombre,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.productos} productos · ${s.stockUnidades} unidades',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              if (s.sucursal.esPrincipal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PRINCIPAL',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Inventario',
                  'L.${_format(s.valorInventario)}',
                  Icons.savings_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  'Enviadas',
                  '${s.enviadas}',
                  Icons.outbound_rounded,
                  const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  'Recibidas',
                  '${s.recibidas}',
                  Icons.inventory_2_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 9, color: const Color(0xFF737373)),
          ),
        ],
      ),
    );
  }

  String _format(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
