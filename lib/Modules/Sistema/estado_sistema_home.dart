import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/module_manager.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/connectivity_service.dart';
import 'package:portal_pilot_app/Shared/services/offline_sync_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_module_scaffold.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_stats_card.dart';

const _estadoColor = Color(0xFF22C55E);

class EstadoSistemaHome extends StatefulWidget {
  const EstadoSistemaHome({super.key});

  @override
  State<EstadoSistemaHome> createState() => _EstadoSistemaHomeState();
}

class _EstadoSistemaHomeState extends State<EstadoSistemaHome> {
  bool _cargando = true;
  bool _apiOk = false;
  bool _internetOk = true;
  bool _sincronizando = false;
  int _pendientes = 0;
  String _apiMensaje = 'Consultando...';
  String _syncMensaje = 'Idle';

  // Datos reales de Supabase (vía API de producción).
  String _planNombre = '';
  int _usuariosTotal = 0;
  int _usuariosActivos = 0;
  int _usuariosLimite = 0;
  int _tokensMes = 0;
  int _tokensLimite = 0;
  double _almacenGb = 0;
  double _almacenBytes = 0;
  bool _almacenMedido = false;
  int _almacenLimite = 0;
  int _facturasTotal = 0;
  double _facturasMesMonto = 0;
  String _soporte = '';
  String _sla = '';
  List<String> _modulosActivos = [];

  String _tenantNombre = '';
  String _tenantLogo = '';
  String _tenantBanner = '';

  static const String _cacheKey = 'estado_sistema_cache';

  Map<String, dynamic> _m(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
  int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
  double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  void initState() {
    super.initState();
    _cargarLocales(); // Pinta cache al instante
    _cargar();        // Luego refresca de API en background
  }

  /// Carga cache local: pinta la UI al instante sin skeleton.
  Future<void> _cargarLocales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _planNombre = _s(data['planNombre']);
            _usuariosTotal = _i(data['usuariosTotal']);
            _usuariosActivos = _i(data['usuariosActivos']);
            _usuariosLimite = _i(data['usuariosLimite']);
            _tokensMes = _i(data['tokensMes']);
            _tokensLimite = _i(data['tokensLimite']);
            _almacenGb = _d(data['almacenGb']);
            _almacenBytes = _d(data['almacenBytes']);
            _almacenMedido = data['almacenMedido'] == true;
            _almacenLimite = _i(data['almacenLimite']);
            _facturasTotal = _i(data['facturasTotal']);
            _facturasMesMonto = _d(data['facturasMesMonto']);
            _soporte = _s(data['soporte']);
            _sla = _s(data['sla']);
            _modulosActivos = (data['modulosActivos'] as List?)?.cast<String>() ?? [];
            _tenantNombre = _s(data['tenantNombre']);
            _tenantLogo = _s(data['tenantLogo']);
            _tenantBanner = _s(data['tenantBanner']);
            _cargando = false; // Ya no muestra skeleton
          });
        }
      }
    } catch (e) {
      debugPrint('[EstadoSistema] Cache load error: $e');
    }
  }

  /// Guarda snapshot en SharedPreferences para próxima apertura instantánea.
  Future<void> _guardarCache({
    required String planNombre,
    required int usuariosTotal,
    required int usuariosActivos,
    required int usuariosLimite,
    required int tokensMes,
    required int tokensLimite,
    required double almacenGb,
    required double almacenBytes,
    required bool almacenMedido,
    required int almacenLimite,
    required int facturasTotal,
    required double facturasMesMonto,
    required String soporte,
    required String sla,
    required List<String> modulosActivos,
    required String tenantNombre,
    required String tenantLogo,
    required String tenantBanner,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({
        'planNombre': planNombre,
        'usuariosTotal': usuariosTotal,
        'usuariosActivos': usuariosActivos,
        'usuariosLimite': usuariosLimite,
        'tokensMes': tokensMes,
        'tokensLimite': tokensLimite,
        'almacenGb': almacenGb,
        'almacenBytes': almacenBytes,
        'almacenMedido': almacenMedido,
        'almacenLimite': almacenLimite,
        'facturasTotal': facturasTotal,
        'facturasMesMonto': facturasMesMonto,
        'soporte': soporte,
        'sla': sla,
        'modulosActivos': modulosActivos,
        'tenantNombre': tenantNombre,
        'tenantLogo': tenantLogo,
        'tenantBanner': tenantBanner,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[EstadoSistema] Cache save error: $e');
    }
  }

  Future<void> _cargar() async {
    try {
      final internOk = ConnectivityService.instance.isOnline;
      final pendientes = OfflineSyncService.instance.pendingOperationsCount;
      final sincronizando = OfflineSyncService.instance.isSyncing;

      final api = ApiService.instance;
      final codigo = api.empresaCodigo;

      bool apiOk = false;
      String apiMensaje = 'Sin sesión de empresa';
      Map<String, dynamic> stats = const {};
      List<String> modulosActivos = [];
      String tenantNombre = '';
      String tenantLogo = '';
      String tenantBanner = '';

      if (codigo.isNotEmpty && codigo != 'ROOT') {
        final resultados = await Future.wait([
          api.get('/api/tenant/$codigo/stats'),
          api.get('/api/tenant/modules'),
          api.get('/api/tenant/$codigo'),
        ]);
        final statsRes = resultados[0];
        final modulosRes = resultados[1];
        final tenantRes = resultados[2];

        apiOk = api.isSuccess(statsRes);
        apiMensaje = apiOk ? 'Conectado' : (api.getError(statsRes) ?? 'Respuesta inesperada');
        if (apiOk) {
          stats = _m(statsRes['stats']);
        }
        if (api.isSuccess(modulosRes) && modulosRes['modulos_activos'] is List) {
          modulosActivos = (modulosRes['modulos_activos'] as List)
              .map((e) => e.toString())
              .toList();
        }
        if (api.isSuccess(tenantRes)) {
          final prev = _m(tenantRes['preview']);
          tenantNombre = _s(prev['name']);
          tenantLogo = _s(prev['logo']);
          tenantBanner = _s(prev['banner']);
        }
      }

      final usuarios = _m(stats['usuarios']);
      final tokens = _m(stats['tokens']);
      final almacen = _m(stats['almacenamiento']);
      final facturas = _m(stats['facturas']);

      final planNombre = _s(stats['planNombre']).isNotEmpty
          ? _s(stats['planNombre'])
          : _s(stats['plan']);
      final usuariosTotal = _i(usuarios['total']);
      final usuariosActivos = _i(usuarios['activos']);
      final usuariosLimite = _i(usuarios['limite']);
      final tokensMes = _i(tokens['mes']) == 0 ? _i(tokens['usados']) : _i(tokens['mes']);
      final tokensLimite = _i(tokens['limite']);
      final almacenMedido = almacen['gbUsados'] != null;
      final almacenGb = _d(almacen['gbUsados']);
      final almacenBytes = _d(almacen['bytesUsados']);
      final almacenLimite = _i(almacen['limite']);
      final facturasTotal = _i(facturas['total']);
      final facturasMesMonto = _d(facturas['mesMonto']);
      final soporte = _s(stats['soporte']);
      final sla = _s(stats['sla']);

      // Guardar cache para próxima apertura instantánea
      await _guardarCache(
        planNombre: planNombre,
        usuariosTotal: usuariosTotal,
        usuariosActivos: usuariosActivos,
        usuariosLimite: usuariosLimite,
        tokensMes: tokensMes,
        tokensLimite: tokensLimite,
        almacenGb: almacenGb,
        almacenBytes: almacenBytes,
        almacenMedido: almacenMedido,
        almacenLimite: almacenLimite,
        facturasTotal: facturasTotal,
        facturasMesMonto: facturasMesMonto,
        soporte: soporte,
        sla: sla,
        modulosActivos: modulosActivos,
        tenantNombre: tenantNombre,
        tenantLogo: tenantLogo,
        tenantBanner: tenantBanner,
      );

      if (!mounted) return;
      setState(() {
        _internetOk = internOk;
        _pendientes = pendientes;
        _sincronizando = sincronizando;
        _apiOk = apiOk;
        _apiMensaje = apiMensaje;
        _syncMensaje = sincronizando
            ? 'Sincronizando...'
            : (pendientes > 0 ? '$pendientes cambios pendientes' : 'Al día');

        _planNombre = planNombre;
        _usuariosTotal = usuariosTotal;
        _usuariosActivos = usuariosActivos;
        _usuariosLimite = usuariosLimite;
        _tokensMes = tokensMes;
        _tokensLimite = tokensLimite;
        _almacenGb = almacenGb;
        _almacenBytes = almacenBytes;
        _almacenMedido = almacenMedido;
        _almacenLimite = almacenLimite;
        _facturasTotal = facturasTotal;
        _facturasMesMonto = facturasMesMonto;
        _soporte = soporte;
        _sla = sla;
        _modulosActivos = modulosActivos;
        _tenantNombre = tenantNombre;
        _tenantLogo = tenantLogo;
        _tenantBanner = tenantBanner;

        _cargando = false;
      });
    } catch (e) {
      debugPrint('[EstadoSistema] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _sincronizarAhora() async {
    SyncService.instance.syncNowIfOnline();
    await Future.delayed(const Duration(milliseconds: 400));
    await _cargar();
  }

  String _fmt(int n) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}$b';
  }

  String _fmtBytes(double bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  String _titulo(String raw) {
    if (raw.isEmpty) return 'Sin plan';
    final lower = raw.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _nombreModulo(String id) {
    for (final m in Modulo.modulosDisponibles) {
      if (m.id == id) return m.nombre;
    }
    return id
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final auth = AuthController.instance;

    return PPModuleScaffold(
      moduleId: 'estado_sistema',
      screenTitle: 'Estado del Sistema',
      moduleIcon: Icons.monitor_heart_rounded,
      moduleColor: _estadoColor,
      onRefresh: _cargar,
      loading: _cargando,
      child: ListView(
        padding: MobileUtils.getPagePadding(context),
        children: [
          _buildEmpresaCard(palette, auth),
          const SizedBox(height: 18),
          PPStatsGrid(
            cards: [
              PPStatsCard(
                label: 'API',
                value: _apiOk ? 'Operativa' : 'Offline',
                icon: Icons.cloud_done_rounded,
                color: _apiOk ? palette.successGreen : const Color(0xFFEF4444),
              ),
              PPStatsCard(
                label: 'Plan',
                value: _titulo(_planNombre),
                icon: Icons.workspace_premium_rounded,
                color: _estadoColor,
              ),
              PPStatsCard(
                label: 'Usuarios',
                value: '$_usuariosActivos/$_usuariosLimite',
                icon: Icons.group_rounded,
                color: palette.infoBlue,
              ),
              PPStatsCard(
                label: 'Tokens IA (mes)',
                value: _fmt(_tokensMes),
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSeccion(palette, 'USO DE RECURSOS', [
            _rowRecurso(
              palette,
              icono: Icons.group_rounded,
              nombre: 'Usuarios',
              detalle: _usuariosTotal > _usuariosActivos
                  ? '$_usuariosActivos activos · $_usuariosTotal total · límite $_usuariosLimite'
                  : '$_usuariosActivos activos de $_usuariosLimite',
              usado: _usuariosActivos,
              limite: _usuariosLimite,
              color: palette.infoBlue,
            ),
            _rowRecurso(
              palette,
              icono: Icons.auto_awesome_rounded,
              nombre: 'Tokens IA (mes)',
              detalle: '${_fmt(_tokensMes)} de ${_fmt(_tokensLimite)} tokens',
              usado: _tokensMes,
              limite: _tokensLimite,
              color: const Color(0xFF8B5CF6),
            ),
            _rowRecurso(
              palette,
              icono: Icons.storage_rounded,
              nombre: 'Almacenamiento',
              detalle: _almacenMedido
                  ? '${_fmtBytes(_almacenBytes)} de $_almacenLimite GB'
                  : '(sin medir)',
              usado: (_almacenGb * 100).round(),
              limite: _almacenLimite * 100,
              color: const Color(0xFF0EA5E9),
            ),
            _rowRecurso(
              palette,
              icono: Icons.receipt_long_rounded,
              nombre: 'Facturas emitidas',
              detalle: _facturasMesMonto > 0
                  ? '$_facturasTotal documentos · L ${_fmt(_facturasMesMonto.round())} este mes'
                  : '$_facturasTotal documentos',
              usado: _facturasTotal,
              limite: 0,
              color: const Color(0xFFF59E0B),
            ),
          ]),
          const SizedBox(height: 18),
          _buildSeccion(palette, 'ESTADO DE SERVICIOS', [
            _rowServicio(
              palette,
              icono: _internetOk ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              nombre: 'Internet',
              detalle: _internetOk ? 'Conexión activa' : 'Sin conexión',
              ok: _internetOk,
            ),
            _rowServicio(
              palette,
              icono: _apiOk ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              nombre: 'API (portal-pilot.vercel.app)',
              detalle: _apiMensaje,
              ok: _apiOk,
            ),
            _rowServicio(
              palette,
              icono: _sincronizando
                  ? Icons.sync_rounded
                  : (_pendientes == 0
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded),
              nombre: 'Sincronización de datos',
              detalle: _syncMensaje,
              ok: _pendientes == 0 && !_sincronizando,
            ),
          ]),
          const SizedBox(height: 18),
          _buildSeccion(palette, 'MÓDULOS ACTIVOS (SUPABASE)', [
            _buildModulosChips(palette),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _sincronizarAhora,
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Sincronizar ahora'),
            ),
          ),
          if (_soporte.isNotEmpty || _sla.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Soporte: $_soporte${_sla.isNotEmpty ? ' · SLA $_sla' : ''}',
                style: GoogleFonts.dmSans(fontSize: 11, color: palette.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModulosChips(ThemePalette palette) {
    final ids = _modulosActivos.isNotEmpty
        ? _modulosActivos
        : ModuleManager.instance.activeAppModules.map((m) => m.id).toList();
    if (ids.isEmpty) {
      return Text(
        'Sin módulos activos registrados.',
        style: GoogleFonts.dmSans(fontSize: 12, color: palette.textMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ids.map((id) {
        Color color = _estadoColor;
        for (final m in ModuleManager.instance.activeAppModules) {
          if (m.id == id) {
            color = m.color;
            break;
          }
        }
        return Chip(
          backgroundColor: color.withValues(alpha: 0.14),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          avatar: Icon(Icons.apps_rounded, size: 16, color: color),
          label: Text(
            _nombreModulo(id),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmpresaCard(ThemePalette palette, AuthController auth) {
    final nombre = _tenantNombre.isNotEmpty
        ? _tenantNombre
        : (auth.empresaNombre.isNotEmpty
            ? auth.empresaNombre
            : auth.empresaCodigo);
    final codigo = auth.empresaCodigo;
    final tieneBanner = _tenantBanner.isNotEmpty;
    final textoPrincipal = tieneBanner ? Colors.white : palette.textPrimary;
    final textoSecundario = tieneBanner
        ? Colors.white.withValues(alpha: 0.85)
        : palette.textMuted;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderLight),
      ),
      child: Stack(
        children: [
          if (tieneBanner)
            Positioned.fill(
              child: Image.network(
                _tenantBanner,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (tieneBanner)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.42),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: tieneBanner
                            ? Colors.white.withValues(alpha: 0.18)
                            : _estadoColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tieneBanner
                              ? Colors.white.withValues(alpha: 0.4)
                              : _estadoColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _tenantLogo.isNotEmpty
                          ? Image.network(
                              _tenantLogo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                  Icons.business_rounded,
                                  color: _estadoColor, size: 22),
                            )
                          : const Icon(Icons.business_rounded,
                              color: _estadoColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textoPrincipal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            codigo,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: textoSecundario),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${auth.nombreCompleto} · ${auth.rol.isEmpty ? 'usuario' : auth.rol}',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: textoSecundario),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(ThemePalette palette, String titulo, List<Widget> hijos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: palette.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        ...hijos,
      ],
    );
  }

  Widget _rowRecurso(
    ThemePalette palette, {
    required IconData icono,
    required String nombre,
    required String detalle,
    required int usado,
    required int limite,
    required Color color,
  }) {
    final tieneLimite = limite > 0;
    final double pct = tieneLimite
        ? (usado / limite).clamp(0.0, 1.0)
        : (usado > 0 ? 1.0 : 0.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (tieneLimite)
                Text(
                  '${(pct * 100).round()}%',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detalle,
            style: GoogleFonts.dmSans(fontSize: 12, color: palette.textMuted),
          ),
          if (tieneLimite) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowServicio(
    ThemePalette palette, {
    required IconData icono,
    required String nombre,
    required String detalle,
    required bool ok,
  }) {
    final color = ok ? palette.successGreen : const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: GoogleFonts.dmSans(fontSize: 12, color: palette.textMuted),
                ),
              ],
            ),
          ),
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color, size: 18),
        ],
      ),
    );
  }
}
