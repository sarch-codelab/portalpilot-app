import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _isInitialized = true;
      debugPrint('✅ HapticService initialized');
    }
  }

  // Feedback ligero para acciones menores
  Future<void> lightImpact() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.lightImpact();
      } catch (e) {
        debugPrint('❌ Error en light impact: $e');
      }
    }
  }

  // Feedback medio para acciones confirmadas
  Future<void> mediumImpact() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('❌ Error en medium impact: $e');
      }
    }
  }

  // Feedback fuerte para acciones importantes
  Future<void> heavyImpact() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (e) {
        debugPrint('❌ Error en heavy impact: $e');
      }
    }
  }

  // Vibración para selección
  Future<void> selectionClick() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.selectionClick();
      } catch (e) {
        debugPrint('❌ Error en selection click: $e');
      }
    }
  }

  // Vibración para éxito
  Future<void> success() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
      } catch (e) {
        debugPrint('❌ Error en success feedback: $e');
      }
    }
  }

  // Vibración para error
  Future<void> error() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        await HapticFeedback.heavyImpact();
      } catch (e) {
        debugPrint('❌ Error en error feedback: $e');
      }
    }
  }

  // Vibración para advertencia
  Future<void> warning() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
      } catch (e) {
        debugPrint('❌ Error en warning feedback: $e');
      }
    }
  }

  // Vibración personalizada con patrón
  Future<void> customPattern({
    required List<int> pattern,
    int repeat = 0,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Android permite patrones personalizados
        // pattern: [duration_on, duration_off, duration_on, duration_off, ...]
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        // Implementación específica para Android si se necesita
      } catch (e) {
        debugPrint('❌ Error en custom pattern: $e');
      }
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS tiene limitaciones en patrones personalizados
      await mediumImpact();
    }
  }

  // Vibración continua (solo Android)
  Future<void> vibrate({
    int duration = 200,
    int amplitude = 128,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Implementación específica para Android
        // Requiere plugin como 'vibrate' si se necesita más control
        await HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('❌ Error en vibrate: $e');
      }
    }
  }

  // Detener vibración (solo Android)
  Future<void> stop() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Implementación específica para Android
      } catch (e) {
        debugPrint('❌ Error en stop vibration: $e');
      }
    }
  }
}