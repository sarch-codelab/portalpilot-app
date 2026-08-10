import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Auth/login.dart';
import 'package:portal_pilot_app/Shared/models/modulo.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Educacion/educacion_home.dart';
import 'package:portal_pilot_app/Modules/Contabilidad/contabilidad_home.dart';
import 'package:portal_pilot_app/Modules/Facturacion/facturacion_home.dart';
import 'package:portal_pilot_app/Modules/Inventario/inventario_home.dart';
import 'package:portal_pilot_app/Modules/RRHH/rrhh_home.dart';
import 'package:portal_pilot_app/Modules/CRM/crm_home.dart';
import 'package:portal_pilot_app/Modules/POS/pos_home.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';
import 'package:portal_pilot_app/Home/multi_area_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _userName = '';
  String _empresaCodigo = '';
  String _empresaNombre = '';
  List<String> _modulosAsignados = [];
  List<Modulo> _modulosDisponibles = [];
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

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
    _loadUserData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthChanged);
    _fadeController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
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
    _modulosAsignados = AuthController.instance.modulos.isNotEmpty
        ? AuthController.instance.modulos
        : ['educacion'];

    _modulosDisponibles = Modulo.modulosDisponibles
        .where((m) => _modulosAsignados.contains(m.id))
        .toList();

    if (_modulosDisponibles.isEmpty) {
      _modulosDisponibles = Modulo.modulosDisponibles
          .where((m) => m.id == 'educacion')
          .toList();
    }

    // Multi-área: filtra por feature flags de la empresa (configuración admin).
    if (MultiAreaConfig.instance.inicializado) {
      final visibles = Modulo.modulosDisponibles.where((m) {
        return _modulosAsignados.contains(m.id) &&
            MultiAreaConfig.instance.moduloActivo(m.id);
      }).toList();
      if (visibles.isNotEmpty) {
        _modulosDisponibles = visibles;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  Colors.black,
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 48,
                  vertical: isMobile ? 24 : 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isMobile),
                    const SizedBox(height: 40),
                    _buildModulosGrid(isMobile),
                    const SizedBox(height: 40),
                    _buildQuickActions(isMobile),
                    const SizedBox(height: 40),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.blur_on_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Column(
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
                ),
                Text(
                  _empresaNombre.isNotEmpty ? _empresaNombre : _empresaCodigo,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFFA3A3A3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x29FFFFFF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    appThemeNotifier.isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: const Color(0xFF8B5CF6),
                    size: 16,
                  ),
                ],
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
                      color: Color(0xFF8B5CF6),
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
                    color: Color(0xFF8B5CF6),
                    size: 18,
                  ),
                  onPressed: () => _handleLogout(context),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildModulosGrid(bool isMobile) {
    final crossAxisCount = isMobile ? 2 : 3;
    final childAspectRatio = isMobile ? 1.2 : 1.4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.apps_rounded,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'TUS MÓDULOS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFA3A3A3),
                letterSpacing: 1.5,
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
                '${_modulosDisponibles.length} activos',
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
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _modulosDisponibles.length,
          itemBuilder: (context, index) {
            return _buildModuleCard(_modulosDisponibles[index], isMobile);
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard(Modulo modulo, bool isMobile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openModule(modulo),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: modulo.color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: modulo.color.withValues(alpha: 0.1),
                blurRadius: 15,
                spreadRadius: -3,
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          modulo.color,
                          modulo.color.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: modulo.color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(modulo.icono, color: Colors.white, size: 24),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
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
                    modulo.nombre,
                    style: GoogleFonts.syne(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modulo.descripcion,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFFA3A3A3),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Abrir',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: modulo.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: modulo.color,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMultiAreaConfig() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MultiAreaConfigScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openModule(Modulo modulo) {
    Widget destination;

    switch (modulo.id) {
      case 'educacion':
        destination = const EducacionScreen();
        break;
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
      default:
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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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
                'Centro de ayuda',
                Icons.help_outline_rounded,
                const Color(0xFF3B82F6),
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
    Color color,
  ) {
    return Container(
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
}
