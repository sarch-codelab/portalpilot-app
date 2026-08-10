import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/services/connectivity_service.dart';

class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  final AppDatabase _db = AppDatabase();
  final SyncService _syncService = SyncService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _connectivityService.initialize();
    await _syncService.initialize();

    _connectivityService.connectivityStream.listen((online) {
      _syncService.setOnlineStatus(online);
    });

    _initialized = true;
    debugPrint('✅ LocalDatabaseService initialized');
  }

  AppDatabase get database => _db;

  Future<void> close() async {
    await _db.close();
    _syncService.dispose();
    _connectivityService.dispose();
    _initialized = false;
  }

  // ════════════════════════════════════════════════════════════════
  // EMPRESAS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Empresa>> getEmpresas() async {
    return await _db.select(_db.empresas).get();
  }

  Future<Empresa?> getEmpresaByCodigo(String codigo) async {
    return await (_db.select(_db.empresas)
          ..where((e) => e.codigo.equals(codigo)))
        .getSingleOrNull();
  }

  Future<void> upsertEmpresa(EmpresasCompanion empresa) async {
    await _db.into(_db.empresas).insertOnConflictUpdate(empresa);
  }

  // ═══════════════════════════════════════════════════════════════
  // USUARIOS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Usuario>> getUsuarios(String empresaId) async {
    return await (_db.select(_db.usuarios)
          ..where((u) => u.empresaId.equals(empresaId)))
        .get();
  }

  Future<void> upsertUsuario(UsuariosCompanion usuario) async {
    await _db.into(_db.usuarios).insertOnConflictUpdate(usuario);
  }

  // ═══════════════════════════════════════════════════════════════
  // FACTURAS (offline-first con sync queue)
  // ═══════════════════════════════════════════════════════════════

  Future<List<Factura>> getFacturas(String empresaId) async {
    return await (_db.select(_db.facturas)
          ..where((f) => f.empresaId.equals(empresaId))
          ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
        .get();
  }

  Future<Factura?> getFacturaById(String id) async {
    return await (_db.select(_db.facturas)
          ..where((f) => f.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertFacturaLocal({
    required String id,
    required String empresaId,
    required String usuarioId,
    required String correlativo,
    required String tipoDocumento,
    required String cai,
    String? rangoInicio,
    String? rangoFin,
    DateTime? fechaLimiteEmision,
    String? clienteNombre,
    String? clienteRtn,
    String? clienteDireccion,
    required String condicionPago,
    required String tipoVenta,
    required Map<String, dynamic> items,
    required double subtotal,
    required double isv15,
    required double isv18,
    required double descuento,
    required double total,
    required String estado,
    String? notas,
  }) async {
    final factura = FacturasCompanion.insert(
      id: id,
      empresaId: empresaId,
      correlativo: correlativo,
      cai: cai,
      items: Uint8List.fromList(utf8.encode(jsonEncode(items))),
      usuarioId: Value(usuarioId),
      tipoDocumento: Value(tipoDocumento),
      rangoInicio: Value(rangoInicio),
      rangoFin: Value(rangoFin),
      fechaLimiteEmision: Value(fechaLimiteEmision),
      clienteNombre: Value(clienteNombre),
      clienteRtn: Value(clienteRtn),
      clienteDireccion: Value(clienteDireccion),
      condicionPago: Value(condicionPago),
      tipoVenta: Value(tipoVenta),
      subtotal: Value(subtotal),
      isv15: Value(isv15),
      isv18: Value(isv18),
      descuento: Value(descuento),
      total: Value(total),
      estado: Value(estado),
      notas: Value(notas),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.facturas).insertOnConflictUpdate(factura);

    await _syncService.enqueueSync(
      tabla: 'facturas',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'factura': {
          'id': id,
          'correlativo': correlativo,
          'tipo_documento': tipoDocumento,
          'cai': cai,
          'rango_inicio': rangoInicio,
          'rango_fin': rangoFin,
          'fecha_limite_emision': fechaLimiteEmision?.toIso8601String(),
          'cliente_nombre': clienteNombre,
          'cliente_rtn': clienteRtn,
          'cliente_direccion': clienteDireccion,
          'condicion_pago': condicionPago,
          'tipo_venta': tipoVenta,
          'items': items,
          'subtotal': subtotal,
          'isv_15': isv15,
          'isv_18': isv18,
          'descuento': descuento,
          'total': total,
          'estado': estado,
          'notas': notas,
        },
      },
      empresaId: empresaId,
    );
  }

  Future<void> updateFacturaLocal(String id, FacturasCompanion factura) async {
    await (_db.update(_db.facturas)..where((f) => f.id.equals(id))).write(factura);

    final existing = await getFacturaById(id);
    if (existing != null) {
      await _syncService.enqueueSync(
        tabla: 'facturas',
        operacion: SyncOperation.update,
        datos: {
          'empresa_codigo': existing.empresaId,
          'factura': {
            'id': id,
            'estado': factura.estado.value ?? existing.estado,
            'fecha_anulacion': factura.fechaAnulacion.value?.toIso8601String(),
            'motivo_anulacion': factura.motivoAnulacion.value,
          },
        },
        empresaId: existing.empresaId,
      );
    }
  }

  Future<void> anularFacturaLocal(String id, String motivo) async {
    await (_db.update(_db.facturas)..where((f) => f.id.equals(id))).write(
      FacturasCompanion(
        estado: const Value('anulada'),
        fechaAnulacion: Value(DateTime.now()),
        motivoAnulacion: Value(motivo),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );

    final existing = await getFacturaById(id);
    if (existing != null) {
      await _syncService.enqueueSync(
        tabla: 'facturas',
        operacion: SyncOperation.update,
        datos: {
          'empresa_codigo': existing.empresaId,
          'factura': {
            'id': id,
            'estado': 'anulada',
            'fecha_anulacion': DateTime.now().toIso8601String(),
            'motivo_anulacion': motivo,
          },
        },
        empresaId: existing.empresaId,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CLIENTES
  // ═══════════════════════════════════════════════════════════════

  Future<List<Cliente>> getClientes(String empresaId) async {
    return await (_db.select(_db.clientes)
          ..where((c) => c.empresaId.equals(empresaId))
          ..orderBy([(c) => OrderingTerm.asc(c.nombre)]))
        .get();
  }

  Future<void> insertClienteLocal({
    required String id,
    required String empresaId,
    required String nombre,
    String? rtn,
    String? direccion,
    String? telefono,
    String? email,
    String? notas,
  }) async {
    final cliente = ClientesCompanion.insert(
      id: id,
      empresaId: empresaId,
      nombre: nombre,
      rtn: Value(rtn),
      direccion: Value(direccion),
      telefono: Value(telefono),
      email: Value(email),
      notas: Value(notas),
      activo: const Value(true),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.clientes).insertOnConflictUpdate(cliente);

    await _syncService.enqueueSync(
      tabla: 'clientes',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'cliente': {
          'id': id,
          'nombre': nombre,
          'rtn': rtn,
          'direccion': direccion,
          'telefono': telefono,
          'email': email,
          'notas': notas,
        },
      },
      empresaId: empresaId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PRODUCTOS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Producto>> getProductos(String empresaId) async {
    return await (_db.select(_db.productos)
          ..where((p) => p.empresaId.equals(empresaId) & p.activo.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
        .get();
  }

  Future<void> upsertProductosLocal({
    required String empresaId,
    required List<Map<String, dynamic>> productos,
  }) async {
    for (final p in productos) {
      final id = p['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
      final companion = ProductosCompanion.insert(
        id: id,
        empresaId: empresaId,
        codigo: Value(p['codigo'] as String?),
        nombre: p['nombre'] as String,
        descripcion: Value(p['descripcion'] as String?),
        categoria: Value(p['categoria'] as String?),
        unidadMedida: Value(p['unidad_medida'] as String? ?? 'Unidad'),
        precioCompra: Value((p['precio_compra'] as num?)?.toDouble() ?? 0.0),
        precioVenta: Value((p['precio_venta'] as num?)?.toDouble() ?? 0.0),
        stockMinimo: Value(p['stock_minimo'] as int? ?? 0),
        stockActual: Value(p['stock_actual'] as int? ?? 0),
        bodega: Value(p['bodega'] as String? ?? 'General'),
        isvRate: Value((p['isv_rate'] as num?)?.toDouble() ?? 15.0),
        exento: Value(p['exento'] as bool? ?? false),
        imagenUrl: Value(p['imagen_url'] as String?),
        activo: const Value(true),
        synced: const Value(false),
        updatedAt: Value(DateTime.now()),
      );

      await _db.into(_db.productos).insertOnConflictUpdate(companion);
    }

    await _syncService.enqueueSync(
      tabla: 'productos',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'productos': productos,
      },
      empresaId: empresaId,
    );
  }

  Future<void> updateProductoStock(String id, int nuevoStock) async {
    await (_db.update(_db.productos)..where((p) => p.id.equals(id))).write(
      ProductosCompanion(
        stockActual: Value(nuevoStock),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TRANSACCIONES
  // ═══════════════════════════════════════════════════════════════

  Future<List<Transaccione>> getTransacciones(String empresaId) async {
    return await (_db.select(_db.transacciones)
          ..where((t) => t.empresaId.equals(empresaId))
          ..orderBy([(t) => OrderingTerm.desc(t.fecha)]))
        .get();
  }

  Future<void> insertTransaccionLocal({
    required String id,
    required String empresaId,
    String? usuarioId,
    required String tipo,
    String? categoria,
    String? descripcion,
    required double monto,
    String? metodoPago,
    String? referencia,
    required DateTime fecha,
  }) async {
    final transaccion = TransaccionesCompanion.insert(
      id: id,
      empresaId: empresaId,
      tipo: tipo,
      monto: monto,
      usuarioId: Value(usuarioId),
      categoria: Value(categoria),
      descripcion: Value(descripcion),
      metodoPago: Value(metodoPago),
      referencia: Value(referencia),
      fecha: Value(fecha),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.transacciones).insertOnConflictUpdate(transaccion);

    await _syncService.enqueueSync(
      tabla: 'transacciones',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'transaccion': {
          'id': id,
          'tipo': tipo,
          'categoria': categoria,
          'descripcion': descripcion,
          'monto': monto,
          'metodo_pago': metodoPago,
          'referencia': referencia,
          'fecha': fecha.toIso8601String(),
        },
      },
      empresaId: empresaId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MATRICULAS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Matricula>> getMatriculas(String empresaId) async {
    return await (_db.select(_db.matriculas)
          ..where((m) => m.empresaId.equals(empresaId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<void> insertMatriculaLocal({
    required String id,
    required String empresaId,
    required String estudianteNombre,
    String? estudianteId,
    String? grado,
    String? seccion,
    String? turno,
    String? estado,
    DateTime? fechaMatricula,
    String? observaciones,
  }) async {
    final matricula = MatriculasCompanion.insert(
      id: id,
      empresaId: empresaId,
      estudianteNombre: estudianteNombre,
      estudianteId: Value(estudianteId),
      grado: Value(grado),
      seccion: Value(seccion),
      turno: Value(turno),
      estado: Value(estado ?? 'activa'),
      fechaMatricula: Value(fechaMatricula ?? DateTime.now()),
      observaciones: Value(observaciones),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.matriculas).insertOnConflictUpdate(matricula);

    await _syncService.enqueueSync(
      tabla: 'matriculas',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'folio_matricula': id,
        'ciclo_escolar': '2024-2025',
        'nivel_educativo': grado ?? '',
        'grado': grado ?? '',
        'seccion': seccion ?? '',
        'turno': turno ?? '',
        'tipo_ingreso': 'nuevo',
        'alumno_nombre': estudianteNombre,
        'alumno_apellido': '',
        'alumno_dni': estudianteId ?? '',
        'alumno_fecha_nacimiento': '',
        'alumno_lugar_nacimiento': '',
        'alumno_nacionalidad': '',
        'observaciones_salud': observaciones ?? '',
        'tutor_parentesco': '',
        'tutor_nombre': '',
        'tutor_telefono': '',
        'tutor_email': '',
        'direccion_calle': '',
        'direccion_municipio': '',
        'direccion_departamento': '',
        'direccion_referencia': '',
        'direccion_cp': '',
        'pago_inscripcion_realizado': false,
        'metodo_pago': '',
        'plan_pagos': '',
        'estado': estado ?? 'pendiente',
      },
      empresaId: empresaId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NOTAS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Nota>> getNotas(String empresaId, String matriculaId) async {
    return await (_db.select(_db.notas)
          ..where((n) => n.empresaId.equals(empresaId) & n.matriculaId.equals(matriculaId)))
        .get();
  }

  Future<void> upsertNotaLocal({
    required String id,
    required String empresaId,
    required String matriculaId,
    required String materia,
    required int trimestre,
    double? nota,
    String? observaciones,
  }) async {
    final notaCompanion = NotasCompanion.insert(
      id: id,
      empresaId: empresaId,
      materia: materia,
      trimestre: trimestre,
      matriculaId: Value(matriculaId),
      nota: Value(nota),
      observaciones: Value(observaciones),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.notas).insertOnConflictUpdate(notaCompanion);

    await _syncService.enqueueSync(
      tabla: 'notas',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'clave': '$matriculaId|$materia|$trimestre',
        'datos': {
          'materia': materia,
          'trimestre': trimestre,
          'nota': nota,
          'observaciones': observaciones,
        },
      },
      empresaId: empresaId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPLEADOS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Empleado>> getEmpleados(String empresaId) async {
    return await (_db.select(_db.empleados)
          ..where((e) => e.empresaId.equals(empresaId)))
        .get();
  }

  Future<void> upsertEmpleadoLocal({
    required String id,
    required String empresaId,
    required String nombre,
    String? identidad,
    String? rtn,
    String? puesto,
    String? departamento,
    double? salarioBase,
    DateTime? fechaIngreso,
    String? estado,
  }) async {
    final empleado = EmpleadosCompanion.insert(
      id: id,
      empresaId: empresaId,
      nombre: nombre,
      identidad: Value(identidad),
      rtn: Value(rtn),
      puesto: Value(puesto),
      departamento: Value(departamento),
      salarioBase: Value(salarioBase ?? 0.0),
      fechaIngreso: Value(fechaIngreso),
      estado: Value(estado ?? 'activo'),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.empleados).insertOnConflictUpdate(empleado);
  }

  // ═══════════════════════════════════════════════════════════════
  // NOMINA
  // ═══════════════════════════════════════════════════════════════

  Future<List<NominaData>> getNomina(String empresaId, int mes, int anio) async {
    return await (_db.select(_db.nomina)
          ..where((n) => n.empresaId.equals(empresaId) & n.mes.equals(mes) & n.anio.equals(anio)))
        .get();
  }

  Future<void> upsertNominaLocal({
    required String id,
    required String empresaId,
    required String empleadoId,
    required int mes,
    required int anio,
    required double salarioBase,
    double bonificaciones = 0,
    double deducciones = 0,
    double isss = 0,
    double rtn = 0,
    double ihss = 0,
    double neta = 0,
    bool pagado = false,
    DateTime? fechaPago,
  }) async {
    final nomina = NominaCompanion.insert(
      id: id,
      empresaId: empresaId,
      mes: mes,
      anio: anio,
      empleadoId: Value(empleadoId),
      salarioBase: Value(salarioBase),
      bonificaciones: Value(bonificaciones),
      deducciones: Value(deducciones),
      isss: Value(isss),
      rtn: Value(rtn),
      ihss: Value(ihss),
      neta: Value(neta),
      pagado: Value(pagado),
      fechaPago: Value(fechaPago),
      synced: const Value(false),
      createdAt: Value(DateTime.now()),
    );

    await _db.into(_db.nomina).insertOnConflictUpdate(nomina);
  }

  // ═══════════════════════════════════════════════════════════════
  // DRAFTS (borradores de formularios)
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveDraft(String pantalla, String clave, Map<String, dynamic> datos) async {
    await _db.into(_db.drafts).insertOnConflictUpdate(
      DraftsCompanion.insert(
        id: '$pantalla|$clave',
        pantalla: pantalla,
        clave: clave,
        datos: Uint8List.fromList(utf8.encode(jsonEncode(datos))),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Map<String, dynamic>?> getDraft(String pantalla, String clave) async {
    final draft = await (_db.select(_db.drafts)
          ..where((d) => d.pantalla.equals(pantalla) & d.clave.equals(clave)))
        .getSingleOrNull();

    if (draft != null) {
      return jsonDecode(utf8.decode(draft.datos)) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearDraft(String pantalla, String clave) async {
    await (_db.delete(_db.drafts)
          ..where((d) => d.pantalla.equals(pantalla) & d.clave.equals(clave)))
        .go();
  }

  // ═══════════════════════════════════════════════════════════════
  // SYNC STATUS
  // ═══════════════════════════════════════════════════════════════

  Stream<SyncStatus> get syncStatusStream => _syncService.statusStream;

  Future<void> forceSyncNow() async {
    await _syncService.forceSyncNow();
  }

  Future<List<SyncItem>> getPendingSyncItems() async {
    return await _syncService.getPendingItems();
  }

  bool get isOnline => _connectivityService.isOnline;
}