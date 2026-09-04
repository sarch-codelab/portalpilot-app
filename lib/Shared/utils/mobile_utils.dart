import 'package:flutter/material.dart';

class MobileUtils {
  // Verifica si es dispositivo móvil
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  // Verifica si es tablet
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 768 && size.width < 1024;
  }

  // Verifica si es desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  // Obtiene padding de Safe Area personalizado
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobileDevice = isMobile(context);
    
    return EdgeInsets.only(
      bottom: isMobileDevice ? mediaQuery.padding.bottom + 80 : mediaQuery.padding.bottom,
      top: mediaQuery.padding.top,
    );
  }

  // Obtiene altura de la barra de navegación inferior
  static double getBottomNavHeight(BuildContext context) {
    return isMobile(context) ? 80.0 : 0.0;
  }

  // Obtiene altura del AppBar personalizado
  static double getAppBarHeight(BuildContext context) {
    final isMobileDevice = isMobile(context);
    return isMobileDevice ? kToolbarHeight + MediaQuery.of(context).padding.top : kToolbarHeight;
  }

  // Obtiene ancho máximo para contenido en móvil
  static double getMaxContentWidth(BuildContext context) {
    return isMobile(context) ? double.infinity : 1200;
  }

  // Wrapper para SafeArea con ajustes móviles
  static Widget safeAreaWrapper({
    required Widget child,
    bool maintainBottomViewPadding = true,
  }) {
    return SafeArea(
      maintainBottomViewPadding: maintainBottomViewPadding,
      child: child,
    );
  }

  // Obtiene el padding apropiado para tarjetas en móvil
  static EdgeInsets getCardPadding(BuildContext context) {
    return isMobile(context) 
        ? const EdgeInsets.all(16) 
        : const EdgeInsets.all(24);
  }

  // Obtiene el espaciado apropiado entre elementos
  static double getElementSpacing(BuildContext context) {
    return isMobile(context) ? 12.0 : 16.0;
  }

  // Obtiene el tamaño de fuente apropiado
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return baseSize * 0.9;
    if (screenWidth < 600) return baseSize;
    if (screenWidth < 900) return baseSize * 1.1;
    return baseSize * 1.2;
  }

  // Obtiene el número de columnas para grid responsivo
  static int getResponsiveColumns(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 1;
    if (screenWidth < 900) return 2;
    if (screenWidth < 1200) return 3;
    return 4;
  }
}