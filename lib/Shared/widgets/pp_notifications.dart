import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';

enum PPNotificationType { success, error, info, warning }

/// Sistema de notificaciones de Portal Pilot.
///
/// Toasts elevados con iconografía de marca y colores de estado. Reemplaza
/// a los `SnackBar` genéricos para mantener una UX consistente.
class PPNotifications {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    PPNotificationType type = PPNotificationType.info,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: _NotificationContent(message: message, title: title, type: type),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 88),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          dismissDirection: DismissDirection.up,
        ),
      );
  }

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: PPNotificationType.success);

  static void error(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: PPNotificationType.error);

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: PPNotificationType.info);

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message: message, title: title, type: PPNotificationType.warning);
}

class _NotificationContent extends StatelessWidget {
  final String message;
  final String? title;
  final PPNotificationType type;

  const _NotificationContent({
    required this.message,
    required this.type,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalette(isDark: appThemeNotifier.isDark);
    final (color, icon) = switch (type) {
      PPNotificationType.success => (palette.successGreen, Icons.check_circle_rounded),
      PPNotificationType.error => (palette.errorRed, Icons.error_rounded),
      PPNotificationType.info => (palette.infoBlue, Icons.info_rounded),
      PPNotificationType.warning => (palette.warningAmber, Icons.warning_amber_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        boxShadow: palette.glowShadow(color, blur: 24, spread: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: palette.textMuted,
                    height: 1.3,
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