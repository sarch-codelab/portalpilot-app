import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/services/connectivity_service.dart';
import 'package:uuid/uuid.dart';

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

  // Helper to create EmpresasCompanion from onboarding selections
  EmpresasCompanion empresaFromOnboarding(String areaNegocio, String empresaCodigo) {
    return EmpresasCompanion(
      id: const Value.absent(), // Let DB generate UUID
      codigo: Value(empresaCodigo),
      nombre: Value('Portal Pilot Empresa'),
      rtn: Value(''),
      direccion: Value(''),
      telefono: Value(''),
      email: Value(''),
      logoUrl: const Value.absent(),
      bannerUrl: const Value.absent(),
      plan: Value('Starter'), // Plan por defecto para Honduras
      areaNegocio: Value(areaNegocio), // **This is the key field**
      config: const Value.absent(),
      activa: Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );
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

  Future<Factura?> getFacturaByCorrelativo(String empresaId, String correlativo) async {
    final rows = await (_db.select(_db.facturas)
          ..where((f) => f.empresaId.equals(empresaId) & f.correlativo.equals(correlativo))
          ..orderBy([(f) => OrderingTerm.desc(f.updatedAt)]))
        .get();
    return rows.firstOrNull;
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
    SyncOperation operacion = SyncOperation.insert,
    bool triggerSync = true,
    double tasaIsvEstandar = 0.15,
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
      operacion: operacion,
      datos: {
        'empresa_codigo': empresaId,
        'factura': {
          'id': id,
          'usuario_id': usuarioId,
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
          'items': items['items'] ?? items,
          'subtotal': subtotal,
          'isv_15': isv15,
          'isv_18': isv18,
          'descuento': descuento,
          'total': total,
          'tasa_isv_estandar': tasaIsvEstandar.clamp(0.0, 0.50),
          'estado': estado,
          'notas': notas,
        },
      },
      empresaId: empresaId,
      triggerSync: triggerSync,
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
            'correlativo': existing.correlativo,
            'estado': factura.estado.value,
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
            'correlativo': existing.correlativo,
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
    bool enqueueSync = true,
  }) async {
    for (final p in productos) {
      final codigo = (p['codigo'] as String?)?.trim();
      final barcode = (p['barcode'] as String?)?.trim();
      String id;

      // Dedupe por (empresa) usando codigo y luego barcode: si ya existe,
      // reutiliza su id para no crear filas duplicadas en la BD local.
      Producto? existing;
      if (codigo != null && codigo.isNotEmpty) {
        existing = await (_db.select(_db.productos)
              ..where((x) => x.empresaId.equals(empresaId) & x.codigo.equals(codigo)))
            .getSingleOrNull();
      }
      if (existing == null && barcode != null && barcode.isNotEmpty) {
        existing = await (_db.select(_db.productos)
              ..where((x) => x.empresaId.equals(empresaId) & x.barcode.equals(barcode)))
            .getSingleOrNull();
      }

      if (existing != null) {
        id = existing.id;
      } else {
        id = (p['id'] as String?)?.isNotEmpty == true
            ? p['id'] as String
            : DateTime.now().microsecondsSinceEpoch.toString();
      }

      final companion = ProductosCompanion.insert(
        id: id,
        empresaId: empresaId,
        codigo: Value(codigo),
        barcode: Value(barcode),
        marca: Value(p['marca'] as String?),
        presentacion: Value(p['presentacion'] as String?),
        nombre: (p['nombre'] as String?) ?? '',
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
        isPerishable: Value(p['is_perishable'] as bool? ?? false),
        imagenUrl: Value(p['imagen_url'] as String?),
        activo: const Value(true),
        synced: Value(!enqueueSync),
        updatedAt: Value(DateTime.now()),
      );

      await _db.into(_db.productos).insertOnConflictUpdate(companion);
    }

    if (enqueueSync) {
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
  }

  /// Registra SOLO el movimiento de kardex (sin tocar stock). Para ventas,
  /// compras y anulaciones que ya ajustaron existencias por su cuenta.
  /// Best-effort: nunca rompe la operación que lo llama.
  Future<void> registrarMovimientoKardexSolo({
    required String empresaCodigo,
    required String productoId,
    required String productoCodigo,
    required String nombreProducto,
    required String tipo, // 'entrada' | 'salida'
    required int cantidad,
    int? stockDespues,
    String? referencia,
    String? notas,
  }) async {
    try {
      // La operación padre (venta/compra/anulación) aplica stock y Kardex
      // remotamente en una transacción; encolar también este movimiento
      // descontaría o sumaría existencias por segunda vez.
      final movimientoId = const Uuid().v4();
      final prefs = await SharedPreferences.getInstance();
      final kardex = JsonGuard.safeListOfMaps(prefs.getString('kardex'), source: 'Inventario/kardex/auto');
      kardex.insert(0, {
        'id': movimientoId,
        'empresa_codigo': empresaCodigo,
        'producto_id': productoId,
        'producto_codigo': productoCodigo.trim(),
        'producto_nombre': nombreProducto,
        'tipo_movimiento': tipo,
        'cantidad': cantidad,
        'stock_despues': stockDespues,
        'referencia': referencia,
        'notas': notas,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (kardex.length > 500) kardex.removeRange(500, kardex.length);
      await prefs.setString('kardex', jsonEncode(kardex));
    } catch (e) {
      debugPrint('[Kardex] No se pudo registrar movimiento automático: $e');
    }
  }

  /// Cambia existencias y registra el movimiento en la misma transacción local.
  /// La fila de la cola queda confirmada junto al cambio de stock antes de
  /// intentar cualquier envío de red.
  Future<void> registrarMovimientoInventario({
    required String empresaCodigo,
    required String productoId,
    required String productoCodigo,
    required String tipo,
    required int cantidad,
    String? referencia,
    String? notas,
  }) async {
    if (!['entrada', 'salida'].contains(tipo)) {
      throw ArgumentError('El tipo de movimiento no es válido.');
    }
    if (cantidad <= 0 || productoCodigo.trim().isEmpty) {
      throw ArgumentError('Selecciona un producto y una cantidad válida.');
    }

    final movimientoId = const Uuid().v4();
    late int stockResultante;
    late String nombreProducto;
    await _db.transaction(() async {
      final producto = await (_db.select(_db.productos)
            ..where((p) => p.empresaId.equals(empresaCodigo) & p.id.equals(productoId)))
          .getSingleOrNull();
      if (producto == null) throw StateError('El producto ya no existe en este negocio.');
      final nuevoStock = tipo == 'entrada'
          ? producto.stockActual + cantidad
          : producto.stockActual - cantidad;
      stockResultante = nuevoStock;
      nombreProducto = producto.nombre;
      if (nuevoStock < 0) {
        throw StateError('No hay existencias suficientes de ${producto.nombre}.');
      }
      await (_db.update(_db.productos)
            ..where((p) => p.empresaId.equals(empresaCodigo) & p.id.equals(productoId)))
      .write(ProductosCompanion(
        stockActual: Value(nuevoStock),
        synced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));

      await _syncService.enqueueSync(
        tabla: 'kardex',
        operacion: SyncOperation.insert,
        datos: {
          'id': movimientoId,
          'empresa_codigo': empresaCodigo,
          'producto_id': productoId,
          'producto_codigo': productoCodigo.trim(),
          'producto_nombre': producto.nombre,
          'tipo_movimiento': tipo,
          'cantidad': cantidad,
          'referencia': referencia,
          'notas': notas,
          'fecha': DateTime.now().toIso8601String(),
          'stock_despues': nuevoStock,
          'created_at': DateTime.now().toIso8601String(),
        },
        empresaId: empresaCodigo,
        triggerSync: false,
      );
    });

    final prefs = await SharedPreferences.getInstance();
    for (final key in ['productos', 'productos_pos']) {
      final cached = JsonGuard.safeListOfMaps(prefs.getString(key), source: 'Inventario/kardex/$key');
      for (final row in cached) {
        if (row['id']?.toString() == productoId ||
            row['codigo']?.toString() == productoCodigo.trim()) {
          row['stock_actual'] = stockResultante;
        }
      }
      await prefs.setString(key, jsonEncode(cached));
    }
    final kardex = JsonGuard.safeListOfMaps(prefs.getString('kardex'), source: 'Inventario/kardex/local');
    kardex.insert(0, {
      'id': movimientoId,
      'producto_id': productoId,
      'producto_codigo': productoCodigo.trim(),
      'producto_nombre': nombreProducto,
      'tipo_movimiento': tipo,
      'cantidad': cantidad,
      'referencia': referencia,
      'notas': notas,
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('kardex', jsonEncode(kardex));
    _syncService.syncNowIfOnline();
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

  Future<void> deleteProductoLocal({
    required String empresaId,
    required String codigo,
    String? id,
  }) async {
    if (codigo.isEmpty && (id == null || id.isEmpty)) return;

    final exp = _db.productos;
    if (id != null && id.isNotEmpty) {
      await (_db.delete(exp)..where((p) => p.empresaId.equals(empresaId) & p.id.equals(id))).go();
      return;
    }
    await (_db.delete(exp)
          ..where((p) => p.empresaId.equals(empresaId) & p.codigo.equals(codigo)))
        .go();
  }

  /// Elimina un producto de todos los almacenes locales (Drift + SharedPreferences
  /// 'productos' y 'productos_pos') y encola su borrado en el backend. Es la ruta
  /// única que usan Inventario y Catálogo para que el producto no reaparezca.
  Future<void> eliminarProductoGlobal({
    required String empresaId,
    required Map<String, dynamic> producto,
  }) async {
    final id = (producto['id'] as String?)?.isNotEmpty == true ? producto['id'] as String : '';
    final codigo = (producto['codigo'] ?? '').toString();

    await deleteProductoLocal(empresaId: empresaId, codigo: codigo, id: id);

    final prefs = await SharedPreferences.getInstance();

    final json = prefs.getString('productos') ?? '[]';
    final List<dynamic> productos = JsonGuard.safeListOfMaps(json, source: 'Inventario/eliminar');
    productos.removeWhere((p) => (p['codigo'] ?? '') == codigo || (id.isNotEmpty && p['id'] == id));
    await prefs.setString('productos', jsonEncode(productos));

    final productosPosJson = prefs.getString('productos_pos') ?? '[]';
    final List<dynamic> productosPos = JsonGuard.safeListOfMaps(productosPosJson, source: 'Inventario/eliminar_pos');
    productosPos.removeWhere((p) => (p['codigo'] ?? '') == codigo || (id.isNotEmpty && p['id'] == id));
    await prefs.setString('productos_pos', jsonEncode(productosPos));

    if (id.isNotEmpty || codigo.isNotEmpty) {
      await _syncService.enqueueSync(
        tabla: 'productos',
        operacion: SyncOperation.delete,
        datos: {
          'empresa_codigo': empresaId,
          'id': id,
          'codigo': codigo,
        },
        empresaId: empresaId,
      );
    }
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
    bool triggerSync = true,
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

    await _db.transaction(() async {
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
        triggerSync: false,
      );
    });
    if (triggerSync) _syncService.syncNowIfOnline();
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
      final decoded = JsonGuard.tryDecode(utf8.decode(draft.datos));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
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

  Future<bool> hasPendingSyncFor(String tabla, String empresaId) async {
    final rows = await (_db.select(_db.syncQueue)
          ..where((s) => s.tabla.equals(tabla) & s.empresaId.equals(empresaId)))
        .get();
    return rows.isNotEmpty;
  }

  bool get isOnline => _connectivityService.isOnline;
}
