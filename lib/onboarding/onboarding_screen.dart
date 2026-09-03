import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Auth/login.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 3 Intros
  final List<Map<String, dynamic>> _introPages = [
    {
      'title': 'Bienvenido a\nPortal Pilot',
      'subtitle': 'La plataforma todo-en-uno para gestionar inventario, ventas, clientes y facturación desde un solo lugar.',
      'icon': Icons.rocket_launch_rounded,
      'gradient': [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      'accent': Color(0xFF8B5CF6),
    },
    {
      'title': 'Control total de\ntu operación',
      'subtitle': 'Sincronización offline, reportes en tiempo real y control multi-sucursal. Tu negocio, siempre conectado.',
      'icon': Icons.analytics_rounded,
      'gradient': [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      'accent': Color(0xFF06B6D4),
    },
    {
      'title': 'Creado para\ncrecer contigo',
      'subtitle': 'Desde pulperías hasta cadenas comerciales. Portal Pilot se adapta a tu modelo y escala contigo.',
      'icon': Icons.storefront_rounded,
      'gradient': [Color(0xFFF59E0B), Color(0xFFEF4444)],
      'accent': Color(0xFFF59E0B),
    },
  ];

  String? _selectedBusiness;
  String? _selectedCustomer;
  String? _selectedOperation;
  bool _isLoading = false;

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
    {'label': 'Tienda física', 'icon': Icons.store_mall_directory_rounded, 'desc': 'Punto de venta'},
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
  int get _totalPages => 6; // 3 intros + 3 preguntas separadas
  bool get _isQuestionStep => _currentPage >= 3;

  void _nextWithValidation() {
    if (_currentPage == 3 && _selectedBusiness == null) {
      _showNeedSelection('Selecciona cómo funciona tu negocio');
      return;
    }
    if (_currentPage == 4 && _selectedCustomer == null) {
      _showNeedSelection('Selecciona a quién vendes');
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
  }

  void _showNeedSelection(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _p.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentPage + 1) / _totalPages;

    return Scaffold(
      backgroundColor: _p.bgPrimary,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.6,
                colors: [
                  _p.accentPurple.withValues(alpha: 0.10),
                  _p.accentPurpleDeep.withValues(alpha: 0.05),
                  _p.bgPrimary,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
          // Fondo tecnológico solicitado
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: Image.asset(
                'assets/img/base-tecnologica.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _p.accentPurple.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _p.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _p.borderLight),
                        ),
                        child: Image.asset(
                          'assets/img/robot_logo.png',
                          width: 22,
                          height: 22,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.blur_on_rounded, color: _p.accentPurple, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Portal Pilot',
                          style: GoogleFonts.syne(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _p.textPrimary,
                            letterSpacing: -0.5,
                          )),
                      const Spacer(),
                      if (!_isQuestionStep)
                        TextButton(
                          onPressed: () => _pageController.animateToPage(3,
                              duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                          style: TextButton.styleFrom(
                            foregroundColor: _p.textMuted,
                            textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Saltar'),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _p.accentPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _p.accentPurple.withValues(alpha: 0.25)),
                          ),
                          child: Text('PASO ${_currentPage + 1} DE $_totalPages',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: _p.accentPurple, letterSpacing: 1)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: _p.bgTertiary,
                      valueColor: AlwaysStoppedAnimation<Color>(_p.accentPurple),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) {
                      final active = i == _currentPage;
                      final completed = i < _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: active ? 28 : 6,
                        decoration: BoxDecoration(
                          color: active
                              ? _p.accentPurple
                              : completed
                                  ? _p.accentPurple.withValues(alpha: 0.45)
                                  : _p.textDark.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    children: [
                      ..._introPages.map((d) => _buildIntroPage(d)),
                      _buildSingleQuestionStep(
                        stepLabel: 'PASO 4',
                        title: '¿Cómo funciona\ntu negocio?',
                        subtitle: 'Elige la opción que mejor te describe',
                        options: _businessOptions,
                        selected: _selectedBusiness,
                        onSelected: (v) => setState(() => _selectedBusiness = v),
                        illustration: Icons.storefront_rounded,
                      ),
                      _buildSingleQuestionStep(
                        stepLabel: 'PASO 5',
                        title: '¿A quién\nle vendes?',
                        subtitle: 'Define tu mercado principal',
                        options: _customerOptions,
                        selected: _selectedCustomer,
                        onSelected: (v) => setState(() => _selectedCustomer = v),
                        illustration: Icons.groups_rounded,
                      ),
                      _buildSingleQuestionStep(
                        stepLabel: 'PASO 6',
                        title: '¿Cómo\noperas?',
                        subtitle: 'Selecciona tu modelo de operación',
                        options: _operationOptions,
                        selected: _selectedOperation,
                        onSelected: (v) => setState(() => _selectedOperation = v),
                        illustration: Icons.hub_rounded,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                // Footer solo para intros
                if (!_isQuestionStep)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        if (_currentPage > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _p.textPrimary,
                                side: BorderSide(color: _p.borderLight),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('Atrás',
                                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          )
                        else
                          const Spacer(),
                        if (_currentPage > 0) const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_p.accentPurple, _p.accentPurpleDark]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: _p.accentPurple.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _nextWithValidation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_currentPage == 2 ? 'Configurar' : 'Siguiente',
                                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroPage(Map<String, dynamic> data) {
    final title = data['title'] as String;
    final subtitle = data['subtitle'] as String;
    final icon = data['icon'] as IconData;
    final accent = data['accent'] as Color;
    final gradient = data['gradient'] as List<Color>;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 16))],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: -10,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                  ),
                ),
                Center(child: Icon(icon, size: 56, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Text('PORTAL PILOT ERP',
                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: accent, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w900, color: _p.textPrimary, height: 1.05, letterSpacing: -1.2),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(subtitle,
                style: GoogleFonts.dmSans(fontSize: 14.5, color: _p.textMuted, height: 1.6),
                textAlign: TextAlign.center),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _p.cardColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _p.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniFeature(Icons.offline_bolt_rounded, 'Offline'),
                Container(width: 1, height: 24, color: _p.borderLight),
                _miniFeature(Icons.security_rounded, 'Seguro'),
                Container(width: 1, height: 24, color: _p.borderLight),
                _miniFeature(Icons.bolt_rounded, 'Rápido'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _miniFeature(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _p.accentPurple.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: _p.accentPurple),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _p.textPrimary)),
      ],
    );
  }

  Widget _buildSingleQuestionStep({
    required String stepLabel,
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> options,
    required String? selected,
    required ValueChanged<String> onSelected,
    required IconData illustration,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del paso con icono grande
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_p.accentPurple, _p.accentPurpleDark]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(illustration, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stepLabel,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, fontWeight: FontWeight.w800, color: _p.accentPurple, letterSpacing: 1.2)),
                  Text(title.split('\n').first,
                      style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w900, color: _p.textPrimary, height: 1)),
                ],
              ),
              const Spacer(),
              if (selected != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _p.successGreen, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text('LISTO', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w900, color: _p.textPrimary, height: 1.05, letterSpacing: -0.7)),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.dmSans(fontSize: 13, color: _p.textMuted)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final opt = options[i];
                final label = opt['label'] as String;
                final icon = opt['icon'] as IconData;
                final desc = opt['desc'] as String;
                final isSelected = selected == label;
                return InkWell(
                  onTap: () => onSelected(label),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? _p.accentPurple.withValues(alpha: 0.12) : _p.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? _p.accentPurple : _p.borderLight, width: isSelected ? 1.5 : 1),
                      boxShadow: isSelected
                          ? [BoxShadow(color: _p.accentPurple.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected ? _p.accentPurple : _p.bgTertiary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 20, color: isSelected ? Colors.white : _p.textMuted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 14, fontWeight: FontWeight.w800, color: isSelected ? _p.textPrimary : _p.textMuted)),
                              Text(desc, style: GoogleFonts.dmSans(fontSize: 11.5, color: _p.textDark)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? _p.accentPurple : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? _p.accentPurple : _p.textDark.withValues(alpha: 0.4), width: 2),
                          ),
                          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _p.textPrimary,
                    side: BorderSide(color: _p.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Atrás', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: isLast ? [_p.successGreen, const Color(0xFF059669)] : [_p.accentPurple, _p.accentPurpleDark]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: (isLast ? _p.successGreen : _p.accentPurple).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLast
                        ? (_isLoading ? null : _finishOnboarding)
                        : _nextWithValidation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading && isLast
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(isLast ? 'Crear mi espacio' : 'Siguiente',
                                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (isLast) ...[
            const SizedBox(height: 8),
            Text('Podrás cambiar esto luego en Configuración → Mi Empresa',
                style: GoogleFonts.dmSans(fontSize: 11, color: _p.textDark, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _goToLoginDirect,
                child: Text('¿No avanza? Ir directo a Acceder →',
                    style: GoogleFonts.dmSans(fontSize: 11, color: _p.accentPurple, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    debugPrint('🔵 _finishOnboarding click: $_selectedBusiness / $_selectedCustomer / $_selectedOperation');
    if (_selectedBusiness == null || _selectedCustomer == null || _selectedOperation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa las 3 secciones (pasos 4, 5 y 6)',
              style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
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

      String areaNegocio = _determineAreaNegocio(_selectedBusiness!);
      final empresaCodigo = _selectedBusiness!.isNotEmpty ? _selectedBusiness!.substring(0, 5).toUpperCase() : 'PP';
      await prefs.setString('empresa_area_negocio', areaNegocio);
      await prefs.setBool('onboarding_completed', true);
      debugPrint('✅ prefs guardados area=$areaNegocio code=$empresaCodigo');

      // Navegar inmediatamente a Login (Acceder) - no bloquear por DB
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }

      // Operaciones en segundo plano (no bloquean navegación)
      try {
        final List<String> modulos = AreasNegocio.modulosPorDefecto(areaNegocio);
        await AuthController.instance.setSession(
          nombre: '',
          apellido: '',
          email: '',
          rol: 'cliente',
          area: areaNegocio,
          rango: '',
          empresaCodigo: 'ROOT',
          empresaNombre: 'Portal Pilot',
          token: '',
          modulos: modulos,
          empresaAreaNegocio: areaNegocio,
          empresaPlan: 'Prueba',
        );
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
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
    _pageController.dispose();
    super.dispose();
  }
}
