import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Utilidades defensivas de JSON de Portal Pilot.
///
/// Ningún método de este archivo lanza (FormatException / TypeError) ante
/// datos corruptos: siempre devuelven un fallback seguro (mapa vacío / lista
/// vacía / null). Previene crashes offline con almacenamiento dañado y
/// responde a la causa raíz reportada por QA (ataques de serialización JSON).
///
/// Avisa al usuario cuando hay datos corruptos: [reportCorrupt] invoca al
/// callback global [onCorrupt] (lo registra la raíz de la app para mostrar el
/// toast "Error de sincronización, datos corruptos").
class JsonGuard {
  JsonGuard._();

  /// Mensaje oficial mostrado al usuario ante datos corruptos.
  static const String kCorruptDataMessage = 'Error de sincronización, datos corruptos';

  /// Callback global de aviso (lo registra el arranque de la app).
  static void Function(String source)? onCorrupt;

  /// Reporta datos corruptos por consola y dispara el callback global.
  static void reportCorrupt(String source) {
    debugPrint('⚠️ $source: $kCorruptDataMessage');
    onCorrupt?.call(source);
  }

  /// Decodifica JSON devolviendo `null` si el texto es inválido (nunca lanza).
  static dynamic tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('⚠️ JSON corrupto (formato): ${_preview(raw)} -> $e');
      return null;
    }
  }

  /// Decodifica a `Map<String, dynamic>` o `null` si corrupto / no es objeto.
  static Map<String, dynamic>? tryDecodeMap(String? raw) {
    final decoded = tryDecode(raw);
    return _asStringKeyedMap(decoded);
  }

  /// Convierte cualquier valor a `Map<String, dynamic>` filtrado o `null`.
  static Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } on TypeError {
        return null;
      }
    }
    return null;
  }

  /// Convierte cualquier valor a `List<Map<String, dynamic>>` filtrando
  /// elementos que no sean mapas con claves de tipo String. `[]` si no es
  /// una lista (nunca lanza).
  static List<Map<String, dynamic>> toListOfMaps(dynamic value) {
    if (value is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in value) {
      final m = _asStringKeyedMap(e);
      if (m != null) out.add(m);
    }
    return out;
  }

  /// Convierte cualquier valor a `List<String>` filtrando no-strings. `[]` si
  /// no es una lista (nunca lanza).
  static List<String> toListOfStrings(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  /// Lee un JSON de lista de mapas de forma segura (nunca lanza).
  ///
  /// Usa [onCorrupt] cuando el contenido NO era una lista de mapas válida,
  /// para que la interfaz pueda notificar "Error de sincronización, datos
  /// corruptos" sin interrumpir la app.
  static List<Map<String, dynamic>> safeListOfMaps(
    String? raw, {
    String source = 'datos',
  }) {
    final decoded = tryDecode(raw);
    if (decoded is! List) {
      if (decoded != null) reportCorrupt('$source: no era una lista');
      return const [];
    }
    final maps = toListOfMaps(decoded);
    if (maps.length != decoded.length) {
      reportCorrupt('$source: elementos no-map filtrados');
    }
    return maps;
  }

  /// Lee un JSON de lista de strings de forma segura (nunca lanza).
  static List<String> safeListOfStrings(String? raw, {String source = 'datos'}) {
    final decoded = tryDecode(raw);
    if (decoded is! List) {
      if (decoded != null) reportCorrupt('$source: no era una lista');
      return const [];
    }
    final strings = toListOfStrings(decoded);
    if (strings.length != decoded.length) {
      reportCorrupt('$source: elementos no-string filtrados');
    }
    return strings;
  }

  /// Número seguro: acepta `num` o String parseable; en otro caso `null`.
  static num? numOrNull(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static String _preview(String raw) =>
      raw.length > 80 ? '${raw.substring(0, 80)}…' : raw;
}