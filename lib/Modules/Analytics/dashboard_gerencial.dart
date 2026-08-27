import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class DashboardGerencial extends StatefulWidget {
  const DashboardGerencial({super.key});

  @override
  State<DashboardGerencial> createState() => _DashboardGerencialState();
}

class _DashboardGerencialState extends State<DashboardGerencial> {
  bool _showAIChat = false;
  final _aiQueryController = TextEditingController();
  final List<_AIMessage> _aiMessages = [];
  bool _isAILoading = false;

  bool _cargando = true;
  Map<String, dynamic> _kpis = {};
  List<dynamic> _gastosCategoria = [];
  List<dynamic> _alertas = [];

  @override
  void initState() {
    super.initState();
    appThemeNotifier.addListener(_onThemeChanged);
    _cargarDatos();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appThemeNotifier.removeListener(_onThemeChanged);
    _aiQueryController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/dashboard/summary');
      if (api.isSuccess(result)) {
        if (mounted) {
          setState(() {
            _kpis = result['kpis'] ?? {};
            _gastosCategoria = result['gastosCategoria'] ?? [];
            _alertas = result['alertas'] ?? [];
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _sendAIQuery() async {
    final query = _aiQueryController.text.trim();
    if (query.isEmpty || _isAILoading) return;
    setState(() {
      _isAILoading = true;
      _aiMessages.add(_AIMessage(text: query, isUser: true));
      _aiMessages.add(_AIMessage(text: 'Analizando...', isUser: false, isLoading: true));
      _aiQueryController.clear();
    });
    try {
      final result = await AIManager.instance.dashboardQuery(query);
      setState(() {
        _aiMessages.removeLast();
        if (result.success) {
          _aiMessages.add(_AIMessage(text: result.text, isUser: false));
        } else {
          _aiMessages.add(_AIMessage(text: 'Error: ${result.error ?? "No se pudo procesar"}', isUser: false, isError: true));
        }
      });
    } catch (e) {
      setState(() {
        _aiMessages.removeLast();
        _aiMessages.add(_AIMessage(text: 'Error de conexión', isUser: false, isError: true));
      });
    } finally {
      if (mounted) setState(() => _isAILoading = false);
    }
  }

  void _toggleAIChat() {
    setState(() => _showAIChat = !_showAIChat);
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
            color: Color(0xFF6366F1),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dashboard Gerencial',
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: _showAIChat ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              size: 20,
            ),
            tooltip: 'Asistente IA',
            onPressed: _toggleAIChat,
          ),
          IconButton(
            icon: Icon(
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_cargando)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildExecutiveSummary(palette),
              const SizedBox(height: 20),
              _buildRevenueSection(palette),
              const SizedBox(height: 20),
              _buildChannelPerformance(palette),
              const SizedBox(height: 20),
              _buildKeyMetrics(palette),
              const SizedBox(height: 20),
              _buildAlertasSection(palette),
              const SizedBox(height: 100),
            ],
          ),
          if (_showAIChat) _buildAIChatPanel(palette),
        ],
      ),
    );
  }

  Widget _buildAlertasSection(ThemePalette palette) {
    if (_alertas.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark
            ? const Color(0xFF1A1A1A).withValues(alpha: 0.8)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appThemeNotifier.isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALERTAS',
            style: GoogleFonts.syne(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ..._alertas.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  a['severidad'] == 'alta'
                      ? Icons.error_rounded
                      : a['severidad'] == 'media'
                          ? Icons.warning_amber_rounded
                          : Icons.info_rounded,
                  size: 16,
                  color: a['severidad'] == 'alta'
                      ? Colors.red
                      : a['severidad'] == 'media'
                          ? Colors.orange
                          : Colors.blue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a['titulo'],
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummary(ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESUMEN EJECUTIVO',
                style: GoogleFonts.syne(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Agosto 2026',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
const SizedBox(height: 16),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               _buildSummaryItem(
                 'Facturas',
                 '${_kpis['facturasCount'] ?? 0}',
                 'Total: L.${(_kpis['facturasTotal'] ?? 0).toStringAsFixed(0)}',
                 const Color(0xFF10B981),
               ),
               _buildSummaryItem(
                 'Ingresos Mes',
                 'L.${(_kpis['ingresoMes'] ?? 0).toStringAsFixed(0)}',
                 'Balance: L.${(_kpis['balanceMes'] ?? 0).toStringAsFixed(0)}',
                 (_kpis['balanceMes'] ?? 0) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4443),
               ),
               _buildSummaryItem(
                 'Transacciones Hoy',
                 '${_kpis['transaccionesHoy'] ?? 0}',
                 'Pendientes: ${_kpis['facturasPendientes'] ?? 0}',
                 const Color(0xFFF59E0B),
               ),
             ],
           ),
         ],
       ),
     );
   }

   Widget _buildSummaryItem(
    String label,
    String value,
    String change,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.trending_up_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              change,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueSection(ThemePalette palette) {
    final gastos = _gastosCategoria;
    final colors = [const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFF3B82F6), const Color(0xFFEF4444)];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GASTOS POR CATEGORÍA',
            style: GoogleFonts.syne(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (gastos.isEmpty)
            Text('Sin datos de gastos', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF737373)))
          else
            ...gastos.take(4).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final g = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRevenueBar(
                  g['categoria'] ?? 'Otro',
                  (g['monto'] ?? 0).toDouble(),
                  colors[idx % colors.length],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRevenueBar(String canal, double valor, Color color) {
    final maxValor = 620000.0;
    final porcentaje = valor / maxValor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              canal,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appThemeNotifier.isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              'L.$valor.toStringAsFixed(0)',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: appThemeNotifier.isDark
                ? const Color(0xFF262626)
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: porcentaje,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

Widget _buildChannelPerformance(ThemePalette palette) {
    final facturasCount = _kpis['facturasCount'] ?? 0;
    final ingresoMes = (_kpis['ingresoMes'] ?? 0).toDouble();
    final lowStock = _kpis['lowStock'] ?? 0;
    final productosCount = _kpis['productosCount'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN DE OPERACIONES',
            style: GoogleFonts.syne(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceCard(
                  'Facturas',
                  '$facturasCount',
                  'total',
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPerformanceCard(
                  'Ingresos',
                  'L.$ingresoMes',
                  'este mes',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPerformanceCard(
                  'Stock Bajo',
                  '$lowStock',
                  'productos',
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceCard(
                  'Productos',
                  '$productosCount',
                  'en inventario',
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600, color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: appThemeNotifier.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildKeyMetrics(ThemePalette palette) {
    final facturasCount = _kpis['facturasCount'] ?? 0;
    final facturasTotal = (_kpis['facturasTotal'] ?? 0).toDouble();
    final ticketPromedio = facturasCount > 0 ? (facturasTotal / facturasCount).toStringAsFixed(0) : '0';
    final usuariosActivos = _kpis['usuariosActivos'] ?? 0;
    final lowStock = _kpis['lowStock'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appThemeNotifier.isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MÉTRICAS CLAVE',
            style: GoogleFonts.syne(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: appThemeNotifier.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Ticket Promedio',
                  'L.$ticketPromedio',
                  const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                  'Usuarios Activos',
                  '$usuariosActivos',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                  'Stock Bajo',
                  '$lowStock',
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: appThemeNotifier.isDark
                  ? const Color(0xFFA3A3A3)
                  : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIChatPanel(ThemePalette palette) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 420,
        decoration: BoxDecoration(
          color: appThemeNotifier.isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: appThemeNotifier.isDark
                  ? const Color(0xFF262626)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Asistente IA',
                      style: GoogleFonts.syne(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    onPressed: _toggleAIChat,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _aiMessages.isEmpty
                  ? Center(
                      child: Text(
                        'Pregunta sobre tus ventas, canales o métricas',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: appThemeNotifier.isDark
                              ? const Color(0xFFA3A3A3)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _aiMessages.length,
                      itemBuilder: (context, index) =>
                          _buildAIMessage(_aiMessages[index]),
                    ),
            ),
            if (_aiMessages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildAISuggestions(),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appThemeNotifier.isDark
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF9FAFB),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiQueryController,
                      enabled: !_isAILoading,
                      onSubmitted: (_) => _sendAIQuery(),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu pregunta...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: appThemeNotifier.isDark
                            ? const Color(0xFF262626)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isAILoading ? null : _sendAIQuery,
                    icon: _isAILoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
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
      '¿Cuál es el canal más rentable?',
      'Resume las ventas del mes',
      'Compara canales tradicional y moderno',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions
          .map(
            (s) => ActionChip(
              label: Text(s, style: GoogleFonts.dmSans(fontSize: 11)),
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
              side: const BorderSide(color: Color(0xFF6366F1)),
              onPressed: () {
                _aiQueryController.text = s;
                _sendAIQuery();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildAIMessage(_AIMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isError
              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
              : isUser
                  ? const Color(0xFF6366F1)
                  : appThemeNotifier.isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: message.isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.text,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: appThemeNotifier.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              )
            : Text(
                message.text,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: message.isError
                      ? const Color(0xFFEF4444)
                      : isUser
                          ? Colors.white
                          : appThemeNotifier.isDark
                              ? Colors.white
                              : Colors.black,
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
