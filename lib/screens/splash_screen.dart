import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'portal_selector.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ✅ Cambiado a TickerProviderStateMixin
  late AnimationController _starController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final Random _random = Random();

  List<Star> _stars = [];
  List<Comet> _comets = [];

  @override
  void initState() {
    super.initState();
    _initStars();
    _initComets();

    _starController = AnimationController(
      vsync: this, // ✅ Ahora funciona porque usamos TickerProviderStateMixin
      duration: const Duration(seconds: 3),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this, // ✅ Ahora funciona porque usamos TickerProviderStateMixin
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _scaleController.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PortalSelector(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  void _initStars() {
    for (int i = 0; i < 60; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1 + _random.nextDouble() * 2,
        opacity: 0.3 + _random.nextDouble() * 0.7,
        twinkleSpeed: 0.5 + _random.nextDouble() * 2,
      ));
    }
  }

  void _initComets() {
    _comets.add(Comet(
      x: -0.2,
      y: _random.nextDouble() * 0.5,
      speed: 0.5 + _random.nextDouble() * 0.3,
      length: 0.15,
    ));
    _comets.add(Comet(
      x: 1.2,
      y: _random.nextDouble() * 0.7,
      speed: 0.3 + _random.nextDouble() * 0.2,
      length: 0.12,
    ));
  }

  @override
  void dispose() {
    _starController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomCenter,
                radius: 1.2,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.12),
                  const Color(0xFF3B82F6).withOpacity(0.05),
                  const Color(0xFF0A0B0F),
                  const Color(0xFF0A0B0F),
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          // Estrellas
          ..._stars.map((star) {
            return AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                final opacity = star.opacity +
                    sin(_starController.value * 2 * pi * star.twinkleSpeed) *
                        0.3;
                return Positioned(
                  left: star.x * MediaQuery.of(context).size.width,
                  top: star.y * MediaQuery.of(context).size.height,
                  child: Container(
                    width: star.size,
                    height: star.size,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(opacity.clamp(0.1, 1.0)),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: star.size * 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),

          // Cometas
          ..._comets.map((comet) {
            return AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                final progress = (_starController.value + comet.speed) % 1.0;
                final x = comet.x + progress * 1.5;
                final y = comet.y + progress * 0.4;

                if (x > 1.3 || x < -0.3) return const SizedBox.shrink();

                return Positioned(
                  left: x * MediaQuery.of(context).size.width,
                  top: y * MediaQuery.of(context).size.height,
                  child: Container(
                    width: comet.length * MediaQuery.of(context).size.width,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF6366F1).withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenido central
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animado
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // Título con efecto shine
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.white70, Colors.white],
                    stops: [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    'PORTALPILOT',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Subtítulo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: Text(
                    '+ CYBERYX VANTAGE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      letterSpacing: 2,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Barra de carga
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: null,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),

                // Texto de carga
                Text(
                  'Inicializando sistema seguro...',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Clases auxiliares
class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double twinkleSpeed;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.twinkleSpeed,
  });
}

class Comet {
  final double x;
  final double y;
  final double speed;
  final double length;

  Comet({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
  });
}
