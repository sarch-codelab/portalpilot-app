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
import 'package:portal_pilot_app/Shared/services/connectivity_service.dart';
import 'package:portal_pilot_app/Shared/services/haptic_service.dart';
import 'package:portal_pilot_app/Shared/services/offline_sync_service.dart';
import 'package:portal_pilot_app/Shared/widgets/refresh_wrapper.dart';
import 'package:portal_pilot_app/Shared/widgets/page_transitions.dart';
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

  Future<void> _initializeServices() async {
    try {
      await HapticService.instance.initialize();
      await OfflineSyncService.instance.initialize();
      
      // Escuchar estado de sincronización
      OfflineSyncService.instance.syncStatusStream.listen((status) {
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
    _fadeController.dispose();
    _moduleSearchController.dispose();
    _clockTimer?.cancel();
    _connectivitySubscription?.cancel();
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
              // Fondo original a pantalla completa, sin bordes
              Positioned.fill(
                child: Image.asset(
                  'img/fondos-img/fondo-panel-modulos.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
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
    return TextField(
      controller: _moduleSearchController,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar módulos...',
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF737373)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB94DDC), size: 20),
        suffixIcon: _moduleSearchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded, color: Color(0xFFA3A3A3), size: 18),
                onPressed: () {
                  _moduleSearchController.clear();
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: const Color(0xCC111111),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFB94DDC).withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFB94DDC).withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB94DDC), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final hour = _currentTime.hour;
    String greeting = 'Buenos días';
    if (hour >= 12 && hour < 19) greeting = 'Buenas tardes';
    if (hour >= 19) greeting = 'Buenas noches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          // Barra de acciones arriba (derecha)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isOnline 
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isOnline 
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x29FFFFFF)),
                ),
                child: Tooltip(
                  message: 'Menú',
                  child: IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: Color(0xFFB94DDC),
                      size: 18,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x29FFFFFF)),
                ),
                child: Tooltip(
                  message: 'Cambiar tema',
                  child: IconButton(
                    icon: Icon(
                      appThemeNotifier.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: const Color(0xFFB94DDC),
                      size: 16,
                    ),
                    onPressed: () async {
                      await appThemeNotifier.toggle();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x29FFFFFF)),
                ),
                child: Tooltip(
                  message: 'Cerrar sesión',
                  child: IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFB94DDC),
                      size: 18,
                    ),
                    onPressed: () => _handleLogout(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Robot centrado + Portal Pilot debajo
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/img/robot_logo.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                Text(
                  'Portal Pilot',
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ] else ...[
          // Desktop: row original
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
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _empresaNombre.isNotEmpty ? _empresaNombre : _empresaCodigo,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFFA3A3A3),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x29FFFFFF)),
                ),
                child: Tooltip(
                  message: 'Cambiar tema',
                  child: IconButton(
                    icon: Icon(
                      appThemeNotifier.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: const Color(0xFFB94DDC),
                      size: 16,
                    ),
                    onPressed: () async {
                      await appThemeNotifier.toggle();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (AuthController.instance.esRoot)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x29FFFFFF)),
                  ),
                  child: Tooltip(
                    message: 'Configuración Multi-Área',
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Color(0xFFB94DDC),
                        size: 18,
                      ),
                      onPressed: () => _openMultiAreaConfig(),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x29FFFFFF)),
                ),
                child: Tooltip(
                  message: 'Cerrar sesión',
                  child: IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFB94DDC),
                      size: 18,
                    ),
                    onPressed: () => _handleLogout(context),
                  ),
                ),
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
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '¿Qué módulo deseas usar hoy?',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: const Color(0xFFA3A3A3),
          ),
        ),
      ],
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

  Widget _buildModulosHeader(bool isMobile) {
    return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFB94DDC).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.apps_rounded,
                color: Color(0xFFB94DDC),
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
                  color: const Color(0xFFA3A3A3),
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
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_filteredModules.length} visibles',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${modulo.nombre} - Próximamente disponible'),
            backgroundColor: modulo.color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
    }

    Navigator.of(context).push(
      SlideFromRightTransition(child: destination),
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCESO RÁPIDO',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFA3A3A3),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Estado del Sistema',
                'Todos los módulos operativos',
                Icons.check_circle_rounded,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Soporte',
                'Centro de ayuda con IA',
                Icons.help_outline_rounded,
                const Color(0xFF3B82F6),
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
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x29FFFFFF)),
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
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFFA3A3A3),
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
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Todos los sistemas operativos',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: const Color(0xFFA3A3A3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 Portal Pilot · v2.0.0',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: const Color(0xFF525252),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            border: Border(top: BorderSide(color: const Color(0xFFB94DDC).withValues(alpha: 0.25))),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, -8))],
          ),
          child: Row(
            children: [
              Expanded(child: _buildMobileNavButton(icon: Icons.home_rounded, label: 'Inicio', isSelected: _mobileNavIndex == 0, onTap: () => setState(() => _mobileNavIndex = 0))),
              Expanded(child: _buildMobileNavButton(icon: Icons.settings_rounded, label: 'Config', isSelected: _mobileNavIndex == 1, onTap: () { setState(() => _mobileNavIndex = 1); _openSettings(); })),
              _buildPortalCoreButton(),
              Expanded(child: _buildMobileNavButton(icon: Icons.support_agent_rounded, label: 'Soporte', isSelected: _mobileNavIndex == 2, onTap: () { setState(() => _mobileNavIndex = 2); Navigator.push(context, MaterialPageRoute(builder: (_) => const SoporteHome())); })),
              Expanded(child: _buildMobileNavButton(icon: Icons.logout_rounded, label: 'Salir', isSelected: false, onTap: () => _handleLogout(context))),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(SlideFromRightTransition(child: const SettingsHome()));
  }

  Widget _buildPortalCoreButton() {
    return Tooltip(
      message: 'Núcleo Portal Pilot',
      child: GestureDetector(
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 58,
          height: 58,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD16BF0), Color(0xFF5C1A7E)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x99B94DDC), blurRadius: 18, spreadRadius: 2)],
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 27),
        ),
      ),
    );
  }

  Widget _buildMobileNavButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFB94DDC).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFB94DDC) : const Color(0xFFA3A3A3),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFB94DDC) : const Color(0xFFA3A3A3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF111111),
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
                        color: const Color(0xFFA3A3A3),
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
                  
                  const Divider(height: 32, color: Color(0xFF292929)),
                  
                  // Opciones adicionales
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'SISTEMA',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA3A3A3),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Configuración',
                    color: const Color(0xFFB94DDC),
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
                    color: const Color(0xFF3B82F6),
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
                      color: const Color(0xFF10B981),
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
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF292929), width: 1),
                ),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: Text(
                  'Cerrar sesión',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFEF4444),
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
          color: Colors.white,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: const Color(0xFFA3A3A3),
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
  static final TextStyle _descStyle = GoogleFonts.dmSans(
    fontSize: 12,
    color: Color(0xFFA3A3A3),
    height: 1.4,
  );

  TextStyle _getTitleStyle(double fontSize) {
    final key = fontSize.toInt();
    return _titleCache.putIfAbsent(key, () => GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.3,
    ));
  }

  TextStyle _getActionStyle(Color color) {
    return GoogleFonts.dmSans(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _isHovered ? 1.015 : 1.0,
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
                colors: [
                  _isHovered ? const Color(0xFF1B1B22) : const Color(0xFF111111),
                  const Color(0xFF0A0A0D),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.modulo.color.withValues(alpha: _isHovered ? 0.8 : 0.3),
                width: _isHovered ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.modulo.color.withValues(alpha: _isHovered ? 0.2 : 0.06),
                  blurRadius: _isHovered ? 26 : 12,
                  offset: const Offset(0, 8),
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
                            widget.modulo.color,
                            widget.modulo.color.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.modulo.color.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(widget.modulo.icono, color: Colors.white, size: 22),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x9910B981),
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
                      style: _getTitleStyle(widget.isMobile ? 16 : 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.modulo.descripcion,
                      style: _descStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Abrir', style: _getActionStyle(widget.modulo.color)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: widget.modulo.color, size: 16),
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
