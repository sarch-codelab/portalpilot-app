import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class AuditEntry {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String action;
  final String details;
  final String previousHash;
  final String currentHash;

  AuditEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.action,
    required this.details,
    required this.previousHash,
    required this.currentHash,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'action': action,
        'details': details,
        'previousHash': previousHash,
        'currentHash': currentHash,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        userId: json['userId'],
        action: json['action'],
        details: json['details'],
        previousHash: json['previousHash'],
        currentHash: json['currentHash'],
      );
}

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  List<AuditEntry> _entries = [];
  String _lastHash = '0' * 64; // Genesis hash
  final String _auditFile = 'audit_log.json';

  Future<void> initialize() async {
    await _loadFromDisk();
  }

  String _calculateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<AuditEntry> recordAction({
    required String userId,
    required String action,
    required String details,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();

    // Crear el contenido para hashear
    final content =
        '$id|${timestamp.toIso8601String()}|$userId|$action|$details|$_lastHash';
    final currentHash = _calculateHash(content);

    final entry = AuditEntry(
      id: id,
      timestamp: timestamp,
      userId: userId,
      action: action,
      details: details,
      previousHash: _lastHash,
      currentHash: currentHash,
    );

    _entries.insert(0, entry); // Más reciente primero
    _lastHash = currentHash;

    await _saveToDisk();
    return entry;
  }

  Future<void> _saveToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_auditFile');
      final jsonList = _entries.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving audit log: $e');
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_auditFile');

      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List;
        _entries = jsonList.map((j) => AuditEntry.fromJson(j)).toList();

        // Reconstruir la cadena de hashes
        if (_entries.isNotEmpty) {
          _lastHash = _entries.first.currentHash;
          for (var i = 1; i < _entries.length; i++) {
            // Verificar integridad
            final expectedHash = _entries[i].previousHash;
            final actualHash = _entries[i - 1].currentHash;
            if (expectedHash != actualHash) {
              print(
                  '⚠️ ALERTA: Cadena de auditoría rota en entrada ${_entries[i].id}');
            }
          }
        }
      }
    } catch (e) {
      print('Error loading audit log: $e');
    }
  }

  List<AuditEntry> getEntries({int limit = 50}) {
    return _entries.take(limit).toList();
  }

  bool verifyChainIntegrity() {
    if (_entries.isEmpty) return true;

    var currentHash = _entries.first.currentHash;
    for (var i = 1; i < _entries.length; i++) {
      if (_entries[i].previousHash != currentHash) {
        return false;
      }
      currentHash = _entries[i].currentHash;
    }
    return true;
  }

  String getCurrentHash() => _lastHash;
}
