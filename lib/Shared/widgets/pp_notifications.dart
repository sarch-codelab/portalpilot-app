import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

enum PPNotificationType { success, error, info, warning }

/// Sistema de notificaciones de Portal Pilot — diseño estilo *Sileo*
/// (https://sileo.aaryan.design): tarjetas apiladas en la parte superior,
/// blur de fondo, tipografía iOS, barra de progreso de tiempo restante,
/// tap o swipe vertical para cerrar.
///
/// Uso:
/// ```dart
/// PPNotifications.success(context, 'Producto guardado');
/// PPNotifications.error(context, 'No se pudo conectar', title: 'Error de red');
/// ```
class PPNotifications {
  PPNotifications._();

  static final _ToastQueue _queue = _ToastQueue();
  static OverlayEntry? _hostEntry;
  static const int _maxVisible = 4;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    PPNotificationType type = PPNotificationType.info,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // Fallback elegante si no hay overlay disponible.
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(_fallbackSnackBar(context, message, title, type, duration));
      return;
    }

    _ensureHost(overlay);
    final toast = _ToastData(
      message: message,
      title: title,
      type: type,
      duration: duration,
    );
    _queue.push(toast);
  }

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title ?? 'Listo', type: PPNotificationType.success);

  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title ?? 'Ups, algo salió mal', type: PPNotificationType.error);

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title ?? 'Portal Pilot', type: PPNotificationType.info);

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title ?? 'Atención', type: PPNotificationType.warning);

  /// Cierra todos los toasts visibles.
  static void dismissAll() {
    for (final t in List<_ToastData>.from(_queue.items)) {
      t.dismiss();
    }
  }

  // ── Host: una sola OverlayEntry que dibuja la pila de toasts ──────────────

  static void _ensureHost(OverlayState overlay) {
    if (_hostEntry != null) return;
    _hostEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        ignoring: false,
        child: AnimatedBuilder(
          animation: _queue,
          builder: (context, _) {
            final toasts = _queue.items;
            if (toasts.isEmpty) return const SizedBox.shrink();
            final mq = MediaQuery.of(context);
            final isDesktop = mq.size.width >= 700;
            // Estilo Sileo: tarjetas compactas. En PC van apiladas arriba a
            // la derecha (máx. 380px); en teléfono ocupan el ancho útil.
            return Positioned(
              top: mq.padding.top + (isDesktop ? 12 : 8),
              left: isDesktop ? 12 : 0,
              right: isDesktop ? 12 : 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
                children: [
                  for (final t in toasts)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 380 : double.infinity,
                        ),
                        child: _ToastCard(key: ValueKey(t.id), toast: t),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    overlay.insert(_hostEntry!);
    // Cuando la cola queda vacía, retirar el host en el siguiente frame.
    _queue.addListener(() {
      if (_queue.items.isEmpty && _hostEntry != null) {
        final entry = _hostEntry;
        _hostEntry = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => entry?.remove());
      }
    });
  }

  static SnackBar _fallbackSnackBar(
    BuildContext context,
    String message,
    String? title,
    PPNotificationType type,
    Duration duration,
  ) {
    final palette = appPalette;
    final color = switch (type) {
      PPNotificationType.success => palette.successGreen,
      PPNotificationType.error => palette.errorRed,
      PPNotificationType.info => palette.infoBlue,
      PPNotificationType.warning => palette.warningAmber,
    };
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: palette.cardElevated,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          Icon(_iconFor(type), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: palette.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(PPNotificationType type) => switch (type) {
        PPNotificationType.success => Icons.check_circle_rounded,
        PPNotificationType.error => Icons.error_rounded,
        PPNotificationType.info => Icons.info_rounded,
        PPNotificationType.warning => Icons.warning_amber_rounded,
      };
}

// ────────────────────────────── Cola ─────────────────────────────────────────

class _ToastQueue extends ChangeNotifier {
  final List<_ToastData> items = [];

  void push(_ToastData toast) {
    // Si ya existe un toast con el mismo mensaje, no bombardear con duplicados
    final alreadyExists = items.any((it) => it.message == toast.message);
    if (alreadyExists) return;

    // Límite visible: descarta el más antiguo del final de la cola
    while (items.length >= PPNotifications._maxVisible) {
      items.removeLast();
    }
    items.insert(0, toast); // El más nuevo arriba.
    notifyListeners();
  }

  void remove(_ToastData toast) {
    items.remove(toast);
    notifyListeners();
  }
}

class _ToastData {
  static int _nextId = 0;
  final int id = _nextId++;
  final String message;
  final String? title;
  final PPNotificationType type;
  final Duration duration;
  _ToastData({
    required this.message,
    required this.title,
    required this.type,
    required this.duration,
  });

  void Function()? _onDismissRequested;

  void dismiss() => _onDismissRequested?.call();
}

// ──────────────────────────── Tarjeta toast ─────────────────────────────────

class _ToastCard extends StatefulWidget {
  final _ToastData toast;
  const _ToastCard({super.key, required this.toast});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _enter;
  late final AnimationController _progress;
  late final AnimationController _glow;
  bool _closing = false;
  final bool _dragging = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _progress = AnimationController(
      vsync: this,
      duration: widget.toast.duration,
    );
    // Pulso de entrada del glifo (dos latidos suaves), estilo Sileo.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.toast._onDismissRequested = _close;
    _enter.forward().then((_) {
      _glow.forward();
      _progress.forward();
    });
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) _close();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pausa el temporizador cuando la app no está en primer plano.
    if (state == AppLifecycleState.resumed) {
      if (!_closing && !_dragging) _progress.forward();
    } else {
      _progress.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
    _progress.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _enter.reverse().then((_) {
      if (!mounted) return;
      _ToastQueueHolder.remove(context, widget.toast);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette;
    final (color, icon) = _colorsFor(widget.toast.type, palette);

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        final dy = (1 - t) * -60;
        final closingLift = _closing ? -18.0 : 0.0;
        // Resorte suave estilo Sileo en la entrada (overshoot mínimo).
        final ts = Curves.easeOutBack.transform(_enter.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, dy + closingLift + _dragOffset),
            child: Transform.scale(
              scale: 0.92 + 0.08 * ts,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          onVerticalDragUpdate: (d) =>
              setState(() => _dragOffset += d.delta.dy),
          onVerticalDragEnd: (d) {
            if (_dragOffset < -36 || (d.primaryVelocity ?? 0) < -220) {
              _close();
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? const Color(0xE61A1526)
                        : const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.isDark
                            ? Colors.black.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Glifo iOS: cuadrado redondeado con tinte del estado
                            // y un pulso de entrada.
                            AnimatedBuilder(
                              animation: _glow,
                              builder: (context, child) {
                                final t = Curves.easeOutBack.transform(
                                  _glow.value.clamp(0, 1),
                                );
                                return Transform.scale(
                                  scale: 0.6 + 0.4 * t,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                        alpha: 0.14 + 0.08 * (1 - _glow.value),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: color, size: 19),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.toast.title != null)
                                    Text(
                                      widget.toast.title!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        color: palette.textPrimary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  Text(
                                    widget.toast.message,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: palette.textMuted,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _close,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: palette.textDim,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData) _colorsFor(PPNotificationType type, ThemePalette palette) =>
      switch (type) {
        PPNotificationType.success => (
            palette.successGreen,
            Icons.check_circle_rounded
          ),
        PPNotificationType.error => (palette.errorRed, Icons.error_rounded),
        PPNotificationType.info => (palette.infoBlue, Icons.info_rounded),
        PPNotificationType.warning =>
          (palette.warningAmber, Icons.warning_amber_rounded),
      };
}

/// Puente para que [_ToastCard] pueda pedir a la cola que retire su toast
/// (la cola es privada del módulo de notificaciones).
class _ToastQueueHolder {
  static void remove(BuildContext context, _ToastData toast) {
    // La cola estática vive en PPNotifications; accedemos por reflexión
    // trivial: mismo archivo, sin imports.
    PPNotifications._queue.remove(toast);
  }
}
