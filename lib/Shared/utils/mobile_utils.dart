import 'package:flutter/material.dart';

/// Utilidades responsivas centralizadas de Portal Pilot.
///
/// Rompimientos estandarizados del sistema de diseño:
/// - Móvil compacto:   < 360
/// - Móvil:            < 768
/// - Tablet:           768 – 1024
/// - Desktop compacto: 1024 – 1280
/// - Desktop amplio:   >= 1280
class MobileUtils {
  static const double _minCompact = 360.0;
  static const double _minMobile = 768.0;
  static const double _minDesktop = 1024.0;
  static const double _minWide = 1280.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < _minCompact;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _minMobile;

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    return size >= _minMobile && size < _minDesktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _minDesktop;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _minWide;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Define si la pantalla debe usar navegación lateral (desktop).
  static bool useSidebar(BuildContext context) => isDesktop(context);

  /// Navegación inferior solo en móvil.
  static bool useBottomNav(BuildContext context) => isMobile(context);

  /// Navegación con drawer solo en móvil.
  static bool useDrawer(BuildContext context) => isMobile(context);

  /// Ancho de la barra lateral en desktop.
  static double get sidebarWidth => 264.0;
  static double get sidebarCollapsedWidth => 76.0;

  // Getter para altura de la barra de navegación inferior.
  static double getBottomNavHeight(BuildContext context) {
    return isMobile(context) ? 80.0 : 0.0;
  }

  static double getAppBarHeight(BuildContext context) {
    return isMobile(context)
        ? kToolbarHeight + MediaQuery.of(context).padding.top
        : kToolbarHeight + 8;
  }

  /// Ancho máximo para el contenido (evita lineas infinitas en ultra-wide).
  static double getMaxContentWidth(BuildContext context) {
    return isMobile(context) ? double.infinity : 1280;
  }

  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      bottom: isMobile(context) ? mediaQuery.padding.bottom + 88 : mediaQuery.padding.bottom,
      top: mediaQuery.padding.top,
    );
  }

  static EdgeInsets getCardPadding(BuildContext context) {
    return isMobile(context) ? const EdgeInsets.all(14) : const EdgeInsets.all(22);
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.fromLTRB(16, 12, 16, 24);
    }
    if (isDesktop(context)) {
      return const EdgeInsets.fromLTRB(32, 24, 32, 32);
    }
    return const EdgeInsets.fromLTRB(24, 16, 24, 28);
  }

  static EdgeInsets getSectionPadding(BuildContext context) {
    return isMobile(context)
        ? const EdgeInsets.all(14)
        : const EdgeInsets.all(20);
  }

  static double getElementSpacing(BuildContext context) {
    return isMobile(context) ? 12.0 : 16.0;
  }

  /// Tamaño de fuente ajustada a la pantalla.
  static double responsiveFontSize(BuildContext context, double baseSize) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return baseSize * 0.88;
    if (w < _minMobile) return baseSize;
    if (w < _minDesktop) return baseSize * 1.08;
    return baseSize * 1.16;
  }

  /// Columnas para grids responsivos.
  static int getResponsiveColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < _minMobile) return 1;
    if (w < _minDesktop) return 2;
    if (w < _minWide) return 3;
    return 4;
  }
}