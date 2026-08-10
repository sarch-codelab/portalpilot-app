import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Sistema de caché local para optimizar rendimiento
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  static const String _prefix = 'cache_';
  static const int _defaultCacheDuration = 3600; // 1 hora en segundos

  /// Guardar datos en caché
  Future<bool> set(String key, dynamic data, {int durationSeconds = _defaultCacheDuration}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final expiry = timestamp + (durationSeconds * 1000);
      
      final cacheData = {
        'data': data,
        'expiry': expiry,
        'timestamp': timestamp,
      };
      
      return await prefs.setString('$_prefix$key', jsonEncode(cacheData));
    } catch (e) {
      print('Error al guardar en caché: $e');
      return false;
    }
  }

  /// Obtener datos de caché
  Future<T?> get<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('$_prefix$key');
      
      if (cachedData == null) return null;
      
      final decoded = jsonDecode(cachedData);
      final expiry = decoded['expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Verificar si el caché ha expirado
      if (now > expiry) {
        await remove(key);
        return null;
      }
      
      return decoded['data'] as T;
    } catch (e) {
      print('Error al obtener de caché: $e');
      return null;
    }
  }

  /// Eliminar datos de caché
  Future<bool> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('$_prefix$key');
    } catch (e) {
      print('Error al eliminar de caché: $e');
      return false;
    }
  }

  /// Limpiar todo el caché
  Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
      
      return true;
    } catch (e) {
      print('Error al limpiar caché: $e');
      return false;
    }
  }

  /// Limpiar caché expirado
  Future<void> clearExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          final cachedData = prefs.getString(key);
          if (cachedData != null) {
            final decoded = jsonDecode(cachedData);
            final expiry = decoded['expiry'] as int;
            
            if (now > expiry) {
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      print('Error al limpiar caché expirado: $e');
    }
  }

  /// Verificar si existe en caché y es válido
  Future<bool> isValid(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('$_prefix$key');
      
      if (cachedData == null) return false;
      
      final decoded = jsonDecode(cachedData);
      final expiry = decoded['expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      return now <= expiry;
    } catch (e) {
      return false;
    }
  }
}