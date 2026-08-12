import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Auth/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _lineProgress;
  late Animation<double> _versionFade;

  // ═══ MISMA PALETA QUE EL LOGIN ═══
  static const Color bgPrimary = Color(0xFF000000);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleDark = Color(0xFF6D28D9);
  static const Color accentPurpleDeep = Color(0xFF5B21B6);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA3A3A3);
  static const Color textDark = Color(0xFF525252);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    // Secuencia escalonada de animaciones
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.70, curve: Curves.easeOut),
      ),
    );

    _lineProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    _versionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.90, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Navegar al Login después de la animación
    Timer(const Duration(milliseconds: 2800), _navigateToLogin);
  }

  Future<void> _navigateToLogin() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPrimary,
      body: Stack(
        children: [
          // Gradiente radial sutil (mismo que el login)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.8,
                colors: [
                  accentPurple.withValues(alpha: 0.06),
                  accentPurpleDeep.withValues(alpha: 0.02),
                  bgPrimary,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),

          // Contenido centrado y responsive
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 640 ||
                    constraints.maxWidth < 380;
                final titleSize = compact ? 32.0 : 42.0;
                final logoPadding = compact ? 14.0 : 18.0;
                final logoIcon = compact ? 28.0 : 34.0;
                final spacingMid = compact ? 8.0 : 12.0;
                final spacingLarge = compact ? 28.0 : 60.0;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── LOGO ──
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _logoScale.value,
                                child: Opacity(
                                  opacity: _logoFade.value,
                                  child: Container(
                                    padding: EdgeInsets.all(logoPadding),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          accentPurple,
                                          accentPurpleDark,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentPurple.withValues(
                                            alpha: 0.5 * _logoFade.value,
                                          ),
                                          blurRadius: 40,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.blur_on_rounded,
                                      color: textPrimary,
                                      size: logoIcon,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: compact ? 24 : 36),

                          // ── TÍTULO: PORTAL PILOT ──
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _titleSlide.value),
                                child: Opacity(
                                  opacity: _titleFade.value,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Portal Pilot',
                                      style: GoogleFonts.syne(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                        letterSpacing: -1.2,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: spacingMid),

                          // ── SUBTÍTULO ──
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _subtitleFade.value,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'WORKSPACE CLIENT',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textMuted,
                                      letterSpacing: 3.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: spacingLarge),

                          // ── LÍNEA DE PROGRESO MINIMALISTA ──
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return SizedBox(
                                width: compact ? 140 : 180,
                                child: Opacity(
                                  opacity: _subtitleFade.value,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Container(
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A1A),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: constraints.maxWidth *
                                                _lineProgress.value,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  accentPurple,
                                                  accentPurpleDark,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accentPurple
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 8,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: compact ? 16 : 24),

                          // ── VERSIÓN ──
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _versionFade.value,
                                child: Text(
                                  'v1.0.0',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Esquina inferior - Copyright
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _versionFade.value,
                  child: Text(
                    '© 2026 Portal Pilot',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

