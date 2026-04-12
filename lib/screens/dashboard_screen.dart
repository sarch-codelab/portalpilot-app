import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _auroraController;
  late AnimationController _starController;
  late AnimationController _rgbController;
  final Random _random = Random();
  
  List<Star> _stars = [];
  String _userName = "JOSEPH";
  String _empresaNombre = "TECH SOLUTIONS";

  @override
  void initState() {
    super.initState();
    
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _rgbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _initStars();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName') ?? 'JOSEPH';
      final empresaNombre = prefs.getString('empresaNombre') ?? 'TECH SOLUTIONS';
      if (mounted) {
        setState(() {
          _userName = userName.toUpperCase();
          _empresaNombre = empresaNombre.toUpperCase();
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }
  
  void _initStars() {
    for (int i = 0; i < 100; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1 + _random.nextDouble() * 2.5,
        opacity: 0.2 + _random.nextDouble() * 0.7,
        twinkleSpeed: 0.3 + _random.nextDouble() * 2,
      ));
    }
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _starController.dispose();
    _rgbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Aurora boreal animada
        AnimatedBuilder(
          animation: _auroraController,
          builder: (context, child) {
            final wave1 = sin(_auroraController.value * 2 * pi) * 0.5 + 0.5;
            final wave2 = sin(_auroraController.value * 2 * pi + 2) * 0.5 + 0.5;
            final wave3 = sin(_auroraController.value * 2 * pi + 4) * 0.5 + 0.5;
            final wave4 = sin(_auroraController.value * 2 * pi + 6) * 0.5 + 0.5;
            
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2 + wave1 * 0.2, 0.3 + wave2 * 0.2),
                  radius: 1.5,
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.25 + wave1 * 0.1),
                    const Color(0xFF6366F1).withOpacity(0.15 + wave2 * 0.08),
                    const Color(0xFF3B82F6).withOpacity(0.1 + wave3 * 0.05),
                    const Color(0xFFEC4899).withOpacity(0.05 + wave4 * 0.03),
                    const Color(0xFF0A0B0F),
                    const Color(0xFF0A0B0F),
                  ],
                  stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                ),
              ),
            );
          },
        ),
        
        // Estrellas parpadeantes
        ..._buildStars(),
        
        // Contenido principal
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Robot icon
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF7C3AED).withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF7C3AED),
                        size: 70,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              
              // Mensaje de bienvenida
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6366F1), Color(0xFFEC4899)],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Column(
                  children: [
                    Text(
                      "HI $_userName,",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      "READY TO ACHIEVE GREAT THINGS?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Ask me anything, from business analysis to creative content.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 30),
              
              // Badge de empresa
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business, size: 14, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _empresaNombre,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Input flotante con borde RGB animado
        Positioned(
          bottom: 40,
          left: 40,
          right: 40,
          child: _buildRgbInput(),
        ),
      ],
    );
  }
  
  List<Widget> _buildStars() {
    return _stars.map((star) {
      return AnimatedBuilder(
        animation: _starController,
        builder: (context, child) {
          final twinkle = (sin(_starController.value * 2 * pi * star.twinkleSpeed) + 1) / 2;
          final opacity = (star.opacity * (0.3 + twinkle * 0.7)).clamp(0.0, 1.0);
          final size = star.size * (0.7 + twinkle * 0.6);
          
          return Positioned(
            left: star.x * MediaQuery.of(context).size.width,
            top: star.y * MediaQuery.of(context).size.height,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(opacity * 0.5),
                    blurRadius: size * 2,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }).toList();
  }
  
  Widget _buildRgbInput() {
    return AnimatedBuilder(
      animation: _rgbController,
      builder: (context, child) {
        // Colores RGB que se mueven
        final r = (sin(_rgbController.value * 2 * pi) + 1) / 2;
        final g = (sin(_rgbController.value * 2 * pi + 2) + 1) / 2;
        final b = (sin(_rgbController.value * 2 * pi + 4) + 1) / 2;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(124, 58, 237, 0.8 + r * 0.2),
                Color.fromRGBO(99, 102, 241, 0.8 + g * 0.2),
                Color.fromRGBO(236, 72, 153, 0.8 + b * 0.2),
              ],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Initiate a query or send a command to the AI...",
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) {},
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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