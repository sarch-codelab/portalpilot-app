import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

/// Paneles divididos redimensionables (desktop).
///
/// Permite arrastrar el divisor para cambiar el ancho de los paneles,
/// ideal para dashboard/analytics con varios paneles.
class PPResizablePanels extends StatefulWidget {
  final List<Widget> children;
  final List<double> initialFractions;
  final Axis direction;

  const PPResizablePanels({
    super.key,
    required this.children,
    this.initialFractions = const [0.5, 0.5],
    this.direction = Axis.horizontal,
  });

  @override
  State<PPResizablePanels> createState() => _PPResizablePanelsState();
}

class _PPResizablePanelsState extends State<PPResizablePanels> {
  late List<double> _fractions;

  @override
  void initState() {
    super.initState();
    _fractions = List.of(widget.initialFractions);
    _normalize();
  }

  void _normalize() {
    if (_fractions.isEmpty) {
      _fractions = List.filled(widget.children.length, 1 / widget.children.length);
    }
    final sum = _fractions.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < _fractions.length; i++) {
      _fractions[i] = _fractions[i] / sum;
    }
  }

  @override
  void didUpdateWidget(PPResizablePanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFractions != widget.initialFractions) {
      _fractions = List.of(widget.initialFractions);
      _normalize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final isVertical = widget.direction == Axis.vertical;

    if (widget.children.length == 1) return widget.children.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = isVertical ? constraints.maxHeight : constraints.maxWidth;

        final panels = <Widget>[];
        for (var i = 0; i < widget.children.length; i++) {
          final size = total * _fractions[i];
          final current = SizedBox(
            width: isVertical ? null : size,
            height: isVertical ? size : null,
            child: widget.children[i],
          );

          if (i == 0) {
            panels.add(current);
            panels.add(_divider(i, palette, isVertical));
          } else if (i == widget.children.length - 1) {
            panels.add(current);
          } else {
            panels.add(current);
            panels.add(_divider(i, palette, isVertical));
          }
        }

        return ClipRect(
          child: isVertical
              ? Column(children: panels)
              : Row(children: panels),
        );
      },
    );
  }

  Widget _divider(int index, ThemePalette palette, bool vertical) {
    return MouseRegion(
      cursor: vertical ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onPanUpdate: (details) {
          final delta = vertical ? details.delta.dy : details.delta.dx;
          final totalRef = (vertical
                      ? MediaQuery.of(context).size.height
                      : MediaQuery.of(context).size.width) *
                  0.5 +
              1;
          _fractions[index] += delta / totalRef;
          if (_fractions[index] < 0.15) _fractions[index] = 0.15;
          if (_fractions[index] > 0.75) _fractions[index] = 0.75;
          _normalize();
          setState(() {});
        },
        child: SizedBox(
          width: vertical ? double.infinity : 4,
          height: vertical ? 4 : double.infinity,
          child: MouseRegion(
            child: Container(
              color: palette.borderLight,
              child: Center(
                child: Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: palette.brand.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conveniencia: dos paneles lado a lado redimensionables.
class PPSplitView extends PPResizablePanels {
  PPSplitView({
    super.key,
    required Widget left,
    required Widget right,
    double leftFraction = 0.45,
  }) : super(
          children: [left, right],
          initialFractions: [leftFraction, 1 - leftFraction],
        );
}