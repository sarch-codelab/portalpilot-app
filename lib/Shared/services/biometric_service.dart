import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _isInitialized = true;
      debugPrint('✅ BiometricService initialized');
    }
  }

  Future<bool> isDeviceSupported() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return await _localAuth.canCheckBiometrics;
    }
    return false;
  }

  Future<bool> isBiometricAvailable() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final isAvailable = await _localAuth.canCheckBiometrics;
        if (!isAvailable) return false;
        
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        return availableBiometrics.isNotEmpty;
      } catch (e) {
        debugPrint('❌ Error checking biometrics: $e');
        return false;
      }
    }
    return false;
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        return await _localAuth.getAvailableBiometrics();
      } catch (e) {
        debugPrint('❌ Error getting available biometrics: $e');
        return [];
      }
    }
    return [];
  }

  Future<bool> authenticate({
    String localizedReason = 'Por favor autentícate para continuar',
    bool stickyAuth = false,
    bool biometricOnly = false,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: localizedReason,
          options: AuthenticationOptions(
            stickyAuth: stickyAuth,
            biometricOnly: biometricOnly,
          ),
        );
        debugPrint(didAuthenticate ? '✅ Biometric authentication successful' : '❌ Biometric authentication failed');
        return didAuthenticate;
      } catch (e) {
        debugPrint('❌ Biometric authentication error: $e');
        return false;
      }
    }
    return false; // En desktop/web no soportado
  }

  Future<bool> authenticateWithFallback({
    String localizedReason = 'Por favor autentícate para continuar',
    VoidCallback? onFallbackPressed,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: localizedReason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
        return didAuthenticate;
      } catch (e) {
        debugPrint('❌ Biometric authentication error: $e');
        return false;
      }
    }
    return false;
  }

  Future<void> cancelAuthentication() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await _localAuth.stopAuthentication();
      } catch (e) {
        debugPrint('❌ Error cancelling authentication: $e');
      }
    }
  }

  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Huella dactilar';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Autenticación fuerte';
      case BiometricType.weak:
        return 'Autenticación débil';
    }
  }

  Future<String> getAvailableBiometricDescription() async {
    final availableBiometrics = await getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      return 'No hay autenticación biométrica disponible';
    }
    
    final names = availableBiometrics.map(getBiometricTypeName).join(', ');
    return 'Disponible: $names';
  }
}