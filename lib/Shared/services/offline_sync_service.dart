import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/services/connectivity_service.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  final ConnectivityService _connectivityService = ConnectivityService.instance;
  final ApiService _apiService = ApiService.instance;
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _hasPendingSync = false;
  
  final List<Map<String, dynamic>> _pendingOperations = [];
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  bool get isSyncing => _isSyncing;
  bool get hasPendingSync => _hasPendingSync;
  int get pendingOperationsCount => _pendingOperations.length;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _connectivityService.initialize();
    
    // Escuchar cambios de conectividad
    _connectivityService.connectivityStream.listen((isOnline) {
      if (isOnline && _hasPendingSync) {
        debugPrint('📡 Conexión restaurada, iniciando sincronización...');
        _performSync();
      }
    });
    
    _isInitialized = true;
    debugPrint('✅ OfflineSyncService initialized');
  }

  Future<void> addPendingOperation(Map<String, dynamic> operation) async {
    _pendingOperations.add({
      ...operation,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    });
    
    _hasPendingSync = true;
    _syncStatusController.add(SyncStatus(
      isSyncing: false,
      pendingCount: _pendingOperations.length,
      message: 'Operación pendiente de sincronización',
    ));
    
    debugPrint('📝 Operación pendiente agregada: ${operation['type']}');
    
    // Si hay conexión, intentar sincronizar inmediatamente
    if (_connectivityService.isOnline) {
      await _performSync();
    }
  }

  Future<void> _performSync() async {
    if (_isSyncing || _pendingOperations.isEmpty) return;
    
    _isSyncing = true;
    _syncStatusController.add(SyncStatus(
      isSyncing: true,
      pendingCount: _pendingOperations.length,
      message: 'Sincronizando operaciones pendientes...',
    ));
    
    debugPrint('🔄 Iniciando sincronización de ${_pendingOperations.length} operaciones...');
    
    final failedOperations = <Map<String, dynamic>>[];
    
    for (final operation in _pendingOperations) {
      try {
        await _syncOperation(operation);
        debugPrint('✅ Operación sincronizada: ${operation['type']}');
      } catch (e) {
        debugPrint('❌ Error sincronizando operación: ${operation['type']} - $e');
        failedOperations.add(operation);
      }
    }
    
    _pendingOperations.clear();
    _pendingOperations.addAll(failedOperations);
    
    _hasPendingSync = _pendingOperations.isNotEmpty;
    _isSyncing = false;
    
    _syncStatusController.add(SyncStatus(
      isSyncing: false,
      pendingCount: _pendingOperations.length,
      message: failedOperations.isEmpty 
          ? 'Sincronización completada' 
          : 'Sincronización completada con errores',
    ));
    
    debugPrint('📊 Sincronización finalizada. Pendientes: ${_pendingOperations.length}');
  }

  Future<void> _syncOperation(Map<String, dynamic> operation) async {
    final type = operation['type'] as String;
    final endpoint = operation['endpoint'] as String;
    final data = operation['data'] as Map<String, dynamic>?;
    
    switch (type) {
      case 'create':
        await _apiService.post(endpoint, body: data);
        break;
      case 'update':
        await _apiService.put(endpoint, body: data);
        break;
      case 'delete':
        await _apiService.delete(endpoint);
        break;
      default:
        throw Exception('Tipo de operación desconocido: $type');
    }
  }

  Future<void> forceSync() async {
    if (!_connectivityService.isOnline) {
      throw Exception('No hay conexión a internet');
    }
    
    await _performSync();
  }

  Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    _hasPendingSync = false;
    
    _syncStatusController.add(SyncStatus(
      isSyncing: false,
      pendingCount: 0,
      message: 'Operaciones pendientes limpiadas',
    ));
    
    debugPrint('🗑️ Operaciones pendientes limpiadas');
  }

  void dispose() {
    _syncStatusController.close();
  }
}

class SyncStatus {
  final bool isSyncing;
  final int pendingCount;
  final String message;

  SyncStatus({
    required this.isSyncing,
    required this.pendingCount,
    required this.message,
  });
}