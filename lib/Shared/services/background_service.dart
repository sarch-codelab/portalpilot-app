import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/utils/mobile_utils.dart';

class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  static const String _basePath = 'assets/img/fondos';

  String getBackgroundPath({
    required BuildContext context,
    required bool isDark,
  }) {
    final isMobile = MobileUtils.isMobile(context);
    final deviceType = isMobile ? 'phone' : 'pc';
    final themeSuffix = isDark ? 'dark' : 'light';
    return '$_basePath/${deviceType}_$themeSuffix.png';
  }

  Widget buildBackground({
    required BuildContext context,
    required bool isDark,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    ColorFilter? colorFilter,
  }) {
    final path = getBackgroundPath(context: context, isDark: isDark);
    Widget image = Image.asset(
      path,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
    );
    if (colorFilter != null) {
      image = ColorFiltered(colorFilter: colorFilter, child: image);
    }
    return image;
  }

  BoxDecoration backgroundDecoration({
    required BuildContext context,
    required bool isDark,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    ColorFilter? colorFilter,
  }) {
    final path = getBackgroundPath(context: context, isDark: isDark);
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(path),
        fit: fit,
        alignment: alignment,
        colorFilter: colorFilter,
      ),
    );
  }
}