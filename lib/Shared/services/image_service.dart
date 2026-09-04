import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _defaultApiRoot = String.fromEnvironment(
  'WEB_DOMAIN',
  defaultValue: 'https://portalpilot-app.vercel.app',
);

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  /// Sube una imagen (base64 o ruta de archivo) a Supabase Storage vía el API.
  /// Retorna únicamente la URL pública creada en Supabase Storage.
  Future<String?> uploadImage({
    required String base64OrPath,
    required String bucketName,
    String? folder,
  }) async {
    try {
      // Determinar si es base64 o ruta de archivo
      final String dataUrl;
      if (base64OrPath.startsWith('data:image') || base64OrPath.contains(',')) {
        dataUrl = base64OrPath;
      } else if (File(base64OrPath).existsSync()) {
        final imageBytes = await File(base64OrPath).readAsBytes();
        dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      } else {
        try {
          final imageBytes = base64Decode(base64OrPath);
          dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
        } catch (e) {
          debugPrint('❌ Error decodificando imagen: $e');
          return null;
        }
      }

      final remoteUrl = await _subirASupabaseStorage(
        dataUrl,
        bucketName: bucketName,
        folder: folder,
      );
      if (remoteUrl != null) return remoteUrl;

      // No guardar data URLs como si fueran archivos sincronizados en la nube.
      return null;
    } catch (e) {
      debugPrint('❌ Error en uploadImage: $e');
      return null;
    }
  }

  /// Elimina una imagen de Supabase Storage (no-op si no es una URL de storage).
  Future<bool> deleteImage({
    required String imageUrl,
    required String bucketName,
  }) async {
    if (!imageUrl.contains('/storage/v1/object/')) return true;
    try {
      final response = await http
          .post(
            Uri.parse('$_defaultApiRoot/api/storage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'delete',
              'bucket': bucketName,
              'url': imageUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['deleted'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error eliminando imagen: $e');
      return false;
    }
  }

  Future<String?> _subirASupabaseStorage(
    String dataUrl, {
    required String bucketName,
    String? folder,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_defaultApiRoot/api/storage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'upload',
              'bucket': bucketName,
              'folder': folder ?? '',
              'base64': dataUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      debugPrint(
        '⚠️ Falló subida a Storage (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      debugPrint('⚠️ Error en _subirASupabaseStorage: $e');
    }
    return null;
  }

  /// Convierte base64 a data URL si no lo es
  String toDataUrl(String base64) {
    if (base64.startsWith('data:image')) {
      return base64;
    }
    return 'data:image/jpeg;base64,$base64';
  }
}
