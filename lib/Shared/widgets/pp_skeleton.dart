import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

/// Carga con efecto shimmer/skeleton alineado a la marca Portal Pilot.
///
/// Reduce la "barriga" del `CircularProgressIndicator` genérico: muestra
/// placeholders acordes al layout final.
class PPSkeleton extends StatefulWidget {
  /// Número de bloques de línea a renderizar.
  final int lines;

  /// Si es `true` muestra una tarjeta con encabezado + líneas.
  final bool card;

  /// Número de tarjetas (en grid).
  final int cards;

  /// Columnas del grid (desktop usa más por defecto).
  final int? columns;

  const PPSkeleton({
    super.key,
    this.lines = 4,
    this.card = false,
    this.cards = 3,
    this.columns,
  });

  @override
  State<PPSkeleton> createState() => _PPSkeletonState();
}

class _PPSkeletonState extends State<PPSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final cols = widget.columns ?? MobileUtils.getResponsiveColumns(context);

    if (!widget.card) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(widget.lines, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _shimmerBar(
                  palette,
                  widthFactor: i % 3 == 0 ? 0.95 : (i % 3 == 1 ? 0.8 : 0.6),
                  height: i == 0 ? 18 : 13,
                ),
              );
            }),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: MobileUtils.isMobile(context) ? 1.6 : 2.0,
          ),
          itemCount: widget.cards,
          itemBuilder: (context, i) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _circle(palette, 36),
                      const SizedBox(width: 10),
                      _bar(palette, width: 90, height: 12),
                    ],
                  ),
                  const Spacer(),
                  _bar(palette, width: double.infinity, height: 14),
                  const SizedBox(height: 8),
                  _bar(palette, width: 120, height: 10),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _bar(palette, width: 70, height: 10),
                      _circle(palette, 24),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerBar(ThemePalette palette, {required double widthFactor, required double height}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: _bar(palette, width: double.infinity, height: height),
    );
  }

  Widget _bar(ThemePalette palette, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            palette.skeletonBase,
            palette.skeletonHighlight,
            palette.skeletonBase,
          ],
          stops: [
            0.3,
            (0.5 + _controller.value * 0.3).clamp(0.35, 0.7),
            1.0,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _circle(ThemePalette palette, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.skeletonBase,
            palette.skeletonHighlight,
            palette.skeletonBase,
          ],
          stops: [
            0.4,
            (0.5 + _controller.value * 0.3).clamp(0.4, 0.7),
            1.0,
          ],
        ),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Cabecera con skeleton para pantallas de carga.
class PPSkeletonHeader extends StatelessWidget {
  const PPSkeletonHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 180, height: 24, decoration: BoxDecoration(color: palette.skeletonBase, borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 10),
        Container(width: 260, height: 14, decoration: BoxDecoration(color: palette.skeletonBase, borderRadius: BorderRadius.circular(8))),
      ],
    );
  }
}