import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';

enum SyncOperation { insert, update, delete }

class SyncItem {
  final String id;
  final String tabla;
  final SyncOperation operacion;
  final Map<String, dynamic> datos;
  final String? empresaId;
  final DateTime createdAt;
  int intentos;
  final int maxIntentos;
  String? ultimoError;
  DateTime? proximoIntento;
  bool procesando;

  SyncItem({
    required this.id,
    required this.tabla,
    required this.operacion,
    required this.datos,
    this.empresaId,
    required this.createdAt,
    this.intentos = 0,
    this.maxIntentos = 5,
    this.ultimoError,
    this.proximoIntento,
    this.procesando = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tabla': tabla,
        'operacion': operacion.name,
        'datos': datos,
        'empresaId': empresaId,
        'createdAt': createdAt.toIso8601String(),
        'intentos': intentos,
        'maxIntentos': maxIntentos,
        'ultimoError': ultimoError,
        'proximoIntento': proximoIntento?.toIso8601String(),
        'procesando': procesando,
      };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
        id: json['id'] as String,
        tabla: json['tabla'] as String,
        operacion: SyncOperation.values.firstWhere(
          (e) => e.name == json['operacion'],
          orElse: () => SyncOperation.insert,
        ),
        datos: Map<String, dynamic>.from(json['datos'] as Map),
        empresaId: json['empresaId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        intentos: json['intentos'] as int? ?? 0,
        maxIntentos: json['maxIntentos'] as int? ?? 5,
        ultimoError: json['ultimoError'] as String?,
        proximoIntento: json['proximoIntento'] != null
            ? DateTime.parse(json['proximoIntento'] as String)
            : null,
        procesando: json['procesando'] as bool? ?? false,
      );
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Número máximo de intentos por ítem (también se usa para excluir del
  /// procesamiento los ítems que fallaron definitivamente: la cola los
  /// conserva como auditoría pero no los vuelve a intentar).
  static const int maxIntentos = 5;

  final AppDatabase _db = AppDatabase();
  Timer? _syncTimer;
  Timer? _retryTimer;
  StreamController<SyncStatus>? _statusController;
  bool _isSyncing = false;
  bool _isOnline = true;

  Stream<SyncStatus> get statusStream {
    _statusController ??= StreamController<SyncStatus>.broadcast();
    return _statusController!.stream;
  }

  void _emitStatus(SyncStatus status) {
    _statusController?.add(status);
    debugPrint('🔄 Sync: ${status.message}');
  }

  Future<void> initialize() async {
    await _processPendingSync();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && !_isSyncing) {
        _processPendingSync();
      }
    });

    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _retryFailedItems();
    });
  }

  Future<void> enqueueSync({
    required String tabla,
    required SyncOperation operacion,
    required Map<String, dynamic> datos,
    String? empresaId,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    await _db.into(_db.syncQueue).insert(
      SyncQueueCompanion.insert(
        id: id,
        tabla: tabla,
        operacion: operacion.name,
        datos: Uint8List.fromList(utf8.encode(jsonEncode(datos))),
        empresaId: Value(empresaId),
        intentos: const Value(0),
        maxIntentos: const Value(5),
        createdAt: Value(DateTime.now()),
        proximoIntento: Value(DateTime.now()),
        procesando: const Value(false),
      ),
    );

    _emitStatus(SyncStatus(
      pendingCount: await _getPendingCount(),
      message: 'Encolado: $tabla ${operacion.name}',
    ));

    if (_isOnline) {
      unawaited(_processPendingSync());
    }
  }

  Future<int> _getPendingCount() async {
    // Los ítems que alcanzaron maxIntentos se conservan como auditoría pero
    // ya no cuentan como pendientes (cola que salta fallos).
    return (await _db.select(_db.syncQueue)
          ..where((s) =>
              s.procesando.equals(false) &
              s.intentos.isSmallerThanValue(maxIntentos)))
        .get()
        .then((list) => list.length);
  }

  Future<void> _processPendingSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    _emitStatus(SyncStatus(pendingCount: await _getPendingCount(), message: 'Iniciando sincronización...'));

    try {
      final pendingItems = await (_db.select(_db.syncQueue)
            ..where((s) => s.procesando.equals(false) &
                s.intentos.isSmallerThanValue(maxIntentos) &
                (s.proximoIntento.isNull() | s.proximoIntento.isSmallerOrEqualValue(DateTime.now())))
            ..orderBy([
              (s) => OrderingTerm.asc(s.createdAt),
            ])
            ..limit(50))
          .get();

      for (final row in pendingItems) {
        if (!_isOnline) break;

        await _processSyncItem(row);
      }

      _emitStatus(SyncStatus(
        pendingCount: await _getPendingCount(),
        message: 'Sincronización completada',
      ));
    } catch (e) {
      _emitStatus(SyncStatus(
        pendingCount: await _getPendingCount(),
        message: 'Error en sincronización: $e',
        isError: true,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncItem(SyncQueueData row) async {
    await (_db.update(_db.syncQueue)
          ..where((s) => s.id.equals(row.id)))
        .write(SyncQueueCompanion(procesando: const Value(true)));

    final datos = jsonDecode(utf8.decode(row.datos)) as Map<String, dynamic>;
    final tabla = row.tabla;
    final operacion = SyncOperation.values.firstWhere(
      (e) => e.name == row.operacion,
      orElse: () => SyncOperation.insert,
    );

    try {
      bool success = false;

      switch (tabla) {
        case 'facturas':
          success = await _syncFactura(datos, operacion);
          break;
        case 'clientes':
          success = await _syncCliente(datos, operacion);
          break;
        case 'productos':
          success = await _syncProducto(datos, operacion);
          break;
        case 'pos_ventas':
        case 'posVentas':
          success = await _syncPosVenta(datos, operacion);
          break;
        case 'empresas':
          success = await _syncEmpresa(datos, operacion);
          break;
        default:
          // Cualquier otra tabla (proveedores, cotizaciones, ordenes_compra,
          // compras, transacciones, empleados, nomina, rutas,
          // fiado_abonos, sucursales, transferencias, membresias, socios,
          // sar_correlativo, etc.) se sincroniza por la ruta genérica /api/sync.
          success = await _syncGeneric(datos, tabla, operacion);
      }

      if (success) {
        await (_db.delete(_db.syncQueue)..where((s) => s.id.equals(row.id))).go();
      } else {
        await _handleSyncFailure(row, 'Backend returned false');
      }
    } catch (e) {
      await _handleSyncFailure(row, e.toString());
    }
  }

  Future<bool> _syncPosVenta(Map<String, dynamic> datos, SyncOperation op) async {
    if (op != SyncOperation.insert) return false;

    final empresaCodigo = datos['empresa_codigo'] as String?;
    final venta = datos['venta'] as Map<String, dynamic>?;
    if (empresaCodigo == null || venta == null) return false;

    // Asegura el alias `precio` que espera el backend para los items.
    final items = (venta['items'] as List<dynamic>? ?? []).map((i) {
      final m = Map<String, dynamic>.from(i as Map<String, dynamic>);
      m['precio'] = m['precio'] ?? m['precio_unitario'];
      return m;
    }).toList();
    final payload = Map<String, dynamic>.from(venta)..['items'] = items;

    // Ruta genérica /api/sync con flujo idempotente por correlativo.
    return await PortalPilotDB.syncRows(
      tabla: 'pos_ventas',
      empresaCodigo: empresaCodigo,
      rows: [payload],
      operacion: op.name,
    );
  }

  /// Sincroniza cualquier tabla a través de la ruta genérica `/api/sync`.
  /// Extrae la fila de su clave anidada (proveedor, cotizacion, compra, ...)
  /// o usa los datos completos si vienen planos.
  Future<bool> _syncGeneric(Map<String, dynamic> datos, String tabla, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    if (empresaCodigo == null) return false;

    Map<String, dynamic> row;
    final nested = datos['proveedor'] ??
        datos['cotizacion'] ??
        datos['orden_compra'] ??
        datos['orden'] ??
        datos['compra'] ??
        datos['transaccion'];
    if (nested is Map<String, dynamic>) {
      row = Map<String, dynamic>.from(nested);
    } else {
      row = Map<String, dynamic>.from(datos)..remove('empresa_codigo');
    }

    return await PortalPilotDB.syncRows(
      tabla: tabla,
      empresaCodigo: empresaCodigo,
      rows: [row],
      operacion: op.name,
    );
  }

  Future<bool> _syncFactura(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final factura = datos['factura'] as Map<String, dynamic>?;

    if (empresaCodigo == null || factura == null) return false;

    switch (op) {
      case SyncOperation.insert:
        return await PortalPilotDB.insertFactura(factura: factura, empresaCodigo: empresaCodigo);
      case SyncOperation.update:
        return await PortalPilotDB.anularFactura(
          id: factura['id'] as String,
          empresaCodigo: empresaCodigo,
        );
      case SyncOperation.delete:
        return false;
    }
  }

  Future<bool> _syncCliente(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final cliente = datos['cliente'] as Map<String, dynamic>?;

    if (empresaCodigo == null || cliente == null) return false;

    switch (op) {
      case SyncOperation.insert:
        return await PortalPilotDB.insertCliente(cliente: cliente, empresaCodigo: empresaCodigo);
      case SyncOperation.update:
      case SyncOperation.delete:
        return false;
    }
  }

  Future<bool> _syncProducto(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;

    if (empresaCodigo == null) return false;

    switch (op) {
      case SyncOperation.insert:
      case SyncOperation.update:
        final productos = datos['productos'] as List<dynamic>?;
        if (productos == null) return false;
        return await PortalPilotDB.syncProductos(
          productos: productos.cast<Map<String, dynamic>>(),
          empresaCodigo: empresaCodigo,
        );
      case SyncOperation.delete:
        final codigo = (datos['codigo'] as String?) ?? '';
        if (codigo.isEmpty) return false;
        return await PortalPilotDB.deleteProducto(
          codigo: codigo,
          empresaCodigo: empresaCodigo,
        );
    }
  }

  Future<bool> _syncEmpresa(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    if (empresaCodigo == null) return false;

    // Usa la ruta genérica /api/sync con el codigo de empresa para idempotencia.
    return await PortalPilotDB.syncRows(
      tabla: 'empresas',
      empresaCodigo: empresaCodigo,
      rows: [datos],
      operacion: op.name,
    );
  }

  Future<void> _handleSyncFailure(SyncQueueData row, String error) async {
    final nuevosIntentos = row.intentos + 1;
    final proximoIntento = DateTime.now().add(Duration(minutes: nuevosIntentos * 2));

    if (nuevosIntentos >= row.maxIntentos) {
      await (_db.update(_db.syncQueue)
            ..where((s) => s.id.equals(row.id)))
          .write(SyncQueueCompanion(
        intentos: Value(nuevosIntentos),
        ultimoError: Value(error),
        procesando: const Value(false),
        proximoIntento: Value(proximoIntento),
      ));
      _emitStatus(SyncStatus(
        pendingCount: await _getPendingCount(),
        message: '❌ Sync fallido definitivamente: ${row.tabla} - $error',
        isError: true,
      ));
    } else {
      await (_db.update(_db.syncQueue)
            ..where((s) => s.id.equals(row.id)))
          .write(SyncQueueCompanion(
        intentos: Value(nuevosIntentos),
        ultimoError: Value(error),
        procesando: const Value(false),
        proximoIntento: Value(proximoIntento),
      ));
      _emitStatus(SyncStatus(
        pendingCount: await _getPendingCount(),
        message: '⚠️ Reintento ${nuevosIntentos}/${row.maxIntentos} en 2 min: ${row.tabla}',
      ));
    }
  }

  Future<void> _retryFailedItems() async {
    if (_isSyncing || !_isOnline) return;

    final failedItems = await (_db.select(_db.syncQueue)
          ..where((s) =>
              s.procesando.equals(false) &
              s.intentos.isBiggerOrEqualValue(1) &
              s.intentos.isSmallerThanValue(maxIntentos) &
              (s.proximoIntento.isNull() | s.proximoIntento.isSmallerOrEqualValue(DateTime.now())))
          ..limit(10))
        .get();

    for (final item in failedItems) {
      await _processSyncItem(item);
    }
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    if (online && !_isSyncing) {
      unawaited(_processPendingSync());
    }
    _emitStatus(SyncStatus(
      pendingCount: 0,
      message: online ? '🟢 Online - Sincronizando...' : '🔴 Offline - Cambios en cola local',
    ));
  }

  Future<void> forceSyncNow() async {
    if (!_isOnline) {
      _emitStatus(SyncStatus(
        pendingCount: await _getPendingCount(),
        message: 'Sin conexión - no se puede sincronizar',
        isError: true,
      ));
      return;
    }
    await _processPendingSync();
  }

  Future<List<SyncItem>> getPendingItems() async {
    final rows = await (_db.select(_db.syncQueue)
          ..where((s) => s.procesando.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .get();

    return rows.map((r) => SyncItem(
          id: r.id,
          tabla: r.tabla,
          operacion: SyncOperation.values.firstWhere(
            (e) => e.name == r.operacion,
            orElse: () => SyncOperation.insert,
          ),
          datos: jsonDecode(utf8.decode(r.datos)) as Map<String, dynamic>,
          empresaId: r.empresaId,
          createdAt: r.createdAt,
          intentos: r.intentos,
          maxIntentos: r.maxIntentos,
          ultimoError: r.ultimoError,
          proximoIntento: r.proximoIntento,
          procesando: r.procesando,
        )).toList();
  }

  void dispose() {
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    _statusController?.close();
    _statusController = null;
  }
}

class SyncStatus {
  final int pendingCount;
  final String message;
  final bool isError;

  SyncStatus({
    required this.pendingCount,
    required this.message,
    this.isError = false,
  });
}