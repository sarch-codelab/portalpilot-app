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
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
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
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Scaffold(
      backgroundColor: palette.bgPrimary,
      appBar: AppBar(
        backgroundColor: palette.appBarColor,
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
                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Punto de Venta',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
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
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFFF97316),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
              MaterialPageRoute(builder: (_) => const PosTerminalV2()),
          );
        },
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(
          Icons.shopping_cart_rounded,
          color: Colors.white,
          size: 22,
        ),
        label: Text(
          'Nueva Venta',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
          if (_showAIChat) _buildAIChatPanel(),
        ],
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
      childAspectRatio: 6.5,
      children: [
        _buildStatCard(
          'Ventas Hoy',
          '$_totalVentas',
          Icons.receipt_rounded,
          const Color(0xFFF97316),
        ),
        _buildStatCard(
          'Ingresos',
          'L.${_formatNumber(_ventasHoy)}',
          Icons.attach_money_rounded,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Artículos',
          '$_totalItems',
          Icons.inventory_rounded,
          const Color(0xFF3B82F6),
        ),
        _buildStatCard(
          'Ticket Prom.',
          'L.${_formatNumber(_ticketPromedio)}',
          Icons.analytics_rounded,
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
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
                const SizedBox(height: 1),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: const Color(0xFF737373),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF737373),
                    ),
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
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Total Ventas',
                '$_totalVentas',
                const Color(0xFFF97316),
              ),
              _buildSummaryItem(
                'Ingresos',
                'L.${_formatNumber(_ventasHoy)}',
                const Color(0xFF10B981),
              ),
              _buildSummaryItem(
                'Ticket Prom.',
                'L.${_formatNumber(_ticketPromedio)}',
                const Color(0xFF3B82F6),
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
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: const Color(0xFF737373),
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
          color: const Color(0xFF111111),
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
                  Text('Asistente de Ventas', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF737373), size: 20),
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
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                      onSubmitted: (_) => _sendAIQuery(),
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre tus ventas...',
                        hintStyle: GoogleFonts.dmSans(color: const Color(0xFF525252), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF262626))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
            Text('Pregúntale a la IA sobre tus ventas', style: GoogleFonts.dmSans(color: Color(0xFF737373), fontSize: 13)),
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
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFF97316))),
            const SizedBox(width: 10),
            Text(msg.text, style: GoogleFonts.dmSans(color: const Color(0xFF737373), fontSize: 12)),
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
          color: msg.isUser ? const Color(0xFFF97316) : (msg.isError ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(12),
          border: msg.isUser ? null : Border.all(color: msg.isError ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFF262626)),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: msg.isUser ? Colors.white : (msg.isError ? const Color(0xFFEF4444) : const Color(0xFFE5E5E5)),
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
