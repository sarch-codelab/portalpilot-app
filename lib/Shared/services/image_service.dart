import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();
  
  /// Sube una imagen (base64 o file) y retorna la data URL
  /// Temporalmente no usa Supabase Storage debido a cambios en la API
  Future<String?> uploadImage({
    required String base64OrPath,
    required String bucketName,
    String? folder,
  }) async {
    try {
      // Determinar si es base64 o ruta de archivo
      Uint8List? imageBytes;
      
      if (base64OrPath.startsWith('data:image') || base64OrPath.contains(',')) {
        // Es base64 - retornar tal cual
        return base64OrPath;
      } else if (File(base64OrPath).existsSync()) {
        // Es ruta de archivo - convertir a base64
        imageBytes = await File(base64OrPath).readAsBytes();
        final base64 = base64Encode(imageBytes);
        return 'data:image/jpeg;base64,$base64';
      } else {
        // Es solo base64 sin data URL
        try {
          imageBytes = base64Decode(base64OrPath);
          final base64 = base64Encode(imageBytes);
          return 'data:image/jpeg;base64,$base64';
        } catch (e) {
          debugPrint('❌ Error decodificando imagen: $e');
          return null;
        }
      }
    } catch (e) {
      debugPrint('❌ Error en uploadImage: $e');
      return null;
    }
  }
  
  /// Elimina una imagen (no-op por ahora)
  Future<bool> deleteImage({
    required String imageUrl,
    required String bucketName,
  }) async {
    // No-op por ahora ya que no usamos Supabase Storage
    return true;
  }
  
  /// Convierte base64 a data URL si no lo es
  String toDataUrl(String base64) {
    if (base64.startsWith('data:image')) {
      return base64;
    }
    return 'data:image/jpeg;base64,$base64';
  }
}