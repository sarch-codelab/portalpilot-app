import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

/// Estado vacío con la identidad visual de Portal Pilot.
///
/// Usa una "órbita piloto" decorativa (anillo + nodo central) como iconografía
/// exclusiva de la marca, en lugar de iconos genéricos.
class PPEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final Color? accentColor;
  final Widget? action;
  final bool compact;

  const PPEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.accentColor,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final accent = accentColor ?? palette.brand;
    final isMobile = MobileUtils.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : (isMobile ? 26 : 38)),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOrbitIllustration(palette, accent, compact),
          SizedBox(height: compact ? 12 : 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: compact ? 15 : (isMobile ? 17 : 20),
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: compact ? 12 : 13,
              color: palette.textMuted,
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            SizedBox(height: compact ? 12 : 20),
            action!,
          ],
        ],
      ),
    );
  }

  /// Órbita piloto: nodo central rodeado por un anillo con 3 satélites.
  Widget _buildOrbitIllustration(ThemePalette palette, Color accent, bool compact) {
    final size = compact ? 72.0 : 96.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anillo exterior
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
            ),
          ),
          // Anillo punteado interior (girando suavemente)
          Positioned.fill(
            child: CustomPaint(painter: _DashedRingPainter(color: accent.withValues(alpha: 0.4))),
          ),
          // Satélites
          Positioned(
            right: size * 0.06,
            top: size * 0.28,
            child: _Satellite(color: accent, size: compact ? 7 : 9),
          ),
          Positioned(
            left: size * 0.10,
            bottom: size * 0.18,
            child: _Satellite(color: palette.warningAmber, size: compact ? 5 : 7),
          ),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.05,
            child: _Satellite(color: palette.infoBlue, size: compact ? 5 : 7),
          ),
          // Nodo central (icono)
          Container(
            width: compact ? 34 : 46,
            height: compact ? 34 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette.brandGradient),
              boxShadow: palette.glowShadow(accent, blur: 18),
            ),
            child: Icon(icon ?? Icons.rocket_launch_rounded, color: Colors.white, size: compact ? 18 : 24),
          ),
        ],
      ),
    );
  }
}

class _Satellite extends StatelessWidget {
  final Color color;
  final double size;
  const _Satellite({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.5)]),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.36;
    const dashCount = 14;
    const sweep = 12.0 * 2.1 / 180.0;
    final total = 2 * 3.1415927;
    final gap = total / dashCount;
    for (var i = 0; i < dashCount; i++) {
      final start = i * gap + 0.05;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => oldDelegate.color != color;
}