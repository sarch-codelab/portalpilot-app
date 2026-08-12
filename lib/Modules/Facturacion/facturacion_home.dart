import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:portal_pilot_app/Modules/Facturacion/factura_form.dart';
import 'package:portal_pilot_app/Modules/Facturacion/factura_list.dart';
import 'package:portal_pilot_app/Modules/Facturacion/clientes/cliente_form.dart';
import 'package:portal_pilot_app/Modules/Facturacion/reportes/reportes.dart';
import 'package:portal_pilot_app/Modules/Facturacion/sar_config_screen.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class FacturacionHome extends StatefulWidget {
  const FacturacionHome({super.key});

  @override
  State<FacturacionHome> createState() => _FacturacionHomeState();
}

class _FacturacionHomeState extends State<FacturacionHome> {
  String _empresaNombre = 'Mi Empresa';
  String _rtn = '';
  String _cai = '';
  String _rangoInicio = '001-001-01-00000001';
  String _rangoFin = '001-001-01-00000500';
  String _fechaLimite = '';
  int _facturasHoy = 0;
  double _totalHoy = 0.0;
  int _totalFacturas = 0;
  double _montoTotal = 0.0;

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

    SarService.instance.setContext(
      empresaId: AuthController.instance.empresaCodigo,
      usuarioId: AuthController.instance.email,
    );

    final config = await SarService.instance.getConfiguracion();
    final row = await SarService.instance.getCorrelativoPorTipo(
      SarTipoDocumento.factura,
    );

    setState(() {
      _empresaNombre =
          config?.razonSocial ??
          config?.nombreComercial ??
          prefs.getString('empresa_nombre') ??
          'Mi Empresa';
      _rtn = config?.rtn ?? prefs.getString('empresa_rtn') ?? '';
      _cai = row.cai ?? '';
      _rangoInicio = row.rangoInicio ?? '001-001-01-00000001';
      _rangoFin = row.rangoFin ?? '001-001-01-00000500';
      _fechaLimite = row.fechaLimiteEmision?.toIso8601String() ?? '';
    });

    final facturasJson = prefs.getString('facturas') ?? '[]';
    final List<dynamic> facturas = jsonDecode(facturasJson);

    final hoy = DateTime.now();
    int fHoy = 0;
    double tHoy = 0.0;

    for (final f in facturas) {
      final fecha = DateTime.tryParse(f['fecha'] ?? '') ?? DateTime.now();
      if (fecha.year == hoy.year &&
          fecha.month == hoy.month &&
          fecha.day == hoy.day) {
        fHoy++;
        tHoy += (f['total'] as num?)?.toDouble() ?? 0.0;
      }
    }

    setState(() {
      _facturasHoy = fHoy;
      _totalHoy = tHoy;
      _totalFacturas = facturas.length;
      _montoTotal = facturas.fold(
        0.0,
        (sum, f) => sum + ((f['total'] as num?)?.toDouble() ?? 0.0),
      );
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
            color: Color(0xFF10B981),
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
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'FACTURACIÃ“N SAR',
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
              color: const Color(0xFF10B981),
              size: 20,
            ),
            onPressed: () async {
              await appThemeNotifier.toggle();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF737373),
              size: 20,
            ),
            onPressed: _mostrarConfiguracion,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildCAIBanner(),
            const SizedBox(height: 16),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildSectionTitle('Acciones Rápidas'),
            const SizedBox(height: 10),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildSectionTitle('Documentos Fiscales'),
            const SizedBox(height: 10),
            _buildDocumentTypes(),
            const SizedBox(height: 20),
            _buildSectionTitle('Resumen ISV'),
            const SizedBox(height: 10),
            _buildISVSummary(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FacturaForm()),
          );
          _cargarDatos();
        },
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Nueva Factura',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCAIBanner() {
    if (_cai.isEmpty) {
      return GestureDetector(
        onTap: _mostrarConfiguracion,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF92400E), Color(0xFF78350F)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFD97706).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFBBF24),
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAI no configurado',
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configurá tu CAI para empezar a facturar',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFFD4D4D4),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFFBBF24),
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    final vencido =
        _fechaLimite.isNotEmpty &&
        DateTime.tryParse(_fechaLimite) != null &&
        DateTime.tryParse(_fechaLimite)!.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vencido
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: vencido
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
              : const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                vencido ? Icons.error_outline_rounded : Icons.verified_rounded,
                color: vencido
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                vencido ? 'CAI VENCIDO' : 'CAI Activo',
                style: GoogleFonts.syne(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: vencido
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (_cai.isNotEmpty)
                GestureDetector(
                  onTap: _mostrarConfiguracion,
                  child: Text(
                    'Editar',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF737373),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_empresaNombre.isNotEmpty) ...[
            Text(
              '$_empresaNombre  â€¢  RTN: $_rtn',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: const Color(0xFFA3A3A3),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            'CAI: $_cai',
            style: GoogleFonts.dmMono(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rango: $_rangoInicio  â†’  $_rangoFin',
            style: GoogleFonts.dmMono(
              fontSize: 12,
              color: const Color(0xFFA3A3A3),
            ),
          ),
          if (_fechaLimite.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Vence: $_fechaLimite',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: vencido
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF737373),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final wide = MediaQuery.of(context).size.width >= 600;
    return GridView.count(
      crossAxisCount: wide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: wide ? 2.6 : 1.5,
      children: [
        _buildStatCard(
          'Facturas Hoy',
          '$_facturasHoy',
          Icons.today_rounded,
          const Color(0xFF3B82F6),
        ),
        _buildStatCard(
          'Total Hoy',
          'L.${_formatNumber(_totalHoy)}',
          Icons.payments_rounded,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Total Facturas',
          '$_totalFacturas',
          Icons.receipt_long_rounded,
          const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          'Monto Total',
          'L.${_formatNumber(_montoTotal)}',
          Icons.account_balance_wallet_rounded,
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
    final wide = MediaQuery.of(context).size.width >= 600;

    if (wide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      fontSize: 15,
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
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: const Color(0xFF737373),
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionRow(
          icon: Icons.add_circle_outline_rounded,
          title: 'Nueva Factura',
          subtitle: 'Crear factura con CAI y correlativo automático',
          color: const Color(0xFF10B981),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FacturaForm()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          icon: Icons.list_alt_rounded,
          title: 'Ver Facturas',
          subtitle: 'Lista completa de facturas emitidas',
          color: const Color(0xFF3B82F6),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FacturaList()),
            );
            _cargarDatos();
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          icon: Icons.people_outline_rounded,
          title: 'Clientes',
          subtitle: 'Gestionar clientes y RTN',
          color: const Color(0xFFF59E0B),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClienteForm()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          icon: Icons.analytics_outlined,
          title: 'Reportes',
          subtitle: 'Reportes diarios, mensuales y por cliente',
          color: const Color(0xFF8B5CF6),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportesScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
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

  Widget _buildDocumentTypes() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          _buildDocTypeRow(
            'Factura',
            'Documento fiscal principal',
            Icons.receipt_long_rounded,
            const Color(0xFF10B981),
          ),
          const Divider(color: Color(0xFF262626), height: 16),
          _buildDocTypeRow(
            'Nota de Crédito',
            'Devoluciones y anulaciones',
            Icons.undo_rounded,
            const Color(0xFF3B82F6),
          ),
          const Divider(color: Color(0xFF262626), height: 16),
          _buildDocTypeRow(
            'Nota de Débito',
            'Ajustes al alza',
            Icons.redo_rounded,
            const Color(0xFFF59E0B),
          ),
          const Divider(color: Color(0xFF262626), height: 16),
          _buildDocTypeRow(
            'Factura Exportación',
            'Ventas al exterior',
            Icons.public_rounded,
            const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildDocTypeRow(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
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
      ],
    );
  }

  Widget _buildISVSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          _buildISVRow(
            'ISV 15% (Bienes)',
            'L.${_formatNumber(_montoTotal * 0.15)}',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _buildISVRow(
            'ISV 18% (Bebidas/Tabaco)',
            'L.${_formatNumber(_montoTotal * 0.03)}',
            const Color(0xFFF59E0B),
          ),
          const Divider(color: Color(0xFF262626), height: 16),
          _buildISVRow(
            'Total ISV a declarar',
            'L.${_formatNumber(_montoTotal * 0.18)}',
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildISVRow(String label, String value, Color color) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFFA3A3A3),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.dmMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarConfiguracion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SarConfigScreen()),
    );
    _cargarDatos();
  }

  String _formatNumber(double number) {
    if (number == number.roundToDouble() && number < 1000000) {
      return number
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return number
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
