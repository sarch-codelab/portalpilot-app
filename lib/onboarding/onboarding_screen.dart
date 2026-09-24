import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:portal_pilot_app/Auth/login.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';

/// Onboarding — Apple Design Language, con diseño separado por plataforma.
///
///  · PC (≥700px de ancho): asistente estilo macOS — columna de contenido
///    centrada (520px), títulos grandes, filas altas, más aire.
///  · Teléfono: asistente estilo iOS Setup — márgenes ceñidos, tipografía
///    compacta, lista inset-grouped a todo el ancho útil.
///  · Ambos comparten: fondo negro-morado profesional, listas iOS con
///    hairlines inset y checkmark morado, botón sólido + acción gris.
///  · Transición hacia el login: zoom-fade tipo Apple (fade + escala + slide).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 6; // 3 intros + 3 preguntas

  final List<Map<String, String>> _introPages = [
    {
      'title': 'Bienvenido a\nPortal Pilot',
      'subtitle':
          'Inventario, ventas, clientes y facturación.\nTodo tu negocio, desde un solo lugar.',
      'img': 'img/onboarding/navi_feliz_risueno.png',
    },
    {
      'title': 'Control total\nde tu operación',
      'subtitle':
          'Sincronización offline, reportes en tiempo real\ny control multi-sucursal.',
      'img': 'img/onboarding/navi_feliz_telefono.png',
    },
    {
      'title': 'Creado para\ncrecer contigo',
      'subtitle':
          'Desde una pulpería hasta una cadena comercial.\nSe adapta a tu modelo y escala contigo.',
      'img': 'img/onboarding/navi_creciendo.png',
    },
  ];

  String? _selectedBusiness;
  String? _selectedCustomer;
  String? _selectedOperation;
  bool _isLoading = false;
  bool _showingSuccess = false;

  /// Flotación suave de Navi (arriba-abajo, 3.2s, vaivén continuo).
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  final List<Map<String, dynamic>> _businessOptions = [
    {'label': 'Pulpería / Mercadito', 'icon': Icons.storefront_rounded, 'desc': 'Barrio, colonia', 'img': 'img/onboarding/pulperia_mercadito.png'},
    {'label': 'Tienda / Supermercado', 'icon': Icons.shopping_cart_rounded, 'desc': 'Retail, abarrotes', 'img': 'img/onboarding/tienda_supermercado.png'},
    {'label': 'Club / Membresía', 'icon': Icons.card_membership_rounded, 'desc': 'Membresías, socios', 'img': 'img/onboarding/club_membresia.png'},
  ];

  final List<Map<String, dynamic>> _customerOptions = [
    {'label': 'Consumidor final', 'icon': Icons.person_rounded, 'desc': 'B2C directo'},
    {'label': 'Empresas', 'icon': Icons.corporate_fare_rounded, 'desc': 'B2B corporativo'},
    {'label': 'Comercios', 'icon': Icons.store_rounded, 'desc': 'Revendedores'},
    {'label': 'Ambos', 'icon': Icons.groups_rounded, 'desc': 'Mixto'},
  ];

  final List<Map<String, dynamic>> _operationOptions = [
    {'label': 'Tienda física', 'icon': Icons.storefront_rounded, 'desc': 'Punto de venta y mostrador', 'img': 'img/onboarding/tienda_fisica.png'},
    {'label': 'Tienda física + Online', 'icon': Icons.hub_rounded, 'desc': 'Omnicanal (local comercial y web)', 'img': 'img/onboarding/tienda_fisica_online.png'},
    {'label': 'Online', 'icon': Icons.language_rounded, 'desc': 'E-commerce y redes sociales', 'img': 'img/onboarding/online.png'},
    {'label': 'Distribución', 'icon': Icons.local_shipping_rounded, 'desc': 'Rutas, preventa y reparto', 'img': 'img/onboarding/distribucion.png'},
    {'label': 'Autoservicio', 'icon': Icons.shopping_basket_rounded, 'desc': 'Kioscos y self-checkout', 'img': 'img/onboarding/autoservicio.png'},
    {'label': 'Membresía', 'icon': Icons.verified_user_rounded, 'desc': 'Club exclusivo o socios', 'img': 'img/onboarding/membresia.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (completed && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Tokens Apple ──────────────────────────────────────────────────────────
  static const Color _accent = Color(0xFF8B5CF6);
  static const Color _fallbackBg = Color(0xFF0A0612);

  bool get _isQuestionStep => _currentPage >= 3;
  bool get _isLastStep => _currentPage == _totalPages - 1;

  String get _primaryLabel {
    switch (_currentPage) {
      case 2:
        return 'Configurar';
      case 5:
        return _isLoading ? 'Guardando…' : 'Finalizar';
      default:
        return 'Continuar';
    }
  }

  void _nextWithValidation() {
    if (_currentPage == 3 && _selectedBusiness == null) {
      _showNeedSelection('Selecciona cómo funciona tu negocio');
      return;
    }
    if (_currentPage == 4 && _selectedCustomer == null) {
      _showNeedSelection('Selecciona a quién vendes');
      return;
    }
    if (_isLastStep) {
      if (_selectedOperation == null) {
        _showNeedSelection('Selecciona tu modelo de operación');
        return;
      }
      _showPlanRecommendationModal();
      return;
    }
    _pageController.nextPage(
        duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
  }

  void _showNeedSelection(String msg) {
    PPNotifications.dismissAll();
    PPNotifications.warning(context, msg, title: 'Selección requerida');
  }

  void _showPlanRecommendationModal() {
    final isEnterprise = (_selectedBusiness?.contains('Supermercado') ?? false) ||
        (_selectedBusiness?.contains('Club') ?? false) ||
        (_selectedOperation?.contains('Distribución') ?? false) ||
        (_selectedOperation?.contains('Autoservicio') ?? false) ||
        (_selectedOperation?.contains('Omnicanal') ?? false) ||
        (_selectedCustomer?.contains('Empresas') ?? false) ||
        (_selectedCustomer?.contains('Comercios') ?? false) ||
        (_selectedCustomer?.contains('Ambos') ?? false);

    final planName = isEnterprise ? 'Plan Enterprise' : 'Plan Business';
    final planPrice = isEnterprise ? 'L 4,999' : 'L 1,499';
    final planDesc = isEnterprise
        ? 'Control multi-sucursal, facturación SAR masiva, rutas y autoservicio.'
        : 'Punto de venta rápido, facturación electrónica SAR y control de inventario.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlanRecommendationSheet(
        business: _selectedBusiness ?? '',
        customer: _selectedCustomer ?? '',
        operation: _selectedOperation ?? '',
        planName: planName,
        planPrice: planPrice,
        planDesc: planDesc,
        isEnterprise: isEnterprise,
        onConfirm: () {
          Navigator.of(ctx).pop();
          _finishOnboarding();
        },
        onGoToLogin: () {
          Navigator.of(ctx).pop();
          _finishOnboarding();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fallbackBg,
      body: LayoutBuilder(builder: (context, c) {
        final aspectRatio = c.maxWidth / c.maxHeight;
        // Solo se considera PC landscape si la ventana tiene proporción apaisada
        // (aspectRatio >= 1.15) y ancho >= 768. Si el usuario reduce el ancho en PC
        // (dejándola vertical como un teléfono), cambia automáticamente a telefono.png.
        final isWide = c.maxWidth >= 768 && c.maxHeight >= 550 && aspectRatio >= 1.15;
        // Escala adaptativa: tipografía/tamaños crecen o se reducen según la
        // altura REAL de la ventana (PC grande, PC pequeña, celular).
        final double s = (c.maxHeight / (isWide ? 860 : 760)).clamp(0.80, isWide ? 1.35 : 1.20);
        // En móvil, las preguntas (pasos 4, 5 y 6) usan un fondo limpio estilo Uber
        // para que las luces no interfieran. Las 3 intros conservan el fondo curvo con Navi.
        final showCurvedBg = isWide || !_isQuestionStep;
        final bg = isWide
            ? 'img/onboarding/pc.png'
            : 'img/onboarding/telefono.png';
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showCurvedBg)
              Image.asset(
                bg,
                key: ValueKey(bg),
                gaplessPlayback: true,
                fit: isWide ? BoxFit.cover : BoxFit.fill,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: _fallbackBg),
              )
            else
              const ColoredBox(color: Color(0xFF090614)),
            if (showCurvedBg) ...[
              Positioned(
                top: 0, left: 0, right: 0, height: 170,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 250,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ],
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isWide, s),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (p) => setState(() => _currentPage = p),
                      children: [
                        ..._introPages.map((d) => _buildIntroPage(d, isWide, s)),
                        _QuestionPage(
                          title: '¿Cómo funciona tu negocio?',
                          subtitle: 'Elige la opción que mejor te describa.',
                          options: _businessOptions,
                          selected: _selectedBusiness,
                          onSelected: (v) => setState(() => _selectedBusiness = v),
                          isDesktop: isWide,
                          scale: s,
                        ),
                        _QuestionPage(
                          title: '¿A quién le vendes?',
                          subtitle: 'Define tu mercado principal.',
                          options: _customerOptions,
                          selected: _selectedCustomer,
                          onSelected: (v) => setState(() => _selectedCustomer = v),
                          isDesktop: isWide,
                          scale: s,
                        ),
                        _QuestionPage(
                          title: '¿Cómo operas?',
                          subtitle: 'Selecciona tu modelo de operación.',
                          options: _operationOptions,
                          selected: _selectedOperation,
                          onSelected: (v) => setState(() => _selectedOperation = v),
                          isDesktop: isWide,
                          scale: s,
                        ),
                      ],
                    ),
                  ),
                  _buildFooter(isWide, s),
                ],
              ),
            ),
            // Momento de éxito: Navi confirma antes del zoom al login.
            if (_showingSuccess) const _SuccessOverlay(),
          ],
        );
      }),
    );
  }

  // ── Header: lockup discreto arriba a la izquierda ─────────────────────────

  Widget _buildHeader(bool isWide, double s) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          isWide ? 32 * s : 24, isWide ? 18 * s : 14, 24, 0),
      child: Row(
        children: [
          Image.asset(
            'assets/img/robot_logo.png',
            width: (isWide ? 24 : 22) * s,
            height: (isWide ? 24 : 22) * s,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.blur_on_rounded, color: _accent, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'Portal Pilot',
            style: GoogleFonts.inter(
              fontSize: (isWide ? 15.5 : 15) * s,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Intro ── PC: asistente macOS · Teléfono: Setup Assistant iOS ──────────

  Widget _buildIntroPage(Map<String, String> data, bool isWide, double s) {
    return Center(
      child: ConstrainedBox(
        // PC: columna 560; teléfono: todo el ancho con márgenes.
        constraints: BoxConstraints(maxWidth: isWide ? 560 : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 0 : 28),
          child: LayoutBuilder(builder: (context, lv) {
            // Navi grande pero proporcional: ~40% del alto útil de la página.
            final h = lv.maxHeight;
            final double naviH =
                (h * (isWide ? 0.40 : 0.38)).clamp(isWide ? 220 : 160, 380.0);
            return Column(
              children: [
                const Spacer(flex: 3),
                // Navi — la mascota (imagen propia de cada página) flota sobre
                // el titular. Sin caja detrás y con contain jamás se recorta.
                AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -4 + 7 * _floatController.value),
                    child: child,
                  ),
                  child: Image.asset(
                    data['img']!,
                    height: naviH,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 64),
                  ),
                ),
                SizedBox(height: (isWide ? 22 : 18) * s),
                Text(
                  '${_currentPage + 1} de $_totalPages',
                  style: GoogleFonts.inter(
                    fontSize: (isWide ? 13.5 : 13) * s,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: (isWide ? 20 : 18) * s),
                Text(
                  data['title']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: (isWide ? 36 : 30) * s,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: isWide ? -1.2 : -1.0,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: (isWide ? 16 : 14) * s),
                Text(
                  data['subtitle']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: (isWide ? 16.5 : 15.5) * s,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(flex: 4),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Footer: CTA iOS/macOS + acción gris ───────────────────────────────────

  Widget _buildFooter(bool isWide, double s) {
    final backButton = SizedBox(
      height: (isWide ? 52 : 50) * s,
      child: OutlinedButton(
        onPressed: _currentPage == 0 || _isLoading
            ? null
            : () => _pageController.previousPage(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.8),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.25),
          side: _currentPage == 0 || _isLoading
              ? BorderSide(color: Colors.white.withValues(alpha: 0.10))
              : BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isWide ? 14 : 13)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_rounded, size: 17 * s.clamp(1, 1.15)),
            const SizedBox(width: 6),
            Text('Atrás',
                style: GoogleFonts.inter(
                    fontSize: (isWide ? 16 : 15.5) * s,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );

    final nextButton = SizedBox(
      height: (isWide ? 52 : 50) * s,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _nextWithValidation,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _accent.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isWide ? 14 : 13)),
        ),
        child: _isLoading && _isLastStep
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _primaryLabel,
                    style: GoogleFonts.inter(
                        fontSize: (isWide ? 16.5 : 16) * s,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 17 * s.clamp(1, 1.15),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
      ),
    );

    final button = Row(
      children: [
        Expanded(child: backButton),
        const SizedBox(width: 10),
        Expanded(child: nextButton),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 560 : double.infinity),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              isWide ? 0 : 24, 8, isWide ? 0 : 24, isWide ? 28 * s : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              button,
              const SizedBox(height: 4),
              if (!_isQuestionStep)
                TextButton(
                  onPressed: () => _pageController.animateToPage(3,
                      duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.5),
                    textStyle: GoogleFonts.inter(
                        fontSize: 14 * s, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Saltar'),
                ),
              if (_isLastStep) ...[
                Text(
                  'Podrás cambiar esto en Configuración → Mi Empresa.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12.5 * s, color: Colors.white.withValues(alpha: 0.42), height: 1.4),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _goToLoginDirect,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.42),
                    textStyle: GoogleFonts.inter(
                        fontSize: 12.5 * s, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Ir directo a Acceder'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Lógica (sin cambios funcionales) ──────────────────────────────────────

  /// Transición estilo Apple hacia el login: fade + zoom-out suave
  /// (escala 0.98→1.0) con deslizamiento mínimo hacia arriba.
  static Route<void> _appleLoginRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero)
                .animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 560),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _finishOnboarding() async {
    debugPrint('🔵 _finishOnboarding click: $_selectedBusiness / $_selectedCustomer / $_selectedOperation');
    if (_selectedBusiness == null || _selectedCustomer == null || _selectedOperation == null) {
      PPNotifications.warning(
        context,
        'Por favor completa las 3 secciones (pasos 4, 5 y 6)',
        title: 'Selección requerida',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('business_type', _selectedBusiness!);
      await prefs.setString('customer_type', _selectedCustomer!);
      await prefs.setString('operation_type', _selectedOperation!);
      // Contexto extendido (Blueprint §2): industria y categoría explícitas
      // para el hand-off hacia la web.
      await prefs.setString('industria', _selectedBusiness!);
      await prefs.setString('categoria', _selectedCustomer!);
      await prefs.setString('operacion', _selectedOperation!);

      String areaNegocio = _determineAreaNegocio(_selectedBusiness!);
      final empresaCodigo = _selectedBusiness!.isNotEmpty ? _selectedBusiness!.substring(0, 5).toUpperCase() : 'PP';
      await prefs.setString('empresa_area_negocio', areaNegocio);
      await prefs.setBool('onboarding_completed', true);
      debugPrint('✅ prefs guardados area=$areaNegocio code=$empresaCodigo');

      // Momento de éxito estilo Apple: Navi confirma (overlay) y luego zoom al login.
      if (mounted) {
        setState(() {
          _showingSuccess = true;
          _isLoading = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushAndRemoveUntil(_appleLoginRoute(), (route) => false);
      }

      // Preparar datos locales sin crear una sesión autenticada.
      try {
        final List<String> modulos = AreasNegocio.modulosPorDefecto(areaNegocio);
        await prefs.setString('onboarding_modulos', modulos.join(','));
        final db = LocalDatabaseService.instance;
        final empresaCompanion = db.empresaFromOnboarding(areaNegocio, empresaCodigo);
        await db.upsertEmpresa(empresaCompanion);
        final empresaDatos = {
          'codigo': empresaCodigo,
          'nombre': 'Portal Pilot Empresa',
          'area_negocio': areaNegocio,
          'plan': 'Prueba',
          'activa': true,
        };
        await SyncService.instance.enqueueSync(
          tabla: 'empresas',
          operacion: SyncOperation.insert,
          datos: empresaDatos,
          empresaId: empresaCodigo,
        );
        debugPrint('✅ DB y sync OK');
      } catch (e) {
        debugPrint('⚠️ Error DB post-navegación (no bloquea): $e');
      }
    } catch (e, st) {
      debugPrint('❌ _finishOnboarding error: $e\n$st');
      if (mounted) {
        PPNotifications.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Botón de emergencia para debug: ir directo a login sin guardar
  Future<void> _goToLoginDirect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(_appleLoginRoute(), (route) => false);
  }

  String _determineAreaNegocio(String businessType) {
    final lower = businessType.toLowerCase();
    if (lower.contains('pulper') || lower.contains('mercad') || lower.contains('abarroter')) {
      return 'canal_tradicional';
    }
    if (lower.contains('supermer') || lower.contains('retail')) {
      return 'retail';
    }
    if (lower.contains('membres') || lower.contains('club')) {
      return 'membresias';
    }
    return 'comercial_generico';
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

/// Pregunta estilo iOS/macOS: título centrado + Inset Grouped List.
///  · Desktop: columna 520, filas altas (más aire, radio 16).
///  · Teléfono: ancho completo útil, filas compactas (radio 12).
class _QuestionPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool isDesktop;
  final double scale;

  const _QuestionPage({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.isDesktop,
    required this.scale,
  });

  static const Color _accent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 560 : double.infinity),
        child: Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 20, 8, isDesktop ? 0 : 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: (isDesktop ? 16 : 12) * s),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: (isDesktop ? 27 : 24) * s,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: isDesktop ? -1.0 : -0.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: (isDesktop ? 15 : 14) * s,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: (isDesktop ? 26 : 20) * s),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDesktop
                            ? const Color(0xEE140F24)
                            : const Color(0xF20F0A1C), // Opacidad alta en teléfono para que las luces laterales no manchen el texto
                        borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDesktop ? 0.08 : 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: 4 * s),
                        itemCount: options.length,
                        separatorBuilder: (context, i) => Padding(
                          padding: EdgeInsets.only(left: (isDesktop ? 68 : 62) * s),
                          child: Divider(
                              height: 1,
                              thickness: 0.8,
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        itemBuilder: (context, i) {
                          final opt = options[i];
                          final label = opt['label'] as String;
                          final desc = opt['desc'] as String;
                          final icon = opt['icon'] as IconData;
                          final img = opt['img'] as String?;
                          final isSelected = selected == label;
                          return Material(
                            color: isSelected
                                ? _accent.withValues(alpha: 0.12)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => onSelected(label),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: (isDesktop ? 18 : 16) * s,
                                  vertical: (isDesktop ? 14 : 11) * s,
                                ),
                                child: Row(
                                  children: [
                                    if (img != null)
                                      Padding(
                                        padding: EdgeInsets.only(right: 14 * s),
                                        child: Image.asset(
                                          img,
                                          width: (isDesktop ? 54 : 46) * s,
                                          height: (isDesktop ? 54 : 46) * s,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              Icon(icon,
                                                  size:
                                                      (isDesktop ? 24 : 22) * s,
                                                  color: _accent),
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: EdgeInsets.only(right: 14 * s),
                                        child: Icon(
                                          icon,
                                          size: (isDesktop ? 26 : 24) * s,
                                          color: isSelected
                                              ? _accent
                                              : Colors.white.withValues(alpha: 0.70),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: GoogleFonts.inter(
                                              fontSize:
                                                  (isDesktop ? 15.5 : 15) * s,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: Colors.white,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            desc,
                                            style: GoogleFonts.inter(
                                              fontSize:
                                                  (isDesktop ? 13 : 12.5) * s,
                                              color: isSelected
                                                  ? Colors.white.withValues(alpha: 0.75)
                                                  : Colors.white.withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(
                                              scale: anim, child: child),
                                      child: isSelected
                                          ? Container(
                                              key: const ValueKey('selected'),
                                              width: 22 * s.clamp(1.0, 1.2),
                                              height: 22 * s.clamp(1.0, 1.2),
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _accent,
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                size: 15,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Container(
                                              key: const ValueKey('unselected'),
                                              width: 22 * s.clamp(1.0, 1.2),
                                              height: 22 * s.clamp(1.0, 1.2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.22),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay de éxito: "Todo listo" + Navi con check, momento estilo Apple
/// antes de lanzar la transición hacia el login.
class _SuccessOverlay extends StatefulWidget {
  const _SuccessOverlay();

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        child: Container(
          color: const Color(0xE6050308),
          child: Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navi con badge de check verde, sin halo circular detrás.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        'assets/img/robot_logo.png',
                        width: 148,
                        height: 148,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.smart_toy_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 64),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF30D158), // verde Apple
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Todo listo',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Llevándote al acceso…',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja modal de recomendación de plan según las selecciones del usuario.
/// Muestra el plan recomendado (Business o Enterprise) y la oferta de 15 días gratis.
class _PlanRecommendationSheet extends StatelessWidget {
  final String business;
  final String customer;
  final String operation;
  final String planName;
  final String planPrice;
  final String planDesc;
  final bool isEnterprise;
  final VoidCallback onConfirm;
  final VoidCallback? onGoToLogin;

  const _PlanRecommendationSheet({
    required this.business,
    required this.customer,
    required this.operation,
    required this.planName,
    required this.planPrice,
    required this.planDesc,
    required this.isEnterprise,
    required this.onConfirm,
    this.onGoToLogin,
  });

  static const Color _accent = Color(0xFF8B5CF6);

  Future<void> _openWebPlans() async {
    final uri = Uri.parse('https://portal-pilot.vercel.app');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('No se pudo abrir enlace: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 540 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0A1C),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: isDesktop ? const Radius.circular(24) : Radius.zero,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 36,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Manija superior
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              // Encabezado con Navi / logo
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/img/robot_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.auto_awesome_rounded, color: _accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Felicidades!',
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Tenemos tu plan recomendado listo',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Tarjetas de los 2 Planes (Recomendado + Oferta 15 días gratis)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Tarjeta 1: Plan Recomendado según sus selecciones
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _accent.withValues(alpha: 0.18),
                              const Color(0xFF1B142F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PLAN RECOMENDADO',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  planPrice,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  ' / mes',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              planName,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              planDesc,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tarjeta 2: Prueba Gratuita (15 días de oferta)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF140E24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF30D158).withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF30D158),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '🔥 OFERTA DE 15 DÍAS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'GRATIS',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF30D158),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Prueba Gratuita Completa',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '¡Prueba tu plan recomendado con 15 días de acceso total sin costo ni tarjeta de crédito!',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.70),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Enlace clickable a portal-pilot.vercel.app
                      InkWell(
                        onTap: _openWebPlans,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                                color: _accent.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ver y comparar todos los planes en ',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                'portal-pilot.vercel.app',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _accent,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Botón principal
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Comenzar Prueba Gratuita (15 días)',
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Botón secundario: Iniciar Sesión / Ir al Login
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onGoToLogin ?? onConfirm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login_rounded, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        'Iniciar Sesión',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

