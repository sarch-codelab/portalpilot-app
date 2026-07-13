// lib/Areas/Educacion/educacion_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Areas/Educacion/Matricula/matricula.dart' show RegistroEstudiantilScreen, ThemePalette;
import 'package:portal_pilot_app/Areas/Educacion/Edu IA/eduia.dart' show CopilotScreen;
import 'package:portal_pilot_app/Areas/Educacion/Notas/notas.dart' show NotasScreen; // 🆕 Import del sistema de notas
import 'package:portal_pilot_app/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// EDUCACION SCREEN - Dashboard principal del área de Educación
// ═══════════════════════════════════════════════════════════

class EducacionScreen extends StatefulWidget {
  const EducacionScreen({super.key});

  @override
  State<EducacionScreen> createState() => _EducacionScreenState();
}

class _EducacionScreenState extends State<EducacionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _flashController;
  late AnimationController _gridController;
  late Animation<double> _flashAnimation;

  late Animation<double> _fadeLogo;
  late Animation<double> _fadeBanner;
  late Animation<double> _fadeWelcome;
  late Animation<double> _fadeUserCard;
  late Animation<double> _fadeClock;
  late Animation<double> _fadeStats;
  late Animation<double> _fadeAreas;

  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _gridController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _fadeLogo = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.0, 0.15, curve: Curves.easeOut)),
    );
    _fadeBanner = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.1, 0.3, curve: Curves.easeOut)),
    );
    _fadeWelcome = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.2, 0.4, curve: Curves.easeOut)),
    );
    _fadeClock = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.25, 0.45, curve: Curves.easeOut)),
    );
    _fadeUserCard = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.35, 0.55, curve: Curves.easeOut)),
    );
    _fadeStats = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.45, 0.65, curve: Curves.easeOut)),
    );
    _fadeAreas = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.55, 0.8, curve: Curves.easeOut)),
    );

    _flashController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _pulseController.forward();
    });

    _currentTime = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flashController.dispose();
    _gridController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  ThemePalette _palette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ThemePalette(isDark: isDark);
  }

  String _getGreeting() {
    final hour = _currentTime.hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _formatDate() {
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    return '${days[_currentTime.weekday % 7]}, ${_currentTime.day} de ${months[_currentTime.month - 1]} ${_currentTime.year}';
  }

  String _formatTime() {
    final h = _currentTime.hour.toString().padLeft(2, '0');
    final m = _currentTime.minute.toString().padLeft(2, '0');
    final s = _currentTime.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);

    return Scaffold(
      backgroundColor: p.bgPrimary,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  p.accentPurple.withOpacity(p.isDark ? 0.08 : 0.10),
                  p.bgPrimary,
                ],
              ),
            ),
          ),
          _buildAnimatedGrid(p),
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, child) {
              if (_flashAnimation.value <= 0.01) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        p.accentPurple.withOpacity(0.4 * _flashAnimation.value),
                        p.accentPurple.withOpacity(0.1 * _flashAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 24,
            right: 24,
            child: _buildThemeToggleButton(p),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAnimatedSection(animation: _fadeLogo, child: _buildPortalPilotLogo(p)),
                    const SizedBox(height: 36),
                    _buildAnimatedSection(animation: _fadeBanner, child: _buildEducationBanner(p)),
                    const SizedBox(height: 32),
                    _buildAnimatedSection(animation: _fadeClock, child: _buildClockWidget(p)),
                    const SizedBox(height: 28),
                    _buildAnimatedSection(animation: _fadeWelcome, child: _buildWelcomeMessage(p)),
                    const SizedBox(height: 28),
                    _buildAnimatedSection(animation: _fadeUserCard, child: _buildUserInfoCard(p)),
                    const SizedBox(height: 32),
                    _buildAnimatedSection(animation: _fadeStats, child: _buildQuickStats(p)),
                    const SizedBox(height: 32),
                    _buildAnimatedSection(animation: _fadeAreas, child: _buildAreasSection(p)),
                    const SizedBox(height: 24),
                    _buildFooter(p),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection({required Animation<double> animation, required Widget child}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedGrid(ThemePalette p) {
    return AnimatedBuilder(
      animation: _gridController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GridPainter(
            color: p.accentPurple.withOpacity(p.isDark ? 0.04 : 0.05),
            offset: _gridController.value * 100,
          ),
        );
      },
    );
  }

  Widget _buildThemeToggleButton(ThemePalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.bgTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          appThemeNotifier.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: p.accentPurple,
          size: 22,
        ),
        onPressed: () async {
          await appThemeNotifier.toggle();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _buildPortalPilotLogo(ThemePalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.accentPurple, p.accentPurpleDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: p.accentPurple.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portal Pilot',
              style: GoogleFonts.syne(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: p.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              'Sistema Educativo Inteligente',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: p.textMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEducationBanner(ThemePalette p) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'lib/Areas/Educacion/img/educacion.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    p.accentPurple.withOpacity(0.15),
                    p.accentPurpleDark.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.accentPurple.withOpacity(0.3)),
              ),
              child: Text(
                'EDUCACIÓN',
                style: GoogleFonts.syne(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: p.accentPurple,
                  letterSpacing: 4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildClockWidget(ThemePalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, color: p.accentPurple, size: 22),
          const SizedBox(width: 12),
          Text(
            _formatTime(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
              letterSpacing: 2,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: p.borderLight,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: p.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDate(),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage(ThemePalette p) {
    return Column(
      children: [
        Text(
          'Bienvenido/a Gissel',
          style: GoogleFonts.syne(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: p.textPrimary,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu portal educativo inteligente te espera',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: p.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(ThemePalette p) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.isDark ? 0.4 : 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: p.accentPurple.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem('ROL', 'Empleado', Icons.badge_rounded, p.accentPurple, p),
          _buildDivider(p),
          _buildInfoItem('ÁREA', 'Educación', Icons.school_rounded, p.accentPurpleLight, p),
          _buildDivider(p),
          _buildInfoItem('RANGO', 'Profesor', Icons.workspace_premium_rounded, p.successGreen, p),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemePalette p) {
    return Container(width: 1, height: 50, color: p.borderLight);
  }

  Widget _buildInfoItem(String label, String value, IconData icon, Color color, ThemePalette p) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: p.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: p.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(ThemePalette p) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Alumnos Activos',
              '1,247',
              '+42 este mes',
              Icons.people_alt_rounded,
              p.successGreen,
              p,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Asistencia Hoy',
              '96.2%',
              'Excelente',
              Icons.how_to_reg_rounded,
              p.accentPurple,
              p,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Próximos Eventos',
              '3',
              'Esta semana',
              Icons.event_rounded,
              p.warningAmber,
              p,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color, ThemePalette p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
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
                    fontSize: 11,
                    color: p.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🆕 SECCIÓN DE ÁREAS HABILITADAS (4 TARJETAS ACTIVAS)
  // ═══════════════════════════════════════════════════════════

  Widget _buildAreasSection(ThemePalette p) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.accentPurple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.accentPurple.withOpacity(0.3)),
                ),
                child: Icon(Icons.apps_rounded, color: p.accentPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Áreas Habilitadas',
                style: GoogleFonts.syne(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Accede a los sistemas educativos disponibles para tu perfil',
            style: GoogleFonts.dmSans(fontSize: 14, color: p.textMuted),
          ),
          const SizedBox(height: 24),

          // ── FILA 1: 🆕 Sistema de Notas + Control de Asistencias ──
          Row(
            children: [
              Expanded(
                child: _buildAreaCard(
                  'Sistema de Notas',
                  'Gestión de calificaciones y boletas',
                  Icons.grade_rounded,
                  p.accentPurple,
                  true, // ✅ AHORA ESTÁ ACTIVO
                  p,
                  destination: const NotasScreen(), // 🆕 Navega al sistema de notas
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildAreaCard(
                  'Control de Asistencias',
                  'Registro y seguimiento de asistencia',
                  Icons.how_to_reg_rounded,
                  p.infoBlue,
                  false,
                  p,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── FILA 2: Registro Estudiantil + Edu IA ──
          Row(
            children: [
              Expanded(
                child: _buildAreaCard(
                  'Registro Estudiantil',
                  'Inscripción y gestión de alumnos',
                  Icons.person_add_alt_1_rounded,
                  p.successGreen,
                  true,
                  p,
                  destination: const RegistroEstudiantilScreen(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildAreaCard(
                  'Edu IA',
                  'Asistente inteligente de gestión escolar',
                  Icons.smart_toy_rounded,
                  p.accentPurpleDeep,
                  true,
                  p,
                  destination: const CopilotScreen(),
                  isAI: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(
    String title,
    String description,
    IconData icon,
    Color color,
    bool isPrimary,
    ThemePalette p, {
    Widget? destination,
    bool isAI = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (destination != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => destination),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title - Próximamente disponible'),
                backgroundColor: color,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: p.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary ? color.withOpacity(0.4) : p.borderLight,
              width: isPrimary ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(p.isDark ? 0.3 : 0.06),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              if (isPrimary)
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
            ],
            gradient: isPrimary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.08),
                      color.withOpacity(0.02),
                    ],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  if (isAI)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [p.accentPurple, p.accentPurpleDark],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: p.accentPurple.withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'IA',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: p.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    isPrimary ? 'Acceder' : 'Próximamente',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? color : p.textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isPrimary ? Icons.arrow_forward_rounded : Icons.schedule_rounded,
                    color: isPrimary ? color : p.textDark,
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

  Widget _buildFooter(ThemePalette p) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: p.successGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.successGreen.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Todos los sistemas operativos',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: p.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '© 2026 Portal Pilot · v1.1.0',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            color: p.textDark,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// GRID PAINTER (fondo animado sutil)
// ═══════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  final Color color;
  final double offset;

  _GridPainter({required this.color, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;

    for (double x = -spacing + (offset % spacing); x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = -spacing + (offset % spacing); y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}