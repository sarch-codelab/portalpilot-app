import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/RRHH/empleados/empleado_form.dart';
import 'package:portal_pilot_app/Modules/RRHH/empleados/empleado_list.dart';
import 'package:portal_pilot_app/Modules/RRHH/nomina/nomina_home.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class RrhhHome extends StatefulWidget {
  const RrhhHome({super.key});

  @override
  State<RrhhHome> createState() => _RrhhHomeState();
}

class _RrhhHomeState extends State<RrhhHome> {
  List<Map<String, dynamic>> _empleados = [];
  int _totalEmpleados = 0;
  int _activos = 0;
  int _inactivos = 0;
  double _nominaMensual = 0.0;

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
    final json = prefs.getString('empleados') ?? '[]';
    final List<dynamic> empleados = jsonDecode(json);

    int activos = 0, inactivos = 0;
    double nomina = 0.0;

    for (final e in empleados) {
      final activo = e['activo'] ?? true;
      final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;
      if (activo) {
        activos++;
        nomina += salario;
      } else {
        inactivos++;
      }
    }

    setState(() {
      _empleados = List<Map<String, dynamic>>.from(empleados);
      _totalEmpleados = empleados.length;
      _activos = activos;
      _inactivos = inactivos;
      _nominaMensual = nomina;
    });
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
            color: Color(0xFFEC4899),
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
                  colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.people_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'RRHH / NÃ“MINA',
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
              appThemeNotifier.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: const Color(0xFFEC4899),
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
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmpleadoForm()),
          );
          _cargarDatos();
        },
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(
          Icons.person_add_rounded,
          color: Colors.white,
          size: 22,
        ),
        label: Text(
          'Nuevo Empleado',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFFEC4899),
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
            _buildSectionTitle('Ãšltimos Empleados'),
            const SizedBox(height: 10),
            _buildRecentEmpleados(),
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
      childAspectRatio: 6.5,
      children: [
        _buildStatCard(
          'Empleados',
          '$_totalEmpleados',
          Icons.people_rounded,
          const Color(0xFFEC4899),
        ),
        _buildStatCard(
          'Activos',
          '$_activos',
          Icons.check_circle_rounded,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Inactivos',
          '$_inactivos',
          Icons.person_off_rounded,
          const Color(0xFFEF4444),
        ),
        _buildStatCard(
          'Nómina/Mes',
          'L.${_formatNumber(_nominaMensual)}',
          Icons.payments_rounded,
          const Color(0xFFF59E0B),
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
          'Nuevo Empleado',
          'Registrar trabajador en el sistema',
          const Color(0xFFEC4899),
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmpleadoForm()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.list_alt_rounded,
          'Ver Empleados',
          'Lista completa de trabajadores',
          const Color(0xFF3B82F6),
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmpleadoList()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.payments_rounded,
          'Calcular Nómina',
          'Generar planilla del mes',
          const Color(0xFFF59E0B),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NominaHome()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          Icons.receipt_long_rounded,
          'Recibos de Pago',
          'Historial de recibos generados',
          const Color(0xFF10B981),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NominaHome()),
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

  Widget _buildRecentEmpleados() {
    final recientes = List<Map<String, dynamic>>.from(
      _empleados,
    )..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    if (recientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Center(
          child: Text(
            'No hay empleados registrados',
            style: GoogleFonts.dmSans(color: const Color(0xFF525252)),
          ),
        ),
      );
    }

    return Column(
      children: recientes.take(5).map((e) {
        final activo = e['activo'] ?? true;
        final salario = (e['salario'] as num?)?.toDouble() ?? 0.0;
        final nombre = '${e['nombre'] ?? ''} ${e['apellido'] ?? ''}'.trim();
        final cargo = e['cargo'] ?? 'Sin cargo';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo
                  ? const Color(0xFF262626)
                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (activo
                              ? const Color(0xFFEC4899)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  activo ? Icons.person_rounded : Icons.person_off_rounded,
                  color: activo
                      ? const Color(0xFFEC4899)
                      : const Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isNotEmpty ? nombre : 'Sin nombre',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cargo,
                      style: GoogleFonts.dmMono(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'L.${salario.toStringAsFixed(0)}',
                    style: GoogleFonts.dmMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  Text(
                    activo ? 'Activo' : 'Inactivo',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: activo
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
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
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
