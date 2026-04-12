import 'dart:ui';
import 'package:flutter/material.dart';

class UnifiedBackground extends StatelessWidget {
  final Widget child;

  const UnifiedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF0A0B0F),
            Color(0xFF05060A),
            Colors.black,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
