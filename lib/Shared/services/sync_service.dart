import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
    final item = SyncItem(
      id: id,
      tabla: tabla,
      operacion: operacion,
      datos: datos,
      empresaId: empresaId,
      createdAt: DateTime.now(),
    );

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
    return (await _db.select(_db.syncQueue)
          ..where((s) => s.procesando.equals(false)))
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
        case 'transacciones':
          success = await _syncTransaccion(datos, operacion);
          break;
        case 'matriculas':
          success = await _syncMatricula(datos, operacion);
          break;
        case 'proveedores':
          success = await _syncProveedor(datos, operacion);
          break;
        case 'cotizaciones':
          success = await _syncCotizacion(datos, operacion);
          break;
        case 'ordenes_compra':
        case 'ordenesCompra':
          success = await _syncOrdenCompra(datos, operacion);
          break;
        case 'compras':
          success = await _syncCompra(datos, operacion);
          break;
        case 'notas':
          success = await _syncNotas(datos, operacion);
          break;
        case 'empleados':
          success = await _syncEmpleado(datos, operacion);
          break;
        case 'nomina':
          success = await _syncNomina(datos, operacion);
          break;
        default:
          debugPrint('⚠️ Tabla no soportada para sync: $tabla');
          success = false;
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

  Future<bool> _syncProveedor(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final proveedor = datos['proveedor'] as Map<String, dynamic>?;
    if (empresaCodigo == null || proveedor == null) return false;

    if (op == SyncOperation.insert) {
      return await PortalPilotDB.insertProveedor(proveedor: proveedor, empresaCodigo: empresaCodigo);
    }
    return false;
  }

  Future<bool> _syncCotizacion(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final cotizacion = datos['cotizacion'] as Map<String, dynamic>?;
    if (empresaCodigo == null || cotizacion == null) return false;

    if (op == SyncOperation.insert) {
      return await PortalPilotDB.insertCotizacion(cotizacion: cotizacion, empresaCodigo: empresaCodigo);
    }
    return false;
  }

  Future<bool> _syncOrdenCompra(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final orden = datos['orden_compra'] as Map<String, dynamic>? ?? datos['orden'] as Map<String, dynamic>?;
    if (empresaCodigo == null || orden == null) return false;

    if (op == SyncOperation.insert) {
      return await PortalPilotDB.insertOrdenCompra(orden: orden, empresaCodigo: empresaCodigo);
    }
    return false;
  }

  Future<bool> _syncCompra(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final compra = datos['compra'] as Map<String, dynamic>?;
    if (empresaCodigo == null || compra == null) return false;

    if (op == SyncOperation.insert) {
      return await PortalPilotDB.insertCompra(compra: compra, empresaCodigo: empresaCodigo);
    }
    return false;
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
    final productos = datos['productos'] as List<dynamic>?;

    if (empresaCodigo == null || productos == null) return false;

    switch (op) {
      case SyncOperation.insert:
      case SyncOperation.update:
        return await PortalPilotDB.syncProductos(
          productos: productos.cast<Map<String, dynamic>>(),
          empresaCodigo: empresaCodigo,
        );
      case SyncOperation.delete:
        return false;
    }
  }

  Future<bool> _syncTransaccion(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final transaccion = datos['transaccion'] as Map<String, dynamic>?;

    if (empresaCodigo == null || transaccion == null) return false;

    switch (op) {
      case SyncOperation.insert:
        return await PortalPilotDB.insertTransaccion(
          transaccion: transaccion,
          empresaCodigo: empresaCodigo,
        );
      case SyncOperation.update:
      case SyncOperation.delete:
        return false;
    }
  }

  Future<bool> _syncMatricula(Map<String, dynamic> datos, SyncOperation op) async {
    if (op != SyncOperation.insert) return false;

    try {
      await PortalPilotDB.insertMatriculaCompleta(
        folioMatricula: datos['folio_matricula'] as String,
        empresaCodigo: datos['empresa_codigo'] as String,
        cicloEscolar: datos['ciclo_escolar'] as String,
        nivelEducativo: datos['nivel_educativo'] as String,
        grado: datos['grado'] as String,
        seccion: datos['seccion'] as String,
        turno: datos['turno'] as String,
        tipoIngreso: datos['tipo_ingreso'] as String,
        alumnoNombre: datos['alumno_nombre'] as String,
        alumnoApellido: datos['alumno_apellido'] as String,
        alumnoDni: datos['alumno_dni'] as String,
        alumnoFechaNacimiento: datos['alumno_fecha_nacimiento'] as String,
        alumnoLugarNacimiento: datos['alumno_lugar_nacimiento'] as String,
        alumnoNacionalidad: datos['alumno_nacionalidad'] as String,
        observacionesSalud: datos['observaciones_salud'] as String,
        tutorParentesco: datos['tutor_parentesco'] as String,
        tutorNombre: datos['tutor_nombre'] as String,
        tutorTelefono: datos['tutor_telefono'] as String,
        tutorEmail: datos['tutor_email'] as String,
        direccionCalle: datos['direccion_calle'] as String,
        direccionMunicipio: datos['direccion_municipio'] as String,
        direccionDepartamento: datos['direccion_departamento'] as String,
        direccionReferencia: datos['direccion_referencia'] as String,
        direccionCP: datos['direccion_cp'] as String,
        pagoInscripcionRealizado: datos['pago_inscripcion_realizado'] as bool,
        metodoPago: datos['metodo_pago'] as String,
        planPagos: datos['plan_pagos'] as String,
        estado: datos['estado'] as String? ?? 'pendiente',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Sync matricula error: $e');
      return false;
    }
  }

  Future<bool> _syncNotas(Map<String, dynamic> datos, SyncOperation op) async {
    final empresaCodigo = datos['empresa_codigo'] as String?;
    final clave = datos['clave'] as String?;
    final datosNotas = datos['datos'] as Map<String, dynamic>?;

    if (empresaCodigo == null || clave == null || datosNotas == null) return false;

    return await PortalPilotDB.saveNotas(
      empresaCodigo: empresaCodigo,
      clave: clave,
      datos: datosNotas,
    );
  }

  Future<bool> _syncEmpleado(Map<String, dynamic> datos, SyncOperation op) async {
    return false;
  }

  Future<bool> _syncNomina(Map<String, dynamic> datos, SyncOperation op) async {
    return false;
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
              s.intentos.isSmallerThanValue(5) &
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
    _db.close();
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