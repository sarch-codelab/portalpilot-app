// lib/Shared/services/session_guard.dart
// Guardián de sesión: detecta respuestas del backend con token inválido/vencido
// y fuerza un cierre de sesión + redirección al LoginScreen automáticamente.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Auth/login.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';

class SessionGuard {
  SessionGuard._privateConstructor();
  static final SessionGuard instance = SessionGuard._privateConstructor();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _navigating = false;

  /// Indica si una respuesta del backend corresponde a un token inválido/vencido
  /// (sesión expirada) y NO a un problema de plan, cuota o permisos.
  static bool isTokenExpired(int statusCode, Map<String, dynamic>? data) {
    if (data == null) {
      return statusCode == 401;
    }
    final code = data['code']?.toString();
    final backendError = (data['error']?.toString() ?? '').toLowerCase();

    // Errores que NO son de sesión: no deben provocar logout.
    if (code == 'TRIAL_EXPIRED' ||
        code == 'PLAN_LIMIT' ||
        code == 'PLAN_LIMIT_REACHED' ||
        code == 'AI_TOKEN_LIMIT_REACHED') {
      return false;
    }
    if (backendError.contains('prueba vencida') ||
        backendError.contains('plan no incluye') ||
        backendError.contains('plan superior') ||
        backendError.contains('límite mensual')) {
      return false;
    }

    if (statusCode == 401) {
      // "Token no provisto" y "Sesión revocada" son errores de sesión puros.
      if (backendError.contains('token no provisto') ||
          backendError.contains('sesión revocada') ||
          backendError.contains('sesion revocada') ||
          code == 'SESSION_REVOKED') {
        return true;
      }
      return true;
    }

    if (statusCode == 403) {
      return backendError.contains('token inválido') ||
          backendError.contains('token invalido') ||
          backendError.contains('invalid token') ||
          backendError.contains('token no provisto');
    }

    return false;
  }

  /// Cierra la sesión, limpia tokens y navega al LoginScreen.
  static Future<void> forceLogoutToLogin() async {
    if (_navigating) return;
    _navigating = true;
    try {
      debugPrint('[SessionGuard] Token expirado detectado. Forzando logout...');
      await AuthController.instance.logout();
      ApiService.instance.reset();
      AIManager.instance.reset();
      // Esperar a que los widgets desmonten la sesión antes de navegar.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[SessionGuard] Error forzando logout: $e');
    } finally {
      _navigating = false;
    }
  }
}