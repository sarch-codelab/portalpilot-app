import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Auth/login.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

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
    },
    {
      'title': 'Control total\nde tu operación',
      'subtitle':
          'Sincronización offline, reportes en tiempo real\ny control multi-sucursal.',
    },
    {
      'title': 'Creado para\ncrecer contigo',
      'subtitle':
          'Desde una pulpería hasta una cadena comercial.\nSe adapta a tu modelo y escala contigo.',
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
    {'label': 'Pulpería / Mercadito', 'icon': Icons.storefront_rounded, 'desc': 'Barrio, colonia'},
    {'label': 'Tienda / Supermercado', 'icon': Icons.shopping_cart_rounded, 'desc': 'Retail, abarrotes'},
    {'label': 'Área Comercial', 'icon': Icons.business_center_rounded, 'desc': 'Distribución mayorista'},
    {'label': 'Club / Membresía', 'icon': Icons.card_membership_rounded, 'desc': 'Membresías, socios'},
  ];

  final List<Map<String, dynamic>> _customerOptions = [
    {'label': 'Consumidor final', 'icon': Icons.person_rounded, 'desc': 'B2C directo'},
    {'label': 'Empresas', 'icon': Icons.corporate_fare_rounded, 'desc': 'B2B corporativo'},
    {'label': 'Comercios', 'icon': Icons.store_rounded, 'desc': 'Revendedores'},
    {'label': 'Ambos', 'icon': Icons.groups_rounded, 'desc': 'Mixto'},
  ];

  final List<Map<String, dynamic>> _operationOptions = [
    {'label': 'Tienda física', 'icon': Icons.storefront_rounded, 'desc': 'Punto de venta'},
    {'label': 'Online', 'icon': Icons.language_rounded, 'desc': 'E-commerce'},
    {'label': 'Distribución', 'icon': Icons.local_shipping_rounded, 'desc': 'Rutas, reparto'},
    {'label': 'Autoservicio', 'icon': Icons.shopping_basket_rounded, 'desc': 'Self-service'},
    {'label': 'Membresía', 'icon': Icons.verified_user_rounded, 'desc': 'Club exclusivo'},
    {'label': 'Tienda física + Online', 'icon': Icons.hub_rounded, 'desc': 'Omnicanal'},
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

  ThemePalette get _p => ThemePalette(isDark: true);

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
      _finishOnboarding();
      return;
    }
    _pageController.nextPage(
        duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic);
  }

  void _showNeedSelection(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: _p.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fallbackBg,
      body: LayoutBuilder(builder: (context, c) {
        final isWide = c.maxWidth >= 700 && c.maxHeight >= 640;
        final bg = isWide
            ? 'assets/img/onboarding-bg.jpg'
            : 'assets/img/onboarding-bg-mobile.jpg';
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              bg,
              fit: BoxFit.cover,
              // Ancla arriba: la parte icónica del arte (curvas/haz de luz)
              // siempre es visible aunque el viewport recorte.
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: _fallbackBg),
            ),
            // Scrims de legibilidad.
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
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isWide),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (p) => setState(() => _currentPage = p),
                      children: [
                        ..._introPages.map((d) => _buildIntroPage(d, isWide)),
                        _QuestionPage(
                          title: '¿Cómo funciona tu negocio?',
                          subtitle: 'Elige la opción que mejor te describa.',
                          options: _businessOptions,
                          selected: _selectedBusiness,
                          onSelected: (v) => setState(() => _selectedBusiness = v),
                          isDesktop: isWide,
                        ),
                        _QuestionPage(
                          title: '¿A quién le vendes?',
                          subtitle: 'Define tu mercado principal.',
                          options: _customerOptions,
                          selected: _selectedCustomer,
                          onSelected: (v) => setState(() => _selectedCustomer = v),
                          isDesktop: isWide,
                        ),
                        _QuestionPage(
                          title: '¿Cómo operas?',
                          subtitle: 'Selecciona tu modelo de operación.',
                          options: _operationOptions,
                          selected: _selectedOperation,
                          onSelected: (v) => setState(() => _selectedOperation = v),
                          isDesktop: isWide,
                        ),
                      ],
                    ),
                  ),
                  _buildFooter(isWide),
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

  Widget _buildHeader(bool isWide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 32 : 24, isWide ? 18 : 14, 24, 0),
      child: Row(
        children: [
          Image.asset(
            'assets/img/robot_logo.png',
            width: isWide ? 24 : 22,
            height: isWide ? 24 : 22,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.blur_on_rounded, color: _accent, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'Portal Pilot',
            style: GoogleFonts.inter(
              fontSize: isWide ? 15.5 : 15,
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

  Widget _buildIntroPage(Map<String, String> data, bool isWide) {
    return Center(
      child: ConstrainedBox(
        // PC: columna 520; teléfono: todo el ancho con márgenes.
        constraints: BoxConstraints(maxWidth: isWide ? 520 : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 0 : 32),
          child: Column(
            children: [
              const Spacer(flex: 4),
              // Navi — la mascota saluda flotando sobre el titular.
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -5 + 7 * _floatController.value),
                  child: child,
                ),
                child: Container(
                  width: isWide ? 116 : 96,
                  height: isWide ? 116 : 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/img/robot_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 44),
                  ),
                ),
              ),
              SizedBox(height: isWide ? 20 : 18),
              Text(
                '${_currentPage + 1} de $_totalPages',
                style: GoogleFonts.inter(
                  fontSize: isWide ? 13.5 : 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: isWide ? 20 : 18),
              Text(
                data['title']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isWide ? 36 : 30,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: isWide ? -1.2 : -1.0,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isWide ? 16 : 14),
              Text(
                data['subtitle']!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isWide ? 16.5 : 15.5,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer: CTA iOS/macOS + acción gris ───────────────────────────────────

  Widget _buildFooter(bool isWide) {
    final button = SizedBox(
      height: isWide ? 52 : 50,
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
                        fontSize: isWide ? 16.5 : 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 17,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 520 : double.infinity),
        child: Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 0 : 24, 8, isWide ? 0 : 24, isWide ? 28 : 16),
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
                    textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Saltar'),
                ),
              if (_isLastStep) ...[
                Text(
                  'Podrás cambiar esto en Configuración → Mi Empresa.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: Colors.white.withValues(alpha: 0.42), height: 1.4),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _goToLoginDirect,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.42),
                    textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa las 3 secciones (pasos 4, 5 y 6)',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: _p.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
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

  const _QuestionPage({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.isDesktop,
  });

  static const Color _accent = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 520 : double.infinity),
        child: Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 20, 8, isDesktop ? 0 : 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: isDesktop ? 16 : 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 27 : 24,
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
                  fontSize: isDesktop ? 15 : 14,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: isDesktop ? 26 : 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    separatorBuilder: (context, i) => Padding(
                      padding: EdgeInsets.only(left: isDesktop ? 58 : 52),
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
                      final isSelected = selected == label;
                      return Material(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelected(label),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 18 : 16,
                              vertical: isDesktop ? 15 : 11,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: isDesktop ? 22 : 21,
                                  color: isSelected
                                      ? _accent
                                      : Colors.white.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.inter(
                                          fontSize: isDesktop ? 15.5 : 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      Text(
                                        desc,
                                        style: GoogleFonts.inter(
                                          fontSize: isDesktop ? 13 : 12.5,
                                          color: Colors.white.withValues(alpha: 0.42),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(scale: anim, child: child),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          key: ValueKey('check'), size: 20, color: _accent)
                                      : const SizedBox(width: 20),
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
                  // Navi con badge de check verde, dentro del halo circular.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/img/robot_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.smart_toy_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 56),
                        ),
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
