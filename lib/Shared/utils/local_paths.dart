import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Redirige las rutas de `path_provider` a una carpeta escribible cuando la app
/// corre en un entorno restringido (por ejemplo un sandbox que solo permite
/// escribir dentro del proyecto). En ese escenario Documents, AppData y Temp
/// quedan en solo lectura y rompen `shared_preferences`, `drift`, backups,
/// logs, PDFs, RPA, etc.
///
/// Se activa con la variable de entorno `PORTAL_PILOT_DATA_DIR`. Si no está
/// definida, no cambia absolutamente nada (comportamiento de producción
/// intacto).
bool configureLocalPaths() {
  final configuredBase = Platform.environment['PORTAL_PILOT_DATA_DIR'];
  final base = configuredBase != null && configuredBase.trim().isNotEmpty
      ? configuredBase.trim()
      : kDebugMode && Platform.isWindows
          ? '${Directory.current.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}portal-pilot-runtime${Platform.pathSeparator}data'
          : null;
  if (base == null || base.trim().isEmpty) return false;
  PathProviderPlatform.instance =
      _DataDirPathProvider(base.trim(), PathProviderPlatform.instance);
  SharedPreferencesStorePlatform.instance = _PrefsStore();
  return true;
}

class _DataDirPathProvider extends PathProviderPlatform {
  _DataDirPathProvider(this.root, this.delegate);

  final String root;
  final PathProviderPlatform delegate;

  Future<String?> _sub(String name) async {
    final dir = Directory('$root${Platform.pathSeparator}$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<String?> getTemporaryPath() => _sub('temp');

  @override
  Future<String?> getApplicationSupportPath() => _sub('support');

  @override
  Future<String?> getApplicationDocumentsPath() => _sub('documents');

  @override
  Future<String?> getApplicationCachePath() => _sub('cache');

  @override
  Future<String?> getLibraryPath() => delegate.getLibraryPath();

  @override
  Future<String?> getExternalStoragePath() => delegate.getExternalStoragePath();

  @override
  Future<List<String>?> getExternalCachePaths() =>
      delegate.getExternalCachePaths();

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) =>
      delegate.getExternalStoragePaths(type: type);

  @override
  Future<String?> getDownloadsPath() => delegate.getDownloadsPath();
}

/// Store de `shared_preferences` que persiste en un JSON dentro del directorio
/// local (vía `getApplicationSupportPath`, ya redirigido a
/// `<PORTAL_PILOT_DATA_DIR>\support`), en lugar de `%APPDATA%`.
///
/// Replica la semántica de filtros por prefijo/allowList de
/// `InMemorySharedPreferencesStore` sin depender del plugin nativo de Windows.
class _PrefsStore extends SharedPreferencesStorePlatform {
  static const String _defaultPrefix = 'flutter.';

  Map<String, Object>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}shared_preferences.json');
  }

  Future<Map<String, Object>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final Map<String, Object> data = <String, Object>{};
    try {
      final file = await _file();
      if (await file.exists()) {
        final text = await file.readAsString();
        if (text.isNotEmpty) {
          final Object? decoded = json.decode(text);
          if (decoded is Map) {
            data.addAll(decoded.cast<String, Object>());
          }
        }
      }
    } catch (_) {
      // Si el archivo está corrupto o no se puede leer, arrancamos vacío.
    }
    _cache = data;
    return data;
  }

  Future<bool> _persist(Map<String, Object> data) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(json.encode(data));
      _cache = data;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    final data = await _load();
    data.remove(key);
    return _persist(data);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final data = await _load();
    data[key] = value;
    return _persist(data);
  }

  @override
  Future<bool> clear() => clearWithParameters(
        ClearParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
      );

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
        ClearParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filter = parameters.filter;
    final data = await _load();
    data.removeWhere(
      (String key, _) =>
          key.startsWith(filter.prefix) &&
          (filter.allowList == null || filter.allowList!.contains(key)),
    );
    return _persist(data);
  }

  @override
  Future<Map<String, Object>> getAll() => getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: _defaultPrefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filter = parameters.filter;
    final preferences = Map<String, Object>.from(await _load());
    preferences.removeWhere(
      (String key, _) =>
          !key.startsWith(filter.prefix) ||
          (filter.allowList != null && !filter.allowList!.contains(key)),
    );
    return preferences;
  }
}