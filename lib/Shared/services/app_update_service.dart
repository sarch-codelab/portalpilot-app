import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

/// Información de una actualización disponible
class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final bool forceUpdate;
  final List<String> changelog;
  final int minSupportedVersionCode;

  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.forceUpdate,
    required this.changelog,
    required this.minSupportedVersionCode,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      apkUrl: json['apkUrl'] as String,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      changelog: (json['changelog'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      minSupportedVersionCode: json['minSupportedVersionCode'] as int? ?? 0,
    );
  }
}

/// Servicio de auto-actualización para APKs distribuidas fuera de Play Store
class AppUpdateService {
  AppUpdateService._privateConstructor();
  static final AppUpdateService instance = AppUpdateService._privateConstructor();

  static const String _endpoint = '/api/app-version';
  static const String _prefsLastCheck = 'last_update_check';
  static const String _prefsDismissedVersion = 'dismissed_update_version';
  static const int _checkIntervalHours = 4;

  bool _isChecking = false;
  AppUpdateInfo? _pendingUpdate;
  final _updateController = StreamController<AppUpdateInfo>.broadcast();

  Stream<AppUpdateInfo> get updateStream => _updateController.stream;
  AppUpdateInfo? get pendingUpdate => _pendingUpdate;
  bool get hasPendingUpdate => _pendingUpdate != null;

  /// Verifica si hay actualización disponible
  /// [force] - forzar verificación ignorando cache
  /// [silent] - no emitir en stream, solo actualizar _pendingUpdate
  Future<AppUpdateInfo?> checkForUpdate({
    bool force = false,
    bool silent = false,
  }) async {
    if (_isChecking && !force) return _pendingUpdate;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCheck = prefs.getInt(_prefsLastCheck) ?? 0;

    if (!force && now - lastCheck < _checkIntervalHours * 60 * 60 * 1000) {
      debugPrint('[AppUpdateService] Check skipped (cache válido)');
      return _pendingUpdate;
    }

    _isChecking = true;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('[AppUpdateService] Verificando actualización... v$currentVersionCode');

      // Inicializar ApiService si no está inicializado
      await ApiService.instance.initialize();
      final response = await ApiService.instance.get(_endpoint);
      if (ApiService.instance.isSuccess(response)) {
        final updateInfo = AppUpdateInfo.fromJson(response);

        // Guardar timestamp de verificación
        await prefs.setInt(_prefsLastCheck, now);

        // Verificar si la versión actual es menor a la mínima soportada
        final mustUpdate = currentVersionCode < updateInfo.minSupportedVersionCode;
        final hasNewVersion = updateInfo.versionCode > currentVersionCode;

        if (hasNewVersion || mustUpdate) {
          _pendingUpdate = updateInfo;
          if (!silent) _updateController.add(updateInfo);
          debugPrint('[AppUpdateService] Nueva versión: ${updateInfo.versionName} (${updateInfo.versionCode})');
          Logger().audit('update_check', 'app', 'update_available',
              userId: 'system', module: 'update',
              changes: {'current': currentVersionCode, 'latest': updateInfo.versionCode});
        } else {
          _pendingUpdate = null;
          debugPrint('[AppUpdateService] App actualizada');
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error verificando actualización: $e');
    } finally {
      _isChecking = false;
    }
    return _pendingUpdate;
  }

  /// Descarga e instala el APK (usa código nativo Android via MethodChannel)
  Future<void> downloadAndInstall(AppUpdateInfo updateInfo) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('Auto-update solo disponible en Android');
    }

    const channel = MethodChannel('portal_pilot/app_update');
    try {
      await channel.invokeMethod('downloadAndInstall', {
        'apkUrl': updateInfo.apkUrl,
        'versionName': updateInfo.versionName,
        'versionCode': updateInfo.versionCode,
      });
    } on PlatformException catch (e) {
      debugPrint('[AppUpdateService] Error nativo: ${e.message}');
      throw Exception('Error iniciando descarga: ${e.message}');
    }
  }

  /// Marca una versión como descartada (para actualizaciones no forzadas)
  Future<void> dismissVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsDismissedVersion, versionCode);
  }

  /// Verifica si una versión fue descartada por el usuario
  Future<bool> isVersionDismissed(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsDismissedVersion) == versionCode;
  }

  /// Limpia el estado de actualización pendiente
  void clearPendingUpdate() {
    _pendingUpdate = null;
  }

  /// Inicia verificación periódica en background
  void startPeriodicCheck() {
    Timer.periodic(const Duration(hours: _checkIntervalHours), (_) {
      checkForUpdate(silent: true);
    });
  }

  void dispose() {
    _updateController.close();
  }
}