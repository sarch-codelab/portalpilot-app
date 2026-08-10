import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Niveles de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Sistema de logs y auditoría para producción
class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 5;
  static const String _logDirectory = 'logs';

  /// Escribir log
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? metadata,
    String? userId,
    String? module,
  }) async {
    try {
      final timestamp = DateTime.now();
      final logEntry = {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'message': message,
        'user_id': userId,
        'module': module,
        'metadata': metadata,
      };

      final logLine = jsonEncode(logEntry);
      await _writeToFile(logLine);
      
      // En producción, también enviar a servidor
      if (level == LogLevel.error || level == LogLevel.critical) {
        await _sendToServer(logEntry);
      }
    } catch (e) {
      print('Error al escribir log: $e');
    }
  }

  /// Log de nivel debug
  Future<void> debug(String message, {Map<String, dynamic>? metadata, String? userId, String? module}) async {
    await log(LogLevel.debug, message, metadata: metadata, userId: userId, module: module);
  }

  /// Log de nivel info
  Future<void> info(String message, {Map<String, dynamic>? metadata, String? userId, String? module}) async {
    await log(LogLevel.info, message, metadata: metadata, userId: userId, module: module);
  }

  /// Log de nivel warning
  Future<void> warning(String message, {Map<String, dynamic>? metadata, String? userId, String? module}) async {
    await log(LogLevel.warning, message, metadata: metadata, userId: userId, module: module);
  }

  /// Log de nivel error
  Future<void> error(String message, {Map<String, dynamic>? metadata, String? userId, String? module}) async {
    await log(LogLevel.error, message, metadata: metadata, userId: userId, module: module);
  }

  /// Log de nivel critical
  Future<void> critical(String message, {Map<String, dynamic>? metadata, String? userId, String? module}) async {
    await log(LogLevel.critical, message, metadata: metadata, userId: userId, module: module);
  }

  /// Log de auditoría
  Future<void> audit(
    String action,
    String entity,
    String entityId, {
    Map<String, dynamic>? changes,
    String? userId,
    String? module,
  }) async {
    await log(
      LogLevel.info,
      'AUDIT: $action on $entity:$entityId',
      metadata: {
        'action': action,
        'entity': entity,
        'entity_id': entityId,
        'changes': changes,
      },
      userId: userId,
      module: module,
    );
  }

  /// Escribir log a archivo
  Future<void> _writeToFile(String logLine) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/$_logDirectory');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final logFileName = 'app_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.log';
      final logFile = File('${logDir.path}/$logFileName');

      // Verificar tamaño del archivo
      if (await logFile.exists()) {
        final fileSize = await logFile.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogs(logDir);
        }
      }

      await logFile.writeAsString('$logLine\n', mode: FileMode.append, flush: true);
    } catch (e) {
      print('Error al escribir log a archivo: $e');
    }
  }

  /// Rotar logs antiguos
  Future<void> _rotateLogs(Directory logDir) async {
    try {
      final files = logDir.listSync().whereType<File>().toList();
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Eliminar logs antiguos si exceden el máximo
      if (files.length > _maxLogFiles) {
        for (int i = _maxLogFiles; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      print('Error al rotar logs: $e');
    }
  }

  /// Enviar log a servidor (para producción)
  Future<void> _sendToServer(Map<String, dynamic> logEntry) async {
    // Implementar envío a servidor de logs
    // Esto es un placeholder para producción
    try {
      // Aquí se implementaría el envío a un servicio de logs centralizado
      // como Sentry, Loggly, o un servidor propio
      print('LOG PARA SERVIDOR: ${jsonEncode(logEntry)}');
    } catch (e) {
      print('Error al enviar log a servidor: $e');
    }
  }

  /// Leer logs recientes
  Future<List<String>> getRecentLogs({int lines = 100}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/$_logDirectory');
      
      if (!await logDir.exists()) {
        return [];
      }

      final logFileName = 'app_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.log';
      final logFile = File('${logDir.path}/$logFileName');

      if (!await logFile.exists()) {
        return [];
      }

      final contents = await logFile.readAsLines();
      return contents.reversed.take(lines).toList();
    } catch (e) {
      print('Error al leer logs: $e');
      return [];
    }
  }

  /// Limpiar logs antiguos
  Future<void> cleanOldLogs({int daysToKeep = 7}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/$_logDirectory');
      
      if (!await logDir.exists()) {
        return;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final files = logDir.listSync().whereType<File>().toList();

      for (final file in files) {
        if (file.lastModifiedSync().isBefore(cutoffDate)) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error al limpiar logs antiguos: $e');
    }
  }
}