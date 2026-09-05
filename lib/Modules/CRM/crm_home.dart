import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/CRM/clientes/cliente_form.dart';
import 'package:portal_pilot_app/Modules/CRM/clientes/cliente_list.dart';
import 'package:portal_pilot_app/Modules/CRM/ventas/ventas_home.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';

class CrmHome extends StatefulWidget {
  const CrmHome({super.key});

  @override
  State<CrmHome> createState() => _CrmHomeState();
}

class _CrmHomeState extends State<CrmHome> {
  List<Map<String, dynamic>> _ventas = [];
  int _totalClientes = 0;
  int _clientesActivos = 0;
  double _ventasMes = 0.0;
  double _pendienteCobro = 0.0;

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
    appThemeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final venJson = prefs.getString('ventas_crm') ?? '[]';
    final List<dynamic> ventas = jsonDecode(venJson);

    int activos = 0;
    double ventasMes = 0, pendiente = 0;
    final ahora = DateTime.now();

    // Cargar clientes desde el backend
    int totalClientes = 0;
    try {
      final api = ApiService.instance;
      final result = await api.get('/api/clientes');
      if (result != null && api.isSuccess(result)) {
        final clientes = result['clientes'] ?? [];
        if (clientes is List) {
          totalClientes = clientes.length;
          for (final c in clientes) {
            if (c['activo'] != false) activos++;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando clientes del backend: $e');
      // Fallback a SharedPreferences
      final cliJson = prefs.getString('clientes') ?? '[]';
      final List<dynamic> clientes = jsonDecode(cliJson);
      totalClientes = clientes.length;
      for (final c in clientes) {
        if (c['activo'] != false) activos++;
      }
    }

    for (final v in ventas) {
      final fecha = DateTime.tryParse(v['fecha'] ?? '');
      final monto = (v['monto'] as num?)?.toDouble() ?? 0.0;
      final estado = v['estado'] ?? 'pendiente';
      if (fecha != null &&
          fecha.year == ahora.year &&
          fecha.month == ahora.month) {
        ventasMes += monto;
      }
      if (estado == 'pendiente' || estado == 'en_proceso') {
        pendiente += monto;
      }
    }

    setState(() {
      _ventas = List<Map<String, dynamic>>.from(ventas);
      _totalClientes = totalClientes;
      _clientesActivos = activos;
      _ventasMes = ventasMes;
      _pendienteCobro = pendiente;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PPModuleScaffold(
      moduleId: 'crm',
      screenTitle: 'CRM',
      moduleIcon: Icons.contacts_rounded,
      moduleColor: const Color(0xFF06B6D4),
      onNew: _nuevoCliente,
      onRefresh: _cargarDatos,
      actions: [
        IconButton(
          icon: Icon(
            appThemeNotifier.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: const Color(0xFF06B6D4),
            size: 20,
          ),
          onPressed: () async {
            await appThemeNotifier.toggle();
          },
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildSectionTitle('Acciones Rápidas'),
          const SizedBox(height: 10),
          _buildActions(),
          const SizedBox(height: 20),
          _buildSectionTitle('Pipeline de Ventas'),
          const SizedBox(height: 10),
          _buildPipeline(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _nuevoCliente() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClienteForm()),
    );
    _cargarDatos();
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
          'Clientes',
          '$_totalClientes',
          Icons.people_rounded,
          const Color(0xFF06B6D4),
        ),
        _buildStatCard(
          'Activos',
          '$_clientesActivos',
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Ventas Mes',
          'L.${_formatNumber(_ventasMes)}',
          Icons.trending_up_rounded,
          const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          'Por Cobrar',
          'L.${_formatNumber(_pendienteCobro)}',
          Icons.pending_actions_rounded,
          const Color(0xFFEF4444),
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
          Icons.person_add_rounded,
          'Nuevo Cliente',
          'Registrar cliente en CRM',
          const Color(0xFF06B6D4),
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClienteForm()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.list_alt_rounded,
          'Ver Clientes',
          'Directorio completo',
          const Color(0xFF3B82F6),
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClienteList()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.trending_up_rounded,
          'Ventas',
          'Pipeline y oportunidades',
          const Color(0xFFF59E0B),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VentasHome()),
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
              MaterialPageRoute(builder: (_) => const VentasHome()),
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

  Widget _buildPipeline() {
    final porCotizar = _ventas.where((v) => v['estado'] == 'cotizacion').length;
    final enProceso = _ventas.where((v) => v['estado'] == 'en_proceso').length;
    final ganadas = _ventas.where((v) => v['estado'] == 'ganada').length;
    final perdidas = _ventas.where((v) => v['estado'] == 'perdida').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPipeStage('Cotización', porCotizar, const Color(0xFF3B82F6))),
          Expanded(child: _buildPipeStage('Proceso', enProceso, const Color(0xFFF59E0B))),
          Expanded(child: _buildPipeStage('Ganada', ganadas, const Color(0xFF10B981))),
          Expanded(child: _buildPipeStage('Perdida', perdidas, const Color(0xFFEF4444))),
        ],
      ),
    );
  }

  Widget _buildPipeStage(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$count',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
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
}
