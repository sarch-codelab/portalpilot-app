import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sistema de backup y recuperación de datos
class BackupManager {
  static final BackupManager _instance = BackupManager._internal();
  factory BackupManager() => _instance;
  BackupManager._internal();

  static const String _backupDirectory = 'backups';
  static const int _maxBackups = 10;

  /// Crear backup completo
  Future<String> createBackup({String? customName}) async {
    try {
      final timestamp = DateTime.now();
      final backupName = customName ?? 'backup_${DateFormat('yyyyMMdd_HHmmss').format(timestamp)}';
      
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/$_backupDirectory');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final backupFile = File('${backupDir.path}/$backupName.json');
      
      // Recopilar todos los datos
      final backupData = await _collectAllData();
      
      // Agregar metadatos
      backupData['metadata'] = {
        'version': '1.0.0',
        'created_at': timestamp.toIso8601String(),
        'app_version': '1.0.0', // Actualizar con versión real
        'platform': Platform.operatingSystem,
      };

      // Escribir backup
      await backupFile.writeAsString(jsonEncode(backupData));
      
      // Limpiar backups antiguos
      await _cleanOldBackups(backupDir);
      
      return backupFile.path;
    } catch (e) {
      throw Exception('Error al crear backup: $e');
    }
  }

  /// Recopilar todos los datos para backup
  Future<Map<String, dynamic>> _collectAllData() async {
    final data = <String, dynamic>{};
    
    // Datos de SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final allPrefs = prefs.getKeys();
    
    for (final key in allPrefs) {
      if (!key.startsWith('cache_')) { // No incluir caché
        data['shared_preferences_$key'] = prefs.get(key);
      }
    }
    
    // Aquí se agregarían datos de la base de datos local
    // Por ahora, placeholder para datos de inventario, clientes, etc.
    data['inventario'] = [];
    data['clientes'] = [];
    data['ventas'] = [];
    data['membresias'] = [];
    
    return data;
  }

  /// Restaurar backup
  Future<void> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      
      if (!await backupFile.exists()) {
        throw Exception('Archivo de backup no encontrado');
      }

      final backupContent = await backupFile.readAsString();
      final backupData = jsonDecode(backupContent) as Map<String, dynamic>;
      
      // Validar backup
      if (!_validateBackup(backupData)) {
        throw Exception('Backup inválido o corrupto');
      }

      // Restaurar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      for (final key in backupData.keys) {
        if (key.startsWith('shared_preferences_')) {
          final prefKey = key.replaceFirst('shared_preferences_', '');
          final value = backupData[key];
          
          if (value is String) {
            await prefs.setString(prefKey, value);
          } else if (value is int) {
            await prefs.setInt(prefKey, value);
          } else if (value is double) {
            await prefs.setDouble(prefKey, value);
          } else if (value is bool) {
            await prefs.setBool(prefKey, value);
          }
        }
      }
      
      // Aquí se restaurarían datos de la base de datos local
      // Por ahora, placeholder
      
    } catch (e) {
      throw Exception('Error al restaurar backup: $e');
    }
  }

  /// Validar integridad del backup
  bool _validateBackup(Map<String, dynamic> backupData) {
    try {
      final metadata = backupData['metadata'] as Map<String, dynamic>?;
      
      if (metadata == null) {
        return false;
      }
      
      final version = metadata['version'] as String?;
      final createdAt = metadata['created_at'] as String?;
      
      if (version == null || createdAt == null) {
        return false;
      }
      
      // Validar formato de fecha
      DateTime.parse(createdAt);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener lista de backups disponibles
  Future<List<BackupInfo>> getAvailableBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/$_backupDirectory');
      
      if (!await backupDir.exists()) {
        return [];
      }

      final files = backupDir.listSync().whereType<File>().toList();
      final backups = <BackupInfo>[];
      
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final metadata = data['metadata'] as Map<String, dynamic>?;
          
          if (metadata != null) {
            backups.add(BackupInfo(
              path: file.path,
              name: file.path.split('/').last,
              createdAt: DateTime.parse(metadata['created_at'] as String),
              version: metadata['version'] as String?,
              size: await file.length(),
            ));
          }
        } catch (e) {
          // Skip corrupted backups
          continue;
        }
      }
      
      // Ordenar por fecha descendente
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return backups;
    } catch (e) {
      print('Error al obtener backups: $e');
      return [];
    }
  }

  /// Eliminar backup específico
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error al eliminar backup: $e');
      return false;
    }
  }

  /// Limpiar backups antiguos
  Future<void> _cleanOldBackups(Directory backupDir) async {
    try {
      final files = backupDir.listSync().whereType<File>().toList();
      
      if (files.length <= _maxBackups) {
        return;
      }
      
      // Ordenar por fecha de modificación descendente
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      // Eliminar backups más allá del límite
      for (int i = _maxBackups; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (e) {
      print('Error al limpiar backups antiguos: $e');
    }
  }

  /// Exportar backup a ubicación específica
  Future<String> exportBackup(String backupPath, String exportPath) async {
    try {
      final backupFile = File(backupPath);
      final exportFile = File(exportPath);
      
      await backupFile.copy(exportPath);
      
      return exportPath;
    } catch (e) {
      throw Exception('Error al exportar backup: $e');
    }
  }

  /// Importar backup desde ubicación específica
  Future<String> importBackup(String importPath) async {
    try {
      final importFile = File(importPath);
      
      if (!await importFile.exists()) {
        throw Exception('Archivo de importación no encontrado');
      }

      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/$_backupDirectory');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now();
      final backupName = 'imported_${DateFormat('yyyyMMdd_HHmmss').format(timestamp)}.json';
      final backupPath = '${backupDir.path}/$backupName';
      
      await importFile.copy(backupPath);
      
      return backupPath;
    } catch (e) {
      throw Exception('Error al importar backup: $e');
    }
  }
}

/// Información de backup
class BackupInfo {
  final String path;
  final String name;
  final DateTime createdAt;
  final String? version;
  final int size;

  BackupInfo({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.version,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedDate {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt);
  }
}