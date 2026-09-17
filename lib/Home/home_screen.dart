import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Auth/login.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Contabilidad/contabilidad_home.dart';
import 'package:portal_pilot_app/Modules/Facturacion/facturacion_home.dart';
import 'package:portal_pilot_app/Modules/Inventario/inventario_home.dart';
import 'package:portal_pilot_app/Modules/RRHH/rrhh_home.dart';
import 'package:portal_pilot_app/Modules/CRM/crm_home.dart';
import 'package:portal_pilot_app/Modules/POS/pos_home.dart';
import 'package:portal_pilot_app/Modules/Comercial/comercial_home.dart';
import 'package:portal_pilot_app/Modules/Membresias/membresia_home.dart';
import 'package:portal_pilot_app/Modules/CanalModerno/canal_moderno_home.dart';
import 'package:portal_pilot_app/Modules/Cotizaciones/cotizaciones_home.dart';
import 'package:portal_pilot_app/Modules/ComprasProveedores/compras_proveedores_home.dart';
import 'package:portal_pilot_app/Modules/SectorRetail/sector_retail_home.dart';
import 'package:portal_pilot_app/Modules/CanalTradicional/canal_tradicional_home.dart';
import 'package:portal_pilot_app/Modules/Settings/settings_home.dart';
import 'package:portal_pilot_app/Modules/Analytics/analytics_home.dart';
import 'package:portal_pilot_app/Modules/ChatIA/chat_ia_home.dart';
import 'package:portal_pilot_app/Modules/Soporte/soporte_home.dart';
import 'package:portal_pilot_app/Modules/SupplyChain/supply_chain_home.dart';
import 'package:portal_pilot_app/Modules/CRMAdvanced/crm_advanced_home.dart';
import 'package:portal_pilot_app/Modules/FiscalAdvanced/fiscal_advanced_home.dart';
import 'package:portal_pilot_app/Modules/Seguridad/seguridad_home.dart';
import 'package:portal_pilot_app/Modules/MultiEmpresa/multi_empresa_home.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';
import 'package:portal_pilot_app/Shared/services/background_service.dart';
import 'package:portal_pilot_app/Shared/services/connectivity_service.dart';
import 'package:portal_pilot_app/Shared/services/haptic_service.dart';
import 'package:portal_pilot_app/Shared/services/offline_sync_service.dart';
import 'package:portal_pilot_app/Shared/widgets/refresh_wrapper.dart';
import 'package:portal_pilot_app/Shared/widgets/page_transitions.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';
import 'package:portal_pilot_app/Home/multi_area_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _userName = '';
  String _empresaCodigo = '';
  String _empresaNombre = '';
  List<String> _modulosAsignados = [];
  List<Modulo> _modulosDisponibles = [];
  final TextEditingController _moduleSearchController = TextEditingController();
  int _mobileNavIndex = 0;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    AuthController.instance.addListener(_onAuthChanged);
    MultiAreaConfig.instance.addListener(_onMultiAreaChanged);
    // Redibuja el panel cuando cambia el tema (claro/oscuro/sistema).
    appThemeNotifier.addListener(_onThemeChanged);
    _loadUserData();
    _initializeServices();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      if (mounted && now.hour != _currentTime.hour) {
        setState(() => _currentTime = now);
      }
    });
    
    // Escuchar cambios de conectividad
    _connectivitySubscription = ConnectivityService.instance.connectivityStream.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    try {
      await HapticService.instance.initialize();
      await OfflineSyncService.instance.initialize();
      
      // Escuchar estado de sincronización
      _syncStatusSubscription = OfflineSyncService.instance.syncStatusStream.listen((status) {
        if (mounted) {
          // Mostrar indicador de sincronización si es necesario
          debugPrint('🔄 Sync status: ${status.message}');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error inicializando servicios: $e');
    }
  }

  Future<void> _refreshData() async {
    HapticService.instance.lightImpact();
    
    // Cargar datos frescos
    await _loadUserData();
    
    // Forzar sincronización si hay operaciones pendientes
    if (OfflineSyncService.instance.hasPendingSync) {
      try {
        await OfflineSyncService.instance.forceSync();
        HapticService.instance.success();
      } catch (e) {
        HapticService.instance.error();
      }
    }
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthChanged);
    MultiAreaConfig.instance.removeListener(_onMultiAreaChanged);
    appThemeNotifier.removeListener(_onThemeChanged);
    _fadeController.dispose();
    _moduleSearchController.dispose();
    _clockTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() => _applySession());
  }

  void _onMultiAreaChanged() {
    if (mounted) setState(() => _applySession());
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Seguro que deseas salir de tu cuenta?',
          style: TextStyle(color: Color(0xFFA3A3A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFFA3A3A3)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Salir',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await AuthController.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadUserData() async {
    await AuthController.instance.restore();
    await MultiAreaConfig.instance.cargar();
    if (mounted) {
      setState(() => _applySession());
    }
  }

  void _applySession() {
    _userName = AuthController.instance.nombreCompleto;
    _empresaCodigo = AuthController.instance.empresaCodigo;
    _empresaNombre = AuthController.instance.empresaNombre.isNotEmpty
        ? AuthController.instance.empresaNombre
        : _empresaCodigo;
    if (AuthController.instance.esRoot) {
      _modulosAsignados = Modulo.modulosDisponibles.map((m) => m.id).toList();
    } else {
      _modulosAsignados = AuthController.instance.modulos.isNotEmpty
          ? AuthController.instance.modulos
          : ['facturacion', 'inventario', 'crm'];
    }

    _modulosDisponibles = Modulo.modulosDisponibles
        .where((m) => _modulosAsignados.contains(m.id))
        .toList();

    if (_modulosDisponibles.isEmpty) {
      _modulosDisponibles = Modulo.modulosDisponibles
          .where((m) => m.id == 'chat_ia')
          .toList();
    }

    // Multi-área: filtra por feature flags de la empresa (configuración admin).
    if (MultiAreaConfig.instance.inicializado) {
      final visibles = Modulo.modulosDisponibles.where((m) {
        return _modulosAsignados.contains(m.id) &&
            MultiAreaConfig.instance.moduloActivo(m.id);
      }).toList();
      _modulosDisponibles = visibles;
    }

    // Gateo por plan: oculta módulos cuya feature no esté contratada.
    _modulosDisponibles = _modulosDisponibles.where((m) {
      final required = moduloFeatureRequerida[m.id];
      return required == null || AuthController.instance.tieneFeature(required);
    }).toList();

    if (_modulosDisponibles.isEmpty) {
      _modulosDisponibles = Modulo.modulosDisponibles
          .where((m) => m.id == 'chat_ia')
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              () => _refreshData(),
            const SingleActivator(LogicalKeyboardKey.f5): () => _refreshData(),
          const SingleActivator(LogicalKeyboardKey.f1): _openSupport,
          for (var index = 0; index < 9; index++)
            SingleActivator(
              LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + index),
              control: true,
            ): () => _openModuleByShortcut(index),
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.bgPrimary,
          drawer: isMobile ? _buildMobileDrawer() : null,
          body: Stack(
            children: [
              // Fondo adaptativo según dispositivo y tema
              Positioned.fill(
                child: BackgroundService.instance.buildBackground(
                  context: context,
                  isDark: appThemeNotifier.isDark,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshWrapper(
                    onRefresh: _refreshData,
                    child: _buildScrollView(isMobile),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
        ),
      ),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SoporteHome()),
    );
  }

  void _openModuleByShortcut(int index) {
    if (index < _filteredModules.length) {
      _openModule(_filteredModules[index]);
    }
  }

  List<Modulo> get _filteredModules {
    final query = _moduleSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _modulosDisponibles;
    return _modulosDisponibles.where((modulo) {
      return modulo.nombre.toLowerCase().contains(query) ||
          modulo.descripcion.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildModuleSearch(bool isMobile) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return TextField(
      controller: _moduleSearchController,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.dmSans(fontSize: 13, color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: 'Buscar módulos...',
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: palette.textDim),
        prefixIcon: Icon(Icons.search_rounded, color: palette.brandOnSurface, size: 20),
        suffixIcon: _moduleSearchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: Icon(Icons.close_rounded, color: palette.textMuted, size: 18),
                onPressed: () {
                  _moduleSearchController.clear();
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: palette.cardColor.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.brand, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final hour = _currentTime.hour;
    String greeting = 'Buenos días';
    if (hour >= 12 && hour < 19) greeting = 'Buenas tardes';
    if (hour >= 19) greeting = 'Buenas noches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          // Barra superior móvil: identidad a la izquierda, acciones a la derecha.
          Row(
            children: [
              Image.asset(
                'assets/img/robot_logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal Pilot',
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                    ),
                    _headerPill(
                      palette: palette,
                      color: _isOnline ? palette.successGreen : palette.errorRed,
                      icon: _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      label: _isOnline ? 'Online' : 'Offline',
                    ),
                  ],
                ),
              ),
              _headerIconButton(
                palette: palette,
                tooltip: 'Menú',
                icon: Icons.menu_rounded,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                palette: palette,
                tooltip: appThemeNotifier.isDark ? 'Modo claro' : 'Modo oscuro',
                icon: appThemeNotifier.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                onPressed: () async {
                  HapticService.instance.lightImpact();
                  await appThemeNotifier.toggle();
                },
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                palette: palette,
                tooltip: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onPressed: () => _handleLogout(context),
              ),
            ],
          ),
        ] else ...[
          // Desktop: fila de identidad + acciones
          Row(
            children: [
              Image.asset(
                'assets/img/robot_logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal Pilot',
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _empresaNombre.isNotEmpty ? _empresaNombre : _empresaCodigo,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: palette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _headerIconButton(
                palette: palette,
                tooltip: appThemeNotifier.isDark ? 'Modo claro' : 'Modo oscuro',
                icon: appThemeNotifier.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                onPressed: () async {
                  HapticService.instance.lightImpact();
                  await appThemeNotifier.toggle();
                },
              ),
              const SizedBox(width: 12),
              if (AuthController.instance.esRoot) ...[
                _headerIconButton(
                  palette: palette,
                  tooltip: 'Configuración Multi-Área',
                  icon: Icons.settings_rounded,
                  onPressed: () => _openMultiAreaConfig(),
                ),
                const SizedBox(width: 12),
              ],
              _headerIconButton(
                palette: palette,
                tooltip: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onPressed: () => _handleLogout(context),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        Text(
          '$greeting, ${_userName.split(' ').first}',
          style: GoogleFonts.syne(
            fontSize: isMobile ? 32 : 42,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '¿Qué módulo deseas usar hoy?',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: palette.textMuted,
          ),
        ),
      ],
    );
  }

  /// Píldora de estado (Online/Offline) del encabezado.
  Widget _headerPill({
    required ThemePalette palette,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de icono estándar del encabezado — funciona en claro y oscuro.
  /// Usa constraints compactas para que quede alineado con la fila (44px).
  Widget _headerIconButton({
    required ThemePalette palette,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderLight),
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, color: palette.brandOnSurface, size: 19),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollView(bool isMobile) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = isMobile ? 2 : 3;
    final isPortrait = size.height > size.width;
    final gridWidth = size.width - (isMobile ? 40 : 96);
    final cellWidth = (gridWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
    final cellHeight = !isMobile
        ? (cellWidth / 1.4).clamp(220.0, 340.0)
        : (cellWidth / (isPortrait ? 0.9 : 1.2)).clamp(180.0, 260.0);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 20 : 48,
            isMobile ? 24 : 40,
            isMobile ? 20 : 48,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(isMobile),
              if (AuthController.instance.soloLectura) ...[
                const SizedBox(height: 16),
                _buildReadOnlyBanner(isMobile),
              ],
              const SizedBox(height: 24),
              _buildModuleSearch(isMobile),
              const SizedBox(height: 32),
              _buildModulosHeader(isMobile),
            ]),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 48,
            vertical: 20,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: cellHeight,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                    _buildModuleCard(_filteredModules[index], isMobile),
                  childCount: _filteredModules.length,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 20 : 48,
            20,
            isMobile ? 20 : 48,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _buildQuickActions(isMobile)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 20 : 48,
            40,
            isMobile ? 20 : 48,
            isMobile ? 100 : 40, // Más espacio en móvil para la barra de navegación
          ),
          sliver: SliverToBoxAdapter(child: _buildFooter()),
        ),
      ],
    );
  }

  Widget _buildReadOnlyBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7F1D1D),
            const Color(0xFFB91C1C).withValues(alpha: 0.85),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prueba vencida · Modo solo lectura',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Puedes consultar y exportar tus datos, pero no registrar movimientos nuevos. Renueva tu plan para continuar operando.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulosHeader(bool isMobile) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.apps_rounded,
                color: palette.brandOnSurface,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'TUS MÓDULOS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: palette.textMuted,
                  letterSpacing: 1.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: palette.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_filteredModules.length} visibles',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: palette.isDark
                      ? palette.successGreen
                      : palette.successGreenDeep,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (MultiAreaConfig.instance.inicializado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MultiAreaConfig.instance.areaInfo.color.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MultiAreaConfig.instance.areaInfo.icono,
                      color: MultiAreaConfig.instance.areaInfo.color,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      MultiAreaConfig.instance.areaInfo.nombre,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MultiAreaConfig.instance.areaInfo.color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
  }

  Widget _buildModuleCard(Modulo modulo, bool isMobile) {
    return RepaintBoundary(
      child: ModuleCard(
        modulo: modulo,
        isMobile: isMobile,
        onTap: () => _openModule(modulo),
      ),
    );
  }

  Future<void> _openMultiAreaConfig() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MultiAreaConfigScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    await _loadUserData();
  }

  void _openModule(Modulo modulo) {
    // Haptic feedback
    HapticService.instance.mediumImpact();

    Widget destination;

    switch (modulo.id) {
      case 'contabilidad':
        destination = ContabilidadHome();
        break;
      case 'facturacion':
        destination = FacturacionHome();
        break;
      case 'inventario':
        destination = const InventarioHome();
        break;
      case 'rrhh':
        destination = const RrhhHome();
        break;
      case 'crm':
        destination = const CrmHome();
        break;
      case 'pos':
        destination = const PosHome();
        break;
      case 'comercial':
        destination = const ComercialHome();
        break;
      case 'membresias':
        destination = const MembresiaHome();
        break;
      case 'canal_moderno':
        destination = const CanalModernoHome();
        break;
      case 'cotizaciones':
        destination = const CotizacionesHome();
        break;
      case 'compras_proveedores':
        destination = const ComprasProveedoresHome();
        break;
      case 'sector_retail':
        destination = const SectorRetailHome();
        break;
      case 'canal_tradicional':
        destination = const CanalTradicionalHome();
        break;
      case 'settings':
        destination = const SettingsHome();
        break;
      case 'chat_ia':
        destination = const ChatIAHome();
        break;
      case 'analytics':
        destination = const AnalyticsHome();
        break;
      case 'supply_chain':
        destination = const SupplyChainHome();
        break;
      case 'crm_advanced':
        destination = const CRMAdvancedHome();
        break;
      case 'fiscal_advanced':
        destination = const FiscalAdvancedHome();
        break;
      case 'seguridad':
        destination = const SeguridadHome();
        break;
      case 'multi_empresa':
        destination = const MultiEmpresaHome();
        break;
      default:
        HapticService.instance.error();
        PPNotifications.info(
          context,
          '${modulo.nombre} llegará en una próxima actualización.',
          title: modulo.nombre,
        );
        return;
    }

    Navigator.of(context).push(
      SlideFromRightTransition(child: destination),
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCESO RÁPIDO',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: palette.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                palette,
                'Estado del Sistema',
                'Todos los módulos operativos',
                Icons.check_circle_rounded,
                palette.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                palette,
                'Soporte',
                'Centro de ayuda con IA',
                Icons.help_outline_rounded,
                palette.infoBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SoporteHome()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    ThemePalette palette,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.cardColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
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
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: palette.textMuted,
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

  Widget _buildFooter() {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Todos los sistemas operativos',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 Portal Pilot · v2.0.0',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: palette.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.cardColor,
            border: Border(top: BorderSide(color: palette.borderLight)),
            boxShadow: [
              BoxShadow(
                color: palette.isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _buildMobileNavButton(palette, icon: Icons.home_rounded, label: 'Inicio', isSelected: _mobileNavIndex == 0, onTap: () => setState(() => _mobileNavIndex = 0))),
              Expanded(child: _buildMobileNavButton(palette, icon: Icons.settings_rounded, label: 'Config', isSelected: _mobileNavIndex == 1, onTap: () { setState(() => _mobileNavIndex = 1); _openSettings(); })),
              _buildPortalCoreButton(palette),
              Expanded(child: _buildMobileNavButton(palette, icon: Icons.support_agent_rounded, label: 'Soporte', isSelected: _mobileNavIndex == 2, onTap: () { setState(() => _mobileNavIndex = 2); Navigator.push(context, MaterialPageRoute(builder: (_) => const SoporteHome())); })),
              Expanded(child: _buildMobileNavButton(palette, icon: Icons.auto_awesome_rounded, label: 'Navi', isSelected: _mobileNavIndex == 3, onTap: () { setState(() => _mobileNavIndex = 3); _openModule(Modulo.modulosDisponibles.firstWhere((m) => m.id == 'chat_ia')); })),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(SlideFromRightTransition(child: const SettingsHome()));
  }

  /// Botón central del nav móvil: abre el Núcleo (drawer con todos los módulos).
  /// Centrado verticalmente, sin márgenes que lo desalineen.
  Widget _buildPortalCoreButton(ThemePalette palette) {
    return Tooltip(
      message: 'Núcleo Portal Pilot — todos los módulos',
      child: GestureDetector(
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD16BF0), Color(0xFF5C1A7E)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x99B94DDC), blurRadius: 16, spreadRadius: 1)],
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 25),
        ),
      ),
    );
  }

  Widget _buildMobileNavButton(
    ThemePalette palette, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.brand.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? palette.brandOnSurface : palette.textMuted,
              size: 21,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? palette.brandOnSurface : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Drawer(
      backgroundColor: palette.sidebarColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header del drawer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB94DDC), Color(0xFF6D28D9)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                          'assets/img/robot_logo.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Portal Pilot',
                              style: GoogleFonts.syne(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _empresaNombre.isNotEmpty ? _empresaNombre : _empresaCodigo,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline ? 'Conectado' : 'Sin conexión',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Lista de módulos
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'MÓDULOS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: palette.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  ..._modulosDisponibles.map((modulo) => _buildDrawerItem(
                    icon: modulo.icono,
                    title: modulo.nombre,
                    color: modulo.color,
                    onTap: () {
                      Navigator.pop(context);
                      _openModule(modulo);
                    },
                  )),

                  Divider(height: 32, color: palette.borderLight),

                  // Opciones adicionales
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'SISTEMA',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: palette.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Configuración',
                    color: palette.brand,
                    onTap: () {
                      Navigator.pop(context);
                      _openModule(_modulosDisponibles.firstWhere(
                        (m) => m.id == 'settings',
                        orElse: () => _modulosDisponibles.first,
                      ));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.support_agent_rounded,
                    title: 'Soporte',
                    color: palette.infoBlue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SoporteHome()),
                      );
                    },
                  ),
                  if (AuthController.instance.esRoot)
                    _buildDrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Multi-Área',
                      color: palette.successGreen,
                      onTap: () {
                        Navigator.pop(context);
                        _openMultiAreaConfig();
                      },
                    ),
                ],
              ),
            ),
            
            // Footer con logout
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.borderLight, width: 1),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: palette.errorRed,
                ),
                title: Text(
                  'Cerrar sesión',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.errorRed,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ThemePalette(isDark: appThemeNotifier.isDark).textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: ThemePalette(isDark: appThemeNotifier.isDark).textMuted,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}

class ModuleCard extends StatefulWidget {
  final Modulo modulo;
  final bool isMobile;
  final VoidCallback onTap;

  const ModuleCard({
    super.key,
    required this.modulo,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _isHovered = false;

  static final Map<int, TextStyle> _titleCache = {};

  TextStyle _getTitleStyle(double fontSize, ThemePalette palette) {
    final key = (fontSize.toInt() << 1) | (palette.isDark ? 1 : 0);
    return _titleCache.putIfAbsent(key, () => GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: palette.textPrimary,
      letterSpacing: -0.3,
    ));
  }

  TextStyle _descStyle(ThemePalette palette) => GoogleFonts.dmSans(
    fontSize: 12,
    color: palette.textMuted,
    height: 1.4,
  );

  TextStyle _getActionStyle(Color color) {
    return GoogleFonts.dmSans(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    // Acentos legibles en ambos temas (los vivos se oscurecen en claro).
    final accent = palette.isDark
        ? widget.modulo.color
        : Color.lerp(widget.modulo.color, Colors.black, 0.18)!;
    final pressed = _isHovered;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: pressed ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(widget.isMobile ? 18 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette.isDark
                        ? [
                            pressed ? const Color(0xFF1B1B22) : const Color(0xFF141219),
                            const Color(0xFF0C0A12),
                          ]
                        : [
                            Colors.white,
                            pressed ? const Color(0xFFF7F2FC) : const Color(0xFFFBF9FE),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: pressed ? 0.55 : 0.28),
                    width: pressed ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.isDark
                          ? accent.withValues(alpha: pressed ? 0.22 : 0.07)
                          : accent.withValues(alpha: pressed ? 0.14 : 0.06),
                      blurRadius: pressed ? 24 : 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.75),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(widget.modulo.icono, color: Colors.white, size: 22),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.isDark
                                ? palette.successGreen
                                : palette.successGreenDeep,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (palette.isDark
                                        ? palette.successGreen
                                        : palette.successGreenDeep)
                                    .withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.modulo.nombre,
                          style: _getTitleStyle(widget.isMobile ? 16 : 18, palette),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.modulo.descripcion,
                          style: _descStyle(palette),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Abrir', style: _getActionStyle(accent)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: accent, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
