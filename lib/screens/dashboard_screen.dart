import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/oculis_sidebar.dart';

// Paleta de colores
const Color oculisBg = Color(0xFF0A0B0F);
const Color oculisAccentPurple = Color(0xFF6366F1);
const Color oculisAccentBlue = Color(0xFF3B82F6);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Este widget ahora SOLO muestra el contenido, la sidebar la maneja MainNavigator
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [
            oculisAccentPurple.withOpacity(0.08),
            oculisBg,
            oculisBg,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Robot icon animado
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
                          oculisAccentPurple.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: Colors.white38,
                      size: 80,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // Mensaje de bienvenida
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Colors.white70, Colors.white],
                stops: [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: const Text(
                "HI JOSEPH, READY TO ACHIEVE\nGREAT THINGS?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                  height: 1.2,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Ask me anything, from business analysis to creative content.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
