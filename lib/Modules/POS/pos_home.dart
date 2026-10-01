import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Modules/POS/pos_terminal_v2.dart';
import 'package:portal_pilot_app/Modules/POS/pos_historial.dart';
import 'package:portal_pilot_app/Modules/POS/pos_reportes.dart';
import 'package:portal_pilot_app/Modules/Inventario/producto_list.dart';
import 'package:portal_pilot_app/Modules/CanalTradicional/fiado_screen.dart';
import 'package:portal_pilot_app/Modules/CanalTradicional/ruta_screen.dart';
import 'package:portal_pilot_app/Modules/Membresias/membresia_home.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/pos_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_stats_card.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';

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
  bool _showAIChat = false;
  final _aiQueryController = TextEditingController();
  final List<_AIMessage> _aiMessages = [];
  bool _isAILoading = false;

  // ── Caja del turno (el cajero necesita abrir/cerrar su gaveta) ──
  final PosService _posService = PosService.instance;
  Map<String, dynamic>? _caja;

  Future<void> _cargarCaja() async {
    try {
      _posService.setContext(
        empresaId: AuthController.instance.empresaCodigo,
        terminalId: 'TERM-${AuthController.instance.empresaCodigo}-01',
        usuarioId: AuthController.instance.email,
      );
      final res = await _posService.resumenCajaAbierta();
      if (mounted) setState(() => _caja = res.isEmpty ? null : res);
    } catch (_) {
      if (mounted) setState(() => _caja = null);
    }
  }

  Future<void> _abrirCajaDialogo() async {
    final ctrl = TextEditingController();
    final fondo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appPalette.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Abrir caja', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: appPalette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Cuánto efectivo dejas de fondo en la gaveta?', style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmSans(color: appPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(prefixText: 'L ', prefixStyle: GoogleFonts.dmSans(color: appPalette.textPrimary, fontWeight: FontWeight.w700), filled: true, fillColor: appPalette.bgSecondary, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appPalette.borderLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316)))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0),
            child: Text('Abrir', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (fondo == null) return;
    try {
      await _posService.abrirCaja(fondoInicial: fondo);
      Logger().audit('crear', 'arqueo', 'apertura', userId: AuthController.instance.email, module: 'pos', changes: {'fondo_inicial': fondo});
      await _cargarCaja();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Caja abierta con L${fondo.toStringAsFixed(2)} de fondo', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir la caja: $e', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Future<void> _cerrarCajaDialogo() async {
    final sistema = (_caja?['sistema_total'] as num?)?.toDouble() ?? 0;
    final ctrl = TextEditingController(text: sistema.toStringAsFixed(2));
    final conteo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appPalette.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cerrar caja (corte Z)', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: appPalette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Según el sistema debería haber:', style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted)),
            Text('L${sistema.toStringAsFixed(2)}', style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
            const SizedBox(height: 10),
            Text('Cuenta el efectivo físico de la gaveta:', style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmSans(color: appPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(prefixText: 'L ', prefixStyle: GoogleFonts.dmSans(color: appPalette.textPrimary, fontWeight: FontWeight.w700), filled: true, fillColor: appPalette.bgSecondary, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appPalette.borderLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316)))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0),
            child: Text('Cerrar turno', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (conteo == null) return;
    try {
      await _posService.cerrarCaja(conteoFisico: conteo);
      final dif = conteo - sistema;
      Logger().audit('editar', 'arqueo', 'cierre', userId: AuthController.instance.email, module: 'pos', changes: {'sistema': sistema.toStringAsFixed(2), 'conteo': conteo.toStringAsFixed(2), 'diferencia': dif.toStringAsFixed(2)});
      await _cargarCaja();
      if (mounted) {
        final difTxt = dif.abs() < 0.01 ? '¡Caja cuadrada!' : (dif > 0 ? 'Sobrante: L${dif.toStringAsFixed(2)}' : 'Faltante: L${dif.abs().toStringAsFixed(2)}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Turno cerrado · $difTxt', style: GoogleFonts.dmSans()), backgroundColor: dif.abs() < 0.01 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cerrar la caja: $e', style: GoogleFonts.dmSans()), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  Widget _buildCajaPanel() {
    final abierta = _caja != null;
    final sistema = (_caja?['sistema_total'] as num?)?.toDouble() ?? 0;
    final efectivo = (_caja?['efectivo'] as num?)?.toDouble() ?? 0;
    final fiado = (_caja?['fiado'] as num?)?.toDouble() ?? 0;
    final desde = _caja?['desde'] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appPalette.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: abierta ? const Color(0xFF10B981).withValues(alpha: 0.35) : appPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(abierta ? Icons.lock_open_rounded : Icons.lock_rounded, color: abierta ? const Color(0xFF10B981) : appPalette.textMuted, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  abierta ? 'Caja abierta${desde != null ? ' · desde ${desde.day}/${desde.month} ${desde.hour.toString().padLeft(2, '0')}:${desde.minute.toString().padLeft(2, '0')}' : ''}' : 'Caja cerrada',
                  style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: appPalette.textPrimary),
                ),
              ),
              TextButton(
                onPressed: abierta ? _cerrarCajaDialogo : _abrirCajaDialogo,
                child: Text(abierta ? 'Cerrar turno' : 'Abrir caja', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: abierta ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
              ),
            ],
          ),
          if (abierta) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _cajaDato('En gaveta (sistema)', 'L${sistema.toStringAsFixed(2)}', const Color(0xFF10B981))),
                const SizedBox(width: 10),
                Expanded(child: _cajaDato('Efectivo del turno', 'L${efectivo.toStringAsFixed(2)}', const Color(0xFFF97316))),
                const SizedBox(width: 10),
                Expanded(child: _cajaDato('Fiado del turno', 'L${fiado.toStringAsFixed(2)}', const Color(0xFFF59E0B))),
              ],
            ),
          ] else
            Text(
              'Abre la caja con el fondo inicial antes de vender. Al final del día, el corte Z te dice si cuadró.',
              style: GoogleFonts.dmSans(fontSize: 12, color: appPalette.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _cajaDato(String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 10.5, color: appPalette.textMuted)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(valor, style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    appThemeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _aiQueryController.dispose();
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _toggleAIChat() {
    setState(() => _showAIChat = !_showAIChat);
  }

  Future<void> _sendAIQuery() async {
    final query = _aiQueryController.text.trim();
    if (query.isEmpty || _isAILoading) return;
    setState(() {
      _isAILoading = true;
      _aiMessages.add(_AIMessage(text: query, isUser: true));
      _aiMessages.add(_AIMessage(text: 'Analizando ventas...', isUser: false, isLoading: true));
      _aiQueryController.clear();
    });
    try {
      final result = await AIManager.instance.posAnalysis(query);
      if (mounted) {
        setState(() {
          _aiMessages.removeLast();
          if (result.success) {
            _aiMessages.add(_AIMessage(text: result.text, isUser: false));
          } else {
            _aiMessages.add(_AIMessage(text: 'Error: ${result.error ?? "No se pudo procesar"}', isUser: false, isError: true));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiMessages.removeLast();
          _aiMessages.add(_AIMessage(text: 'Error de conexión', isUser: false, isError: true));
        });
      }
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  Future<void> _cargarDatos() async {
    unawaited(_cargarCaja());
    try {
      final api = ApiService.instance;

      final resumenResult = await api.get('/api/pos/ventas/resumen');
      if (api.isSuccess(resumenResult)) {
        final resumen = resumenResult['resumen'] ?? resumenResult;
        if (mounted) {
          setState(() {
            _totalVentas = (resumen['ventas_hoy'] as num?)?.toInt() ?? 0;
            _ventasHoy = (resumen['ingresos_hoy'] as num?)?.toDouble() ?? 0.0;
            _ticketPromedio = (resumen['ticket_promedio'] as num?)?.toDouble() ?? 0.0;
          });
        }
      }

      final productosResult = await api.get('/api/productos');
      if (api.isSuccess(productosResult)) {
        final productos = productosResult['productos'] ?? [];
        if (mounted) {
          setState(() {
            _totalItems = (productos is List) ? productos.length : 0;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando datos POS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PPModuleScaffold(
      moduleId: 'pos',
      screenTitle: 'Punto de Venta',
      moduleIcon: Icons.point_of_sale_rounded,
      moduleColor: const Color(0xFFF97316),
      onNew: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PosTerminalV2()),
        );
      },
      actions: [
        IconButton(
          icon: Icon(
            _showAIChat ? Icons.chat_bubble : Icons.auto_awesome,
            color: const Color(0xFFF97316),
            size: 20,
          ),
          onPressed: _toggleAIChat,
          tooltip: 'Asistente IA',
        ),
        ],
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _cargarDatos,
            color: const Color(0xFFF97316),
            backgroundColor: appPalette.cardColor,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildDashboardHeader(),
                const SizedBox(height: 16),
                _buildCajaPanel(),
                const SizedBox(height: 16),
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
          if (_showAIChat) _buildAIChatPanel(),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    // Icono de marca PNG centrado sobre el título del dashboard.
    final logoSize = (MediaQuery.sizeOf(context).shortestSide * 0.2).clamp(92.0, 128.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'img/Iconos/punto_de_venta.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Punto de Venta',
          style: GoogleFonts.syne(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: appPalette.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ventas, cobros y facturación',
          style: GoogleFonts.dmSans(fontSize: 13, color: appPalette.textMuted),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    // Mismo estilo de KPIs que Inventario: tarjetas verticales grandes
    // (PPStatsGrid) con icono arriba y valor grande; 2 columnas en móvil,
    // 4 en escritorio.
    return PPStatsGrid(
      cards: [
        PPStatsCard(
          label: 'Ventas Hoy',
          value: '$_totalVentas',
          icon: Icons.receipt_rounded,
          color: const Color(0xFFF97316),
        ),
        PPStatsCard(
          label: 'Ingresos',
          value: 'L.${_formatNumber(_ventasHoy)}',
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF10B981),
        ),
        PPStatsCard(
          label: 'Artículos',
          value: '$_totalItems',
          icon: Icons.inventory_rounded,
          color: const Color(0xFF3B82F6),
        ),
        PPStatsCard(
          label: 'Ticket Prom.',
          value: 'L.${_formatNumber(_ticketPromedio)}',
          icon: Icons.analytics_rounded,
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.syne(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: appPalette.textPrimary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        _buildActionRow(
          Icons.shopping_cart_rounded,
          'Abrir Terminal POS',
          'Realizar ventas y cobros',
          const Color(0xFFF97316),
          () {
            Navigator.push(
              context,
            MaterialPageRoute(builder: (_) => const PosTerminalV2()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.inventory_2_rounded,
          'Inventario',
          'Ver productos disponibles',
          const Color(0xFF3B82F6),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductoList()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.history_rounded,
          'Historial',
          'Ventas anteriores',
          const Color(0xFF10B981),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PosHistorial()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.analytics_rounded,
          'Reportes',
          'Estadísticas de ventas',
          const Color(0xFF8B5CF6),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PosReportes()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.account_balance_wallet_rounded,
          'Fiado · Cuentas por Cobrar',
          'Saldos, abonos y límites de crédito',
          const Color(0xFF10B981),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FiadoScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.route_rounded,
          'Rutas',
          'Rutas de reparto y clientes asignados',
          const Color(0xFF8B5CF6),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RutaScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.badge_rounded,
          'Membresías',
          'Socios, precios preferenciales y vigencias',
          const Color(0xFF8B5CF6),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MembresiaHome()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionRow(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: appPalette.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appPalette.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: appPalette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: appPalette.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF404040),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appPalette.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appPalette.borderLight),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Ventas',
                  '$_totalVentas',
                  const Color(0xFFF97316),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Ingresos',
                  'L.${_formatNumber(_ventasHoy)}',
                  const Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Ticket Prom.',
                  'L.${_formatNumber(_ticketPromedio)}',
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: appPalette.textMuted,
          ),
        ),
      ],
    );
  }

  String _formatNumber(double n) => n
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  Widget _buildAIChatPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: appPalette.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFF404040), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 18),
                  const SizedBox(width: 8),
                  Text('Asistente de Ventas', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: appPalette.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: appPalette.textMuted, size: 20),
                    onPressed: _toggleAIChat,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _aiMessages.isEmpty
                  ? _buildAISuggestions()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _aiMessages.length,
                      itemBuilder: (ctx, i) => _buildAIMessage(_aiMessages[i]),
                    ),
            ),
            if (_isAILoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: LinearProgressIndicator(color: Color(0xFFF97316)),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiQueryController,
                      style: GoogleFonts.dmSans(color: appPalette.textPrimary, fontSize: 13),
                      onSubmitted: (_) => _sendAIQuery(),
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre tus ventas...',
                        hintStyle: GoogleFonts.dmSans(color: appPalette.textDim, fontSize: 13),
                        filled: true,
                        fillColor: appPalette.cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appPalette.borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appPalette.borderLight)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(Icons.send_rounded, color: appPalette.cardColor, size: 18),
                      onPressed: _sendAIQuery,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISuggestions() {
    final suggestions = [
      '¿Cómo van las ventas hoy?',
      '¿Cuál es el ticket promedio?',
      '¿Qué productos más se venden?',
      '¿Hay alguna tendencia preocupante?',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 32),
            const SizedBox(height: 12),
            Text('Pregúntale a la IA sobre tus ventas', style: GoogleFonts.dmSans(color: appPalette.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((s) => GestureDetector(
                onTap: () {
                  _aiQueryController.text = s;
                  _sendAIQuery();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                  ),
                  child: Text(s, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFF97316))),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMessage(_AIMessage msg) {
    if (msg.isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appPalette.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFF97316))),
            const SizedBox(width: 10),
            Text(msg.text, style: GoogleFonts.dmSans(color: appPalette.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFFF97316) : (msg.isError ? const Color(0xFFEF4444).withValues(alpha: 0.15) : appPalette.cardColor),
          borderRadius: BorderRadius.circular(12),
          border: msg.isUser ? null : Border.all(color: msg.isError ? const Color(0xFFEF4444).withValues(alpha: 0.3) : appPalette.borderLight),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: msg.isUser ? appPalette.textPrimary : (msg.isError ? const Color(0xFFEF4444) : const Color(0xFFE5E5E5)),
          ),
        ),
      ),
    );
  }
}

class _AIMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isError;
  _AIMessage({required this.text, required this.isUser, this.isLoading = false, this.isError = false});
}
