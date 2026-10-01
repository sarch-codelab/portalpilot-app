// lib/Shared/services/comercial_service.dart
// Motor Comercial Genérico (Paso 8):
//  - Proveedores: CRUD, condiciones de pago.
//  - Cotizaciones: borrador -> enviada -> aceptada | rechazada | vencida.
//  - Órdenes de Compra: borrador -> enviada -> recibida | parcial | cancelada.
//  - Compras (recepción): pendiente -> pagada | parcial | anulada; al recibir, incrementa stock.

import 'package:drift/drift.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Estados para cotizaciones.
class EstadoCotizacion {
  static const String borrador = 'borrador';
  static const String enviada = 'enviada';
  static const String aceptada = 'aceptada';
  static const String rechazada = 'rechazada';
  static const String vencida = 'vencida';

  static String etiqueta(String estado) {
    switch (estado) {
      case enviada:
        return 'Enviada';
      case aceptada:
        return 'Aceptada';
      case rechazada:
        return 'Rechazada';
      case vencida:
        return 'Vencida';
      default:
        return 'Borrador';
    }
  }
}

/// Estados para órdenes de compra.
class EstadoOrdenCompra {
  static const String borrador = 'borrador';
  static const String enviada = 'enviada';
  static const String recibida = 'recibida';
  static const String parcial = 'parcial';
  static const String cancelada = 'cancelada';

  static String etiqueta(String estado) {
    switch (estado) {
      case enviada:
        return 'Enviada';
      case recibida:
        return 'Recibida';
      case parcial:
        return 'Parcial';
      case cancelada:
        return 'Cancelada';
      default:
        return 'Borrador';
    }
  }
}

/// Estados para compras (recepción/factura proveedor).
class EstadoCompra {
  static const String pendiente = 'pendiente';
  static const String pagada = 'pagada';
  static const String parcial = 'parcial';
  static const String anulada = 'anulada';

  static String etiqueta(String estado) {
    switch (estado) {
      case pagada:
        return 'Pagada';
      case parcial:
        return 'Parcial';
      case anulada:
        return 'Anulada';
      default:
        return 'Pendiente';
    }
  }
}

/// Detalle de cotización con items.
class CotizacionDetalle {
  final Cotizacione cotizacion;
  final List<CotizacionItem> items;

  const CotizacionDetalle({required this.cotizacion, required this.items});

  int get totalItems => items.fold<int>(0, (s, i) => s + i.cantidad);
}

/// Detalle de orden de compra con items.
class OrdenCompraDetalle {
  final OrdenesCompraData orden;
  final List<OrdenCompraItem> items;

  const OrdenCompraDetalle({required this.orden, required this.items});

  int get totalItems => items.fold<int>(0, (s, i) => s + i.cantidad);
}

/// Detalle de compra con items.
class CompraDetalle {
  final Compra compra;
  final List<CompraItem> items;

  const CompraDetalle({required this.compra, required this.items});

  int get totalItems => items.fold<int>(0, (s, i) => s + i.cantidad);
}

/// Dashboard comercial.
class DashboardComercial {
  final int totalProveedores;
  final int cotizacionesPendientes;
  final int ordenesPendientes;
  final int comprasPendientes;
  final double montoCotizaciones;
  final double montoOrdenes;
  final double montoCompras;

  const DashboardComercial({
    required this.totalProveedores,
    required this.cotizacionesPendientes,
    required this.ordenesPendientes,
    required this.comprasPendientes,
    required this.montoCotizaciones,
    required this.montoOrdenes,
    required this.montoCompras,
  });
}

/// Servicio central del módulo Comercial.
class ComercialService {
  ComercialService._();
  static final ComercialService instance = ComercialService._();

  final AppDatabase _db = LocalDatabaseService.instance.database;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  String? _empresaId;
  String? _usuarioId;

  void setContext({required String empresaId, String? usuarioId}) {
    _empresaId = empresaId;
    _usuarioId = usuarioId;
  }

  /// Tenant de la sesión activa. Antes caía a 'ROOT' y por eso las listas
  /// salían vacías aunque hubiera datos del tenant real.
  String get empresaId {
    final propio = _empresaId;
    if (propio != null && propio.isNotEmpty) return propio;
    final codigo = AuthController.instance.empresaCodigo;
    return codigo.isNotEmpty ? codigo : 'ROOT';
  }

  String get usuarioId => _usuarioId ?? '';

  // ═══════════════════════════════════════════════════════════════
  // DESCARGA EN VIVO DESDE EL BACKEND
  // Las listas leen la BD local; estas funciones bajan lo que existe en la
  // nube para que nunca estén vacías si hay datos del tenant. Devuelven la
  // cantidad guardada, o -1 si falló la conexión (offline).
  // ═══════════════════════════════════════════════════════════════

  String? _s(Map<String, dynamic> m, List<String> claves) {
    for (final k in claves) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  double _d(Map<String, dynamic> m, List<String> claves, [double def = 0]) {
    for (final k in claves) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v);
        if (p != null) return p;
      }
    }
    return def;
  }

  int _i(Map<String, dynamic> m, List<String> claves, [int def = 0]) {
    for (final k in claves) {
      final v = m[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return def;
  }

  DateTime? _dt(Map<String, dynamic> m, List<String> claves) {
    final s = _s(m, claves);
    return s == null ? null : DateTime.tryParse(s);
  }

  List<Map<String, dynamic>> _itemRows(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _guardarItemsCotizacion(String parentId, dynamic rawItems) async {
    for (final item in _itemRows(rawItems)) {
      final id = _s(item, ['id']);
      if (id == null) continue;
      await _db.into(_db.cotizacionItems).insertOnConflictUpdate(CotizacionItemsCompanion.insert(
        id: id,
        cotizacionId: parentId,
        empresaId: empresaId,
        productoId: Value(_s(item, ['producto_id'])),
        productoCodigo: Value(_s(item, ['producto_codigo'])),
        productoNombre: _s(item, ['producto_nombre']) ?? 'Producto',
        descripcion: Value(_s(item, ['descripcion'])),
        cantidad: _i(item, ['cantidad']),
        precioUnitario: _d(item, ['precio_unitario']),
        descuento: Value(_d(item, ['descuento'])),
        isvRate: Value(_d(item, ['isv_rate'], 15)),
        subtotal: _d(item, ['subtotal']),
        createdAt: Value(_dt(item, ['created_at']) ?? DateTime.now()),
      ));
    }
  }

  Future<void> _guardarItemsOrdenCompra(String parentId, dynamic rawItems) async {
    for (final item in _itemRows(rawItems)) {
      final id = _s(item, ['id']);
      if (id == null) continue;
      await _db.into(_db.ordenCompraItems).insertOnConflictUpdate(OrdenCompraItemsCompanion.insert(
        id: id,
        ordenCompraId: parentId,
        empresaId: empresaId,
        productoId: Value(_s(item, ['producto_id'])),
        productoCodigo: Value(_s(item, ['producto_codigo'])),
        productoNombre: _s(item, ['producto_nombre']) ?? 'Producto',
        descripcion: Value(_s(item, ['descripcion'])),
        cantidad: _i(item, ['cantidad']),
        precioUnitario: _d(item, ['precio_unitario']),
        descuento: Value(_d(item, ['descuento'])),
        isvRate: Value(_d(item, ['isv_rate'], 15)),
        subtotal: _d(item, ['subtotal']),
        createdAt: Value(_dt(item, ['created_at']) ?? DateTime.now()),
      ));
    }
  }

  Future<void> _guardarItemsCompra(String parentId, dynamic rawItems) async {
    for (final item in _itemRows(rawItems)) {
      final id = _s(item, ['id']);
      if (id == null) continue;
      await _db.into(_db.compraItems).insertOnConflictUpdate(CompraItemsCompanion.insert(
        id: id,
        compraId: parentId,
        empresaId: empresaId,
        productoId: Value(_s(item, ['producto_id'])),
        productoCodigo: Value(_s(item, ['producto_codigo'])),
        productoNombre: _s(item, ['producto_nombre']) ?? 'Producto',
        descripcion: Value(_s(item, ['descripcion'])),
        cantidad: _i(item, ['cantidad']),
        precioUnitario: _d(item, ['precio_unitario']),
        descuento: Value(_d(item, ['descuento'])),
        isvRate: Value(_d(item, ['isv_rate'], 15)),
        subtotal: _d(item, ['subtotal']),
        createdAt: Value(_dt(item, ['created_at']) ?? DateTime.now()),
      ));
    }
  }

  Future<int> descargarProveedoresDesdeApi() async {
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/proveedores');
      if (!api.isSuccess(res)) return -1;
      final data = (res['proveedores'] ?? res['data'] ?? const []) as List;
      var n = 0;
      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;
        final id = _s(raw, ['id']);
        if (id == null || id.isEmpty) continue;
        await _db.into(_db.proveedores).insertOnConflictUpdate(
          ProveedoresCompanion.insert(
            id: id,
            empresaId: _s(raw, ['empresa_codigo', 'empresa_id']) ?? empresaId,
            nombre: _s(raw, ['nombre']) ?? 'Proveedor',
            contacto: Value(_s(raw, ['contacto'])),
            telefono: Value(_s(raw, ['telefono', 'teléfono'])),
            email: Value(_s(raw, ['email', 'correo'])),
            direccion: Value(_s(raw, ['direccion', 'dirección'])),
            rtn: Value(_s(raw, ['rtn'])),
            condicionesPago: Value(_i(raw, ['condiciones_pago', 'condicionesPago'], 30)),
            notas: Value(_s(raw, ['notas'])),
            activo: Value(raw['activo'] is bool ? raw['activo'] as bool : true),
            createdAt: Value(_dt(raw, ['created_at', 'fecha']) ?? DateTime.now()),
            updatedAt: Value(_dt(raw, ['updated_at']) ?? DateTime.now()),
            synced: const Value(true),
          ),
        );
        n++;
      }
      return n;
    } catch (_) {
      return -1;
    }
  }

  Future<int> descargarCotizacionesDesdeApi() async {
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/cotizaciones');
      if (!api.isSuccess(res)) return -1;
      final data = (res['cotizaciones'] ?? res['data'] ?? const []) as List;
      var n = 0;
      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;
        final id = _s(raw, ['id']);
        if (id == null || id.isEmpty) continue;
        await _db.into(_db.cotizaciones).insertOnConflictUpdate(
          CotizacionesCompanion.insert(
            id: id,
            empresaId: _s(raw, ['empresa_codigo', 'empresa_id']) ?? empresaId,
            correlativo: Value(_s(raw, ['correlativo'])),
            proveedorId: _s(raw, ['proveedor_id', 'proveedorId']) ?? '',
            proveedorNombre: _s(raw, ['proveedor_nombre', 'proveedorNombre']) ?? 'Proveedor',
            fecha: _dt(raw, ['fecha', 'created_at']) ?? DateTime.now(),
            validezDias: Value(_i(raw, ['validez_dias', 'validezDias'], 30)),
            estado: Value(_s(raw, ['estado']) ?? EstadoCotizacion.borrador),
            subtotal: Value(_d(raw, ['subtotal'])),
            isv15: Value(_d(raw, ['isv_15', 'isv15'])),
            isv18: Value(_d(raw, ['isv_18', 'isv18'])),
            descuento: Value(_d(raw, ['descuento'])),
            total: Value(_d(raw, ['total'])),
            notas: Value(_s(raw, ['notas'])),
            usuarioId: Value(_s(raw, ['usuario_id', 'usuarioId'])),
            createdAt: Value(_dt(raw, ['created_at', 'fecha']) ?? DateTime.now()),
            updatedAt: Value(_dt(raw, ['updated_at']) ?? DateTime.now()),
            synced: const Value(true),
          ),
        );
        await _guardarItemsCotizacion(id, raw['items']);
        n++;
      }
      return n;
    } catch (_) {
      return -1;
    }
  }

  Future<int> descargarOrdenesCompraDesdeApi() async {
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/ordenes-compra');
      if (!api.isSuccess(res)) return -1;
      final data = (res['ordenes'] ?? res['ordenes_compra'] ?? res['data'] ?? const []) as List;
      var n = 0;
      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;
        final id = _s(raw, ['id']);
        if (id == null || id.isEmpty) continue;
        await _db.into(_db.ordenesCompra).insertOnConflictUpdate(
          OrdenesCompraCompanion.insert(
            id: id,
            empresaId: _s(raw, ['empresa_codigo', 'empresa_id']) ?? empresaId,
            correlativo: Value(_s(raw, ['correlativo'])),
            proveedorId: _s(raw, ['proveedor_id', 'proveedorId']) ?? '',
            proveedorNombre: _s(raw, ['proveedor_nombre', 'proveedorNombre']) ?? 'Proveedor',
            cotizacionId: Value(_s(raw, ['cotizacion_id', 'cotizacionId'])),
            fecha: _dt(raw, ['fecha', 'created_at']) ?? DateTime.now(),
            fechaEntrega: Value(_dt(raw, ['fecha_entrega', 'fechaEntrega'])),
            estado: Value(_s(raw, ['estado']) ?? EstadoOrdenCompra.borrador),
            subtotal: Value(_d(raw, ['subtotal'])),
            isv15: Value(_d(raw, ['isv_15', 'isv15'])),
            isv18: Value(_d(raw, ['isv_18', 'isv18'])),
            descuento: Value(_d(raw, ['descuento'])),
            total: Value(_d(raw, ['total'])),
            notas: Value(_s(raw, ['notas'])),
            usuarioId: Value(_s(raw, ['usuario_id', 'usuarioId'])),
            createdAt: Value(_dt(raw, ['created_at', 'fecha']) ?? DateTime.now()),
            updatedAt: Value(_dt(raw, ['updated_at']) ?? DateTime.now()),
            synced: const Value(true),
          ),
        );
        await _guardarItemsOrdenCompra(id, raw['items']);
        n++;
      }
      return n;
    } catch (_) {
      return -1;
    }
  }

  Future<int> descargarComprasDesdeApi() async {
    try {
      final api = ApiService.instance;
      final res = await api.get('/api/compras');
      if (!api.isSuccess(res)) return -1;
      final data = (res['compras'] ?? res['data'] ?? const []) as List;
      var n = 0;
      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;
        final id = _s(raw, ['id']);
        if (id == null || id.isEmpty) continue;
        await _db.into(_db.compras).insertOnConflictUpdate(
          ComprasCompanion.insert(
            id: id,
            empresaId: _s(raw, ['empresa_codigo', 'empresa_id']) ?? empresaId,
            correlativo: Value(_s(raw, ['correlativo'])),
            proveedorId: _s(raw, ['proveedor_id', 'proveedorId']) ?? '',
            proveedorNombre: _s(raw, ['proveedor_nombre', 'proveedorNombre']) ?? 'Proveedor',
            ordenCompraId: Value(_s(raw, ['orden_compra_id', 'ordenCompraId'])),
            numeroFactura: Value(_s(raw, ['numero_factura', 'numeroFactura'])),
            fecha: _dt(raw, ['fecha', 'created_at']) ?? DateTime.now(),
            fechaVencimiento: Value(_dt(raw, ['fecha_vencimiento', 'fechaVencimiento'])),
            estado: Value(_s(raw, ['estado']) ?? EstadoCompra.pendiente),
            subtotal: Value(_d(raw, ['subtotal'])),
            isv15: Value(_d(raw, ['isv_15', 'isv15'])),
            isv18: Value(_d(raw, ['isv_18', 'isv18'])),
            descuento: Value(_d(raw, ['descuento'])),
            total: Value(_d(raw, ['total'])),
            notas: Value(_s(raw, ['notas'])),
            usuarioId: Value(_s(raw, ['usuario_id', 'usuarioId'])),
            createdAt: Value(_dt(raw, ['created_at', 'fecha']) ?? DateTime.now()),
            updatedAt: Value(_dt(raw, ['updated_at']) ?? DateTime.now()),
            synced: const Value(true),
          ),
        );
        await _guardarItemsCompra(id, raw['items']);
        n++;
      }
      return n;
    } catch (_) {
      return -1;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PROVEEDORES
  // ═══════════════════════════════════════════════════════════════

  Future<List<Proveedore>> getProveedores() async {
    return await (_db.select(_db.proveedores)
          ..where((p) => p.empresaId.equals(empresaId))
          ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
        .get();
  }

  Future<Proveedore?> getProveedor(String id) async {
    final q = _db.select(_db.proveedores)..where((p) => p.id.equals(id) & p.empresaId.equals(empresaId));
    return await q.getSingleOrNull();
  }

  Future<Proveedore> crearProveedor({
    required String nombre,
    String? contacto,
    String? telefono,
    String? email,
    String? direccion,
    String? rtn,
    int condicionesPago = 30,
    String? notas,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.proveedores).insert(
      ProveedoresCompanion.insert(
        id: id,
        empresaId: empresaId,
        nombre: nombre.trim(),
        contacto: Value(contacto?.trim()),
        telefono: Value(telefono?.trim()),
        email: Value(email?.trim()),
        direccion: Value(direccion?.trim()),
        rtn: Value(rtn?.trim()),
        condicionesPago: Value(condicionesPago),
        notas: Value(notas?.trim()),
        activo: const Value(true),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    final q = _db.select(_db.proveedores)..where((p) => p.id.equals(id) & p.empresaId.equals(empresaId));
    // Encolar sync
    await SyncService.instance.enqueueSync(
      tabla: 'proveedores',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'proveedor': {
          'id': id,
          'nombre': nombre,
          'contacto': contacto,
          'telefono': telefono,
          'email': email,
          'direccion': direccion,
          'rtn': rtn,
          'condiciones_pago': condicionesPago,
          'notas': notas,
        },
      },
      empresaId: empresaId,
    );
    return await q.getSingle();
  }

  Future<void> actualizarProveedor({
    required String id,
    required String nombre,
    String? contacto,
    String? telefono,
    String? email,
    String? direccion,
    String? rtn,
    int condicionesPago = 30,
    String? notas,
    bool activo = true,
  }) async {
    await (_db.update(_db.proveedores)..where((p) => p.id.equals(id) & p.empresaId.equals(empresaId))).write(
      ProveedoresCompanion(
        nombre: Value(nombre.trim()),
        contacto: Value(contacto?.trim()),
        telefono: Value(telefono?.trim()),
        email: Value(email?.trim()),
        direccion: Value(direccion?.trim()),
        rtn: Value(rtn?.trim()),
        condicionesPago: Value(condicionesPago),
        notas: Value(notas?.trim()),
        activo: Value(activo),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    await SyncService.instance.enqueueSync(
      tabla: 'proveedores',
      operacion: SyncOperation.update,
      datos: {
        'empresa_codigo': empresaId,
        'proveedor': {
          'id': id,
          'nombre': nombre,
          'contacto': contacto,
          'telefono': telefono,
          'email': email,
          'direccion': direccion,
          'rtn': rtn,
          'condiciones_pago': condicionesPago,
          'notas': notas,
          'activo': activo,
        },
      },
      empresaId: empresaId,
    );
  }

  Future<void> eliminarProveedor(String id) async {
    final tieneCotizaciones = await (_db.select(_db.cotizaciones)
          ..where((c) => c.proveedorId.equals(id) & c.empresaId.equals(empresaId))
          ..limit(1))
        .getSingleOrNull();
    if (tieneCotizaciones != null) {
      throw StateError('El proveedor tiene cotizaciones. Desactívalo en su lugar.');
    }
    await (_db.delete(_db.proveedores)..where((p) => p.id.equals(id) & p.empresaId.equals(empresaId))).go();
  }

  // ═══════════════════════════════════════════════════════════════
  // COTIZACIONES
  // ═══════════════════════════════════════════════════════════════

  Future<String> _siguienteCorrelativoCotizacion() async {
    final ahora = DateTime.now();
    final prefijo = 'COT-${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-';
    final ultima = await (_db.select(_db.cotizaciones)
          ..where(
            (c) =>
                c.empresaId.equals(empresaId) &
                c.correlativo.like('$prefijo%'),
          )
          ..orderBy([(c) => OrderingTerm.desc(c.correlativo)])
          ..limit(1))
        .getSingleOrNull();
    int n = 1;
    if (ultima?.correlativo != null) {
      n = int.tryParse(ultima!.correlativo!.substring(prefijo.length)) ?? 1;
      n++;
    }
    return '$prefijo${n.toString().padLeft(4, '0')}';
  }

  Future<List<Cotizacione>> getCotizaciones() async {
    return await (_db.select(_db.cotizaciones)
          ..where((c) => c.empresaId.equals(empresaId))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  Future<CotizacionDetalle?> getCotizacion(String id) async {
    final q = _db.select(_db.cotizaciones)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId));
    final c = await q.getSingleOrNull();
    if (c == null) return null;
    final items = await (_db.select(_db.cotizacionItems)
          ..where((i) => i.cotizacionId.equals(id) & i.empresaId.equals(empresaId))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
        .get();
    return CotizacionDetalle(cotizacion: c, items: items);
  }

  Future<Cotizacione> crearCotizacion({
    required String proveedorId,
    required List<(Producto, int, double, double)> items, // producto, cantidad, precio, descuento
    int validezDias = 30,
    String? notas,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Agregá al menos un item a la cotización.');
    }
    final proveedor = await getProveedor(proveedorId);
    if (proveedor == null) throw StateError('Proveedor no encontrado.');

    final id = const Uuid().v4();
    final correlativo = await _siguienteCorrelativoCotizacion();

    double subtotal = 0, isv15 = 0, isv18 = 0, descuento = 0;
    for (final (p, cant, precio, dcto) in items) {
      final base = precio * cant * (1 - dcto / 100);
      subtotal += base;
      descuento += precio * cant * (dcto / 100);
      final isv = p.isvRate >= 18 ? 18.0 : 15.0;
      if (isv >= 18) {
        isv18 += base * (isv / 100);
      } else {
        isv15 += base * (isv / 100);
      }
    }
    final total = subtotal + isv15 + isv18;

    await _db.into(_db.cotizaciones).insert(
      CotizacionesCompanion.insert(
        id: id,
        empresaId: empresaId,
        correlativo: Value(correlativo),
        proveedorId: proveedorId,
        proveedorNombre: proveedor.nombre,
        fecha: DateTime.now(),
        validezDias: Value(validezDias),
        estado: const Value(EstadoCotizacion.borrador),
        subtotal: Value(subtotal),
        isv15: Value(isv15),
        isv18: Value(isv18),
        descuento: Value(descuento),
        total: Value(total),
        notas: Value(notas?.trim()),
        usuarioId: Value(usuarioId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );

    for (final (p, cant, precio, dcto) in items) {
      final base = precio * cant * (1 - dcto / 100);
      await _db.into(_db.cotizacionItems).insert(
        CotizacionItemsCompanion.insert(
          id: const Uuid().v4(),
          cotizacionId: id,
          empresaId: empresaId,
          productoId: Value(p.id),
          productoCodigo: Value(p.codigo),
          productoNombre: p.nombre,
          descripcion: Value(p.descripcion),
          cantidad: cant,
          precioUnitario: precio,
          descuento: Value(dcto),
          isvRate: Value(p.isvRate),
          subtotal: base,
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    final q = _db.select(_db.cotizaciones)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId));
    // Encolar cotización para sync
    await SyncService.instance.enqueueSync(
      tabla: 'cotizaciones',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'cotizacion': {
          'id': id,
          'correlativo': correlativo,
          'proveedor_id': proveedorId,
          'proveedor_nombre': proveedor.nombre,
          'fecha': DateTime.now().toIso8601String(),
          'validez_dias': validezDias,
          'estado': EstadoCotizacion.borrador,
          'subtotal': subtotal,
          'isv15': isv15,
          'isv18': isv18,
          'descuento': descuento,
          'total': total,
          'notas': notas,
          'usuario_id': usuarioId,
        },
      },
      empresaId: empresaId,
    );
    for (final (producto, cantidad, precio, descuentoLinea) in items) {
      await SyncService.instance.enqueueSync(
        tabla: 'cotizacion_items',
        operacion: SyncOperation.insert,
        datos: {
          'empresa_codigo': empresaId,
          'id': const Uuid().v4(),
          'cotizacion_id': id,
          'producto_id': producto.id,
          'producto_codigo': producto.codigo,
          'producto_nombre': producto.nombre,
          'descripcion': producto.descripcion,
          'cantidad': cantidad,
          'precio_unitario': precio,
          'descuento': descuentoLinea,
          'isv_rate': producto.isvRate,
          'subtotal': precio * cantidad * (1 - descuentoLinea / 100),
          'created_at': DateTime.now().toIso8601String(),
        },
        empresaId: empresaId,
      );
    }
    return await q.getSingle();
  }

  Future<void> enviarCotizacion(String id) async {
    final detalle = await getCotizacion(id);
    if (detalle == null) throw StateError('Cotización no encontrada.');
    if (detalle.cotizacion.estado != EstadoCotizacion.borrador) {
      throw StateError('Solo se pueden enviar cotizaciones en borrador.');
    }
    await _cambiarEstadoCotizacion(id, EstadoCotizacion.enviada);
  }

  Future<void> aceptarCotizacion(String id) async {
    final detalle = await getCotizacion(id);
    if (detalle == null) throw StateError('Cotización no encontrada.');
    if (detalle.cotizacion.estado != EstadoCotizacion.enviada) {
      throw StateError('Solo se pueden aceptar cotizaciones enviadas.');
    }
    await _cambiarEstadoCotizacion(id, EstadoCotizacion.aceptada);
  }

  Future<void> rechazarCotizacion(String id) async {
    final detalle = await getCotizacion(id);
    if (detalle == null) throw StateError('Cotización no encontrada.');
    if (detalle.cotizacion.estado != EstadoCotizacion.enviada) {
      throw StateError('Solo se pueden rechazar cotizaciones enviadas.');
    }
    await _cambiarEstadoCotizacion(id, EstadoCotizacion.rechazada);
  }

  Future<void> _cambiarEstadoCotizacion(String id, String estado) async {
    await _db.transaction(() async {
      await (_db.update(_db.cotizaciones)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId))).write(
        CotizacionesCompanion(
          estado: Value(estado),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
      await SyncService.instance.enqueueSync(
        tabla: 'cotizaciones',
        operacion: SyncOperation.update,
        datos: {'empresa_codigo': empresaId, 'cotizacion': {'id': id, 'estado': estado}},
        empresaId: empresaId,
        triggerSync: false,
      );
    });
    SyncService.instance.syncNowIfOnline();
  }

  Future<void> _marcarCotizacionesVencidas() async {
    final ahora = DateTime.now();
    final todas = await (_db.select(_db.cotizaciones)
          ..where((c) => c.empresaId.equals(empresaId) & c.estado.equals(EstadoCotizacion.enviada)))
        .get();
    
    for (final c in todas) {
      final fechaVencimiento = c.fecha.add(Duration(days: c.validezDias));
      if (fechaVencimiento.isBefore(ahora)) {
        await _cambiarEstadoCotizacion(c.id, EstadoCotizacion.vencida);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ÓRDENES DE COMPRA
  // ═══════════════════════════════════════════════════════════════

  Future<String> _siguienteCorrelativoOrden() async {
    final ahora = DateTime.now();
    final prefijo = 'OC-${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-';
    final ultima = await (_db.select(_db.ordenesCompra)
          ..where(
            (o) =>
                o.empresaId.equals(empresaId) &
                o.correlativo.like('$prefijo%'),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.correlativo)])
          ..limit(1))
        .getSingleOrNull();
    int n = 1;
    if (ultima?.correlativo != null) {
      n = int.tryParse(ultima!.correlativo!.substring(prefijo.length)) ?? 1;
      n++;
    }
    return '$prefijo${n.toString().padLeft(4, '0')}';
  }

  Future<List<OrdenesCompraData>> getOrdenesCompra() async {
    return await (_db.select(_db.ordenesCompra)
          ..where((o) => o.empresaId.equals(empresaId))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  Future<OrdenCompraDetalle?> getOrdenCompra(String id) async {
    final q = _db.select(_db.ordenesCompra)..where((o) => o.id.equals(id) & o.empresaId.equals(empresaId));
    final o = await q.getSingleOrNull();
    if (o == null) return null;
    final items = await (_db.select(_db.ordenCompraItems)
          ..where((i) => i.ordenCompraId.equals(id) & i.empresaId.equals(empresaId))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
        .get();
    return OrdenCompraDetalle(orden: o, items: items);
  }

  Future<OrdenesCompraData> crearOrdenCompra({
    required String proveedorId,
    String? cotizacionId,
    required List<(Producto, int, double, double)> items, // producto, cantidad, precio, descuento
    DateTime? fechaEntrega,
    String? notas,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Agregá al menos un item a la orden de compra.');
    }
    final proveedor = await getProveedor(proveedorId);
    if (proveedor == null) throw StateError('Proveedor no encontrado.');

    if (cotizacionId != null) {
      final cot = await getCotizacion(cotizacionId);
      if (cot == null) throw StateError('Cotización no encontrada.');
      if (cot.cotizacion.proveedorId != proveedorId) {
        throw StateError('La cotización pertenece a otro proveedor.');
      }
      if (cot.cotizacion.estado != EstadoCotizacion.aceptada) {
        throw StateError('Solo se pueden crear órdenes de cotizaciones aceptadas.');
      }
    }

    final id = const Uuid().v4();
    final correlativo = await _siguienteCorrelativoOrden();

    double subtotal = 0, isv15 = 0, isv18 = 0, descuento = 0;
    for (final (p, cant, precio, dcto) in items) {
      final base = precio * cant * (1 - dcto / 100);
      subtotal += base;
      descuento += precio * cant * (dcto / 100);
      final isv = p.isvRate >= 18 ? 18.0 : 15.0;
      if (isv >= 18) {
        isv18 += base * (isv / 100);
      } else {
        isv15 += base * (isv / 100);
      }
    }
    final total = subtotal + isv15 + isv18;

    await _db.into(_db.ordenesCompra).insert(
      OrdenesCompraCompanion.insert(
        id: id,
        empresaId: empresaId,
        correlativo: Value(correlativo),
        proveedorId: proveedorId,
        proveedorNombre: proveedor.nombre,
        cotizacionId: Value(cotizacionId),
        fecha: DateTime.now(),
        fechaEntrega: Value(fechaEntrega),
        estado: const Value(EstadoOrdenCompra.borrador),
        subtotal: Value(subtotal),
        isv15: Value(isv15),
        isv18: Value(isv18),
        descuento: Value(descuento),
        total: Value(total),
        notas: Value(notas?.trim()),
        usuarioId: Value(usuarioId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );

    for (final (p, cant, precio, dcto) in items) {
      final base = precio * cant * (1 - dcto / 100);
      await _db.into(_db.ordenCompraItems).insert(
        OrdenCompraItemsCompanion.insert(
          id: const Uuid().v4(),
          ordenCompraId: id,
          empresaId: empresaId,
          productoId: Value(p.id),
          productoCodigo: Value(p.codigo),
          productoNombre: p.nombre,
          descripcion: Value(p.descripcion),
          cantidad: cant,
          precioUnitario: precio,
          descuento: Value(dcto),
          isvRate: Value(p.isvRate),
          subtotal: base,
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    if (cotizacionId != null) {
      await (_db.update(_db.cotizaciones)..where((c) => c.id.equals(cotizacionId) & c.empresaId.equals(empresaId))).write(
        CotizacionesCompanion(
          estado: const Value(EstadoCotizacion.aceptada),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    }

    await SyncService.instance.enqueueSync(
      tabla: 'ordenes_compra',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': empresaId,
        'orden_compra': {
          'id': id,
          'correlativo': correlativo,
          'proveedor_id': proveedorId,
          'proveedor_nombre': proveedor.nombre,
          'cotizacion_id': cotizacionId,
          'fecha': DateTime.now().toIso8601String(),
          'fecha_entrega': fechaEntrega?.toIso8601String(),
          'estado': EstadoOrdenCompra.borrador,
          'subtotal': subtotal,
          'isv15': isv15,
          'isv18': isv18,
          'descuento': descuento,
          'total': total,
          'notas': notas?.trim(),
          'usuario_id': usuarioId,
        },
      },
      empresaId: empresaId,
    );
    for (final (producto, cantidad, precio, descuentoLinea) in items) {
      await SyncService.instance.enqueueSync(
        tabla: 'orden_compra_items',
        operacion: SyncOperation.insert,
        datos: {
          'empresa_codigo': empresaId,
          'id': const Uuid().v4(),
          'orden_compra_id': id,
          'producto_id': producto.id,
          'producto_codigo': producto.codigo,
          'producto_nombre': producto.nombre,
          'descripcion': producto.descripcion,
          'cantidad': cantidad,
          'precio_unitario': precio,
          'descuento': descuentoLinea,
          'isv_rate': producto.isvRate,
          'subtotal': precio * cantidad * (1 - descuentoLinea / 100),
          'created_at': DateTime.now().toIso8601String(),
        },
        empresaId: empresaId,
      );
    }
    if (cotizacionId != null) {
      await SyncService.instance.enqueueSync(
        tabla: 'cotizaciones',
        operacion: SyncOperation.update,
        datos: {
          'empresa_codigo': empresaId,
          'cotizacion': {'id': cotizacionId, 'estado': EstadoCotizacion.aceptada},
        },
        empresaId: empresaId,
      );
    }

    final q = _db.select(_db.ordenesCompra)..where((o) => o.id.equals(id) & o.empresaId.equals(empresaId));
    return await q.getSingle();
  }

  Future<void> enviarOrdenCompra(String id) async {
    final detalle = await getOrdenCompra(id);
    if (detalle == null) throw StateError('Orden de compra no encontrada.');
    if (detalle.orden.estado != EstadoOrdenCompra.borrador) {
      throw StateError('Solo se pueden enviar órdenes en borrador.');
    }
    await (_db.update(_db.ordenesCompra)..where((o) => o.id.equals(id) & o.empresaId.equals(empresaId))).write(
      OrdenesCompraCompanion(
        estado: const Value(EstadoOrdenCompra.enviada),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    await SyncService.instance.enqueueSync(
      tabla: 'ordenes_compra',
      operacion: SyncOperation.update,
      datos: {
        'empresa_codigo': empresaId,
        'orden_compra': {'id': id, 'estado': EstadoOrdenCompra.enviada},
      },
      empresaId: empresaId,
    );
  }

  Future<void> cancelarOrdenCompra(String id) async {
    final detalle = await getOrdenCompra(id);
    if (detalle == null) throw StateError('Orden de compra no encontrada.');
    if (detalle.orden.estado == EstadoOrdenCompra.recibida ||
        detalle.orden.estado == EstadoOrdenCompra.parcial) {
      throw StateError('No se puede cancelar una orden ya recibida.');
    }
    await (_db.update(_db.ordenesCompra)..where((o) => o.id.equals(id) & o.empresaId.equals(empresaId))).write(
      OrdenesCompraCompanion(
        estado: const Value(EstadoOrdenCompra.cancelada),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPRAS (RECEPCIÓN / FACTURA PROVEEDOR) - INCREMENTA STOCK
  // ═══════════════════════════════════════════════════════════════

  Future<String> _siguienteCorrelativoCompra() async {
    final ahora = DateTime.now();
    final prefijo = 'COM-${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-';
    final ultima = await (_db.select(_db.compras)
          ..where(
            (c) =>
                c.empresaId.equals(empresaId) &
                c.correlativo.like('$prefijo%'),
          )
          ..orderBy([(c) => OrderingTerm.desc(c.correlativo)])
          ..limit(1))
        .getSingleOrNull();
    int n = 1;
    if (ultima?.correlativo != null) {
      n = int.tryParse(ultima!.correlativo!.substring(prefijo.length)) ?? 1;
      n++;
    }
    return '$prefijo${n.toString().padLeft(4, '0')}';
  }

  Future<List<Compra>> getCompras() async {
    return await (_db.select(_db.compras)
          ..where((c) => c.empresaId.equals(empresaId))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  Future<CompraDetalle?> getCompra(String id) async {
    final q = _db.select(_db.compras)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId));
    final c = await q.getSingleOrNull();
    if (c == null) return null;
    final items = await (_db.select(_db.compraItems)
          ..where((i) => i.compraId.equals(id) & i.empresaId.equals(empresaId))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
        .get();
    return CompraDetalle(compra: c, items: items);
  }

  Future<Compra> crearCompra({
    required String proveedorId,
    String? ordenCompraId,
    String? numeroFactura,
    required List<(Producto, int, double, double)> items, // producto, cantidad, precio, descuento
    DateTime? fechaVencimiento,
    String? notas,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Agregá al menos un item a la compra.');
    }
    final proveedor = await getProveedor(proveedorId);
    if (proveedor == null) throw StateError('Proveedor no encontrado.');

    if (ordenCompraId != null) {
      final oc = await getOrdenCompra(ordenCompraId);
      if (oc == null) throw StateError('Orden de compra no encontrada.');
      if (oc.orden.proveedorId != proveedorId) {
        throw StateError('La orden pertenece a otro proveedor.');
      }
      if (oc.orden.estado != EstadoOrdenCompra.enviada &&
          oc.orden.estado != EstadoOrdenCompra.recibida &&
          oc.orden.estado != EstadoOrdenCompra.parcial) {
        throw StateError('Solo se puede crear compra de órdenes enviadas/recibidas.');
      }
    }

    final id = const Uuid().v4();
    final correlativo = await _siguienteCorrelativoCompra();

    double subtotal = 0, isv15 = 0, isv18 = 0, descuento = 0;
    for (final (p, cant, precio, dcto) in items) {
      final base = precio * cant * (1 - dcto / 100);
      subtotal += base;
      descuento += precio * cant * (dcto / 100);
      final isv = p.isvRate >= 18 ? 18.0 : 15.0;
      if (isv >= 18) {
        isv18 += base * (isv / 100);
      } else {
        isv15 += base * (isv / 100);
      }
    }
    final total = subtotal + isv15 + isv18;

    final fechaCompra = DateTime.now();
    final itemsSync = <Map<String, dynamic>>[];
    await _db.transaction(() async {
      await _db.into(_db.compras).insert(
        ComprasCompanion.insert(
          id: id,
          empresaId: empresaId,
          correlativo: Value(correlativo),
          proveedorId: proveedorId,
          proveedorNombre: proveedor.nombre,
          ordenCompraId: Value(ordenCompraId),
          numeroFactura: Value(numeroFactura?.trim()),
          fecha: fechaCompra,
          fechaVencimiento: Value(fechaVencimiento),
          estado: const Value(EstadoCompra.pendiente),
          subtotal: Value(subtotal),
          isv15: Value(isv15),
          isv18: Value(isv18),
          descuento: Value(descuento),
          total: Value(total),
          notas: Value(notas?.trim()),
          usuarioId: Value(usuarioId),
          createdAt: Value(fechaCompra),
          updatedAt: Value(fechaCompra),
          synced: const Value(false),
        ),
      );

      for (final (p, cant, precio, dcto) in items) {
        final base = precio * cant * (1 - dcto / 100);
        final itemId = const Uuid().v4();
        await _db.into(_db.compraItems).insert(
          CompraItemsCompanion.insert(
            id: itemId,
            compraId: id,
            empresaId: empresaId,
            productoId: Value(p.id),
            productoCodigo: Value(p.codigo),
            productoNombre: p.nombre,
            descripcion: Value(p.descripcion),
            cantidad: cant,
            precioUnitario: precio,
            descuento: Value(dcto),
            isvRate: Value(p.isvRate),
            subtotal: base,
            createdAt: Value(fechaCompra),
          ),
        );
        itemsSync.add({
          'id': itemId,
          'producto_codigo': p.codigo,
          'producto_nombre': p.nombre,
          'descripcion': p.descripcion,
          'cantidad': cant,
          'precio_unitario': precio,
          'descuento': dcto,
          'isv_rate': p.isvRate,
          'subtotal': base,
        });
      }

      // Se actualiza el stock en la misma transacci?n que el documento y la cola.
      for (final (p, cant, precio, _) in items) {
        await _incrementarStock(p.id, cant, precioCompraNuevo: precio, referencia: 'Compra a proveedor');
      }

      await SyncService.instance.enqueueSync(
        tabla: 'compras',
        operacion: SyncOperation.insert,
        datos: {
          'empresa_codigo': empresaId,
          'compra': {
            'id': id,
            'correlativo': correlativo,
            'proveedor_id': proveedorId,
            'proveedor_nombre': proveedor.nombre,
            'orden_compra_id': ordenCompraId,
            'numero_factura': numeroFactura?.trim(),
            'fecha': fechaCompra.toIso8601String(),
            'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
            'estado': EstadoCompra.pendiente,
            'subtotal': subtotal,
            'isv15': isv15,
            'isv18': isv18,
            'descuento': descuento,
            'total': total,
            'notas': notas?.trim(),
            'usuario_id': usuarioId,
            'items': itemsSync,
          },
        },
        empresaId: empresaId,
        triggerSync: false,
      );
    });

    if (ordenCompraId != null) {
      await _actualizarEstadoOrden(ordenCompraId);
    }

    // La recepción debe reflejarse en Supabase y en el Kardex junto con el
    // incremento local de existencias. La cola conserva el documento completo
    // mientras no haya red y el backend lo aplica dentro de una sola transacción.
    SyncService.instance.syncNowIfOnline();

    final q = _db.select(_db.compras)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId));
    return await q.getSingle();
  }

  Future<void> _incrementarStock(String productoId, int cantidad, {required double precioCompraNuevo, String? referencia}) async {
    final q = _db.select(_db.productos)..where((p) => p.id.equals(productoId) & p.empresaId.equals(empresaId));
    final producto = await q.getSingleOrNull();
    if (producto == null) throw StateError('Producto no encontrado en esta empresa.');
    await (_db.update(_db.productos)..where((p) => p.id.equals(productoId) & p.empresaId.equals(empresaId))).write(
      ProductosCompanion(
        stockActual: Value(producto.stockActual + cantidad),
        precioCompra: Value(
          producto.stockActual + cantidad == 0
              ? precioCompraNuevo
              : ((producto.stockActual * producto.precioCompra) + (cantidad * precioCompraNuevo)) /
                  (producto.stockActual + cantidad),
        ),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    // Kardex: la compra del proveedor es una ENTRADA.
    await _localDb.registrarMovimientoKardexSolo(
      empresaCodigo: empresaId,
      productoId: productoId,
      productoCodigo: producto.codigo ?? '',
      nombreProducto: producto.nombre,
      tipo: 'entrada',
      cantidad: cantidad,
      stockDespues: producto.stockActual + cantidad,
      referencia: referencia ?? 'Compra a proveedor',
    );
  }

  Future<void> _actualizarEstadoOrden(String ordenId) async {
    final oc = await getOrdenCompra(ordenId);
    if (oc == null) return;

    final compras = await (_db.select(_db.compras)
          ..where((c) => c.ordenCompraId.equals(ordenId) & c.empresaId.equals(empresaId) & c.estado.isNotValue(EstadoCompra.anulada)))
        .get();

    int recibidos = 0;
    for (final c in compras) {
      final items = await (_db.select(_db.compraItems)
            ..where((i) => i.compraId.equals(c.id) & i.empresaId.equals(empresaId)))
          .get();
      for (final i in items) {
        OrdenCompraItem? itemOC;
        for (final oi in oc.items) {
          if (oi.productoId == i.productoId) {
            itemOC = oi;
            break;
          }
        }
        if (itemOC != null) {
          if (i.cantidad >= itemOC.cantidad) {
            recibidos += itemOC.cantidad;
          } else {
            recibidos += i.cantidad;
          }
        }
      }
    }

    final totalSolicitado = oc.items.fold<int>(0, (s, i) => s + i.cantidad);
    String nuevoEstado;
    if (recibidos >= totalSolicitado) {
      nuevoEstado = EstadoOrdenCompra.recibida;
    } else if (recibidos > 0) {
      nuevoEstado = EstadoOrdenCompra.parcial;
    } else {
      nuevoEstado = EstadoOrdenCompra.enviada;
    }

      await (_db.update(_db.ordenesCompra)..where((o) => o.id.equals(ordenId) & o.empresaId.equals(empresaId))).write(
      OrdenesCompraCompanion(
        estado: Value(nuevoEstado),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    await SyncService.instance.enqueueSync(
      tabla: 'ordenes_compra',
      operacion: SyncOperation.update,
      datos: {
        'empresa_codigo': empresaId,
        'orden_compra': {'id': ordenId, 'estado': nuevoEstado},
      },
      empresaId: empresaId,
    );
  }

  Future<void> pagarCompra(String id) async {
    final detalle = await getCompra(id);
    if (detalle == null) throw StateError('Compra no encontrada.');
    if (detalle.compra.estado == EstadoCompra.anulada) {
      throw StateError('Una compra anulada no se puede pagar.');
    }
    await (_db.update(_db.compras)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId))).write(
      ComprasCompanion(
        estado: const Value(EstadoCompra.pagada),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    await SyncService.instance.enqueueSync(
      tabla: 'compras',
      operacion: SyncOperation.update,
      datos: {
        'empresa_codigo': empresaId,
        'compra': {'id': id, 'estado': EstadoCompra.pagada},
      },
      empresaId: empresaId,
    );
  }

  Future<void> anularCompra(String id) async {
    final detalle = await getCompra(id);
    if (detalle == null) throw StateError('Compra no encontrada.');
    if (detalle.compra.estado == EstadoCompra.pagada) {
      throw StateError('Una compra pagada no se puede anular (hacé nota de crédito).');
    }
    if (detalle.compra.estado == EstadoCompra.anulada) return;
    // Revertir stock, estado y cola en una sola transacción local. Si el stock
    // ya salió por ventas u otros movimientos, no se permite dejar una compra
    // anulada con inventario distinto en el dispositivo y en Supabase.
    await _db.transaction(() async {
      for (final item in detalle.items) {
        final productoId = item.productoId;
        if (productoId == null) throw StateError('No se puede anular: una línea no tiene producto asociado.');
        final q = _db.select(_db.productos)
          ..where((p) => p.id.equals(productoId) & p.empresaId.equals(empresaId));
        final prod = await q.getSingleOrNull();
        if (prod == null) throw StateError('No se puede anular: no se encontró ${item.productoNombre} en esta empresa.');
        if (prod.stockActual < item.cantidad) {
          throw StateError('No se puede anular: ${item.productoNombre} ya salió del inventario. Registra una devolución o ajuste primero.');
        }
        await (_db.update(_db.productos)..where((p) => p.id.equals(productoId) & p.empresaId.equals(empresaId))).write(
          ProductosCompanion(
            stockActual: Value(prod.stockActual - item.cantidad),
            updatedAt: Value(DateTime.now()),
            synced: const Value(false),
          ),
        );
        // Kardex: anular la compra DEVUELVE mercadería al proveedor (salida).
        await _localDb.registrarMovimientoKardexSolo(
          empresaCodigo: empresaId,
          productoId: productoId,
          productoCodigo: prod.codigo ?? '',
          nombreProducto: prod.nombre,
          tipo: 'salida',
          cantidad: item.cantidad,
          stockDespues: prod.stockActual - item.cantidad,
          referencia: 'Anulación de compra',
        );
      }
      await (_db.update(_db.compras)..where((c) => c.id.equals(id) & c.empresaId.equals(empresaId))).write(
        ComprasCompanion(
          estado: const Value(EstadoCompra.anulada),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
      await SyncService.instance.enqueueSync(
        tabla: 'compras',
        operacion: SyncOperation.update,
        datos: {
          'empresa_codigo': empresaId,
          'compra': {'id': id, 'estado': EstadoCompra.anulada},
        },
        empresaId: empresaId,
        triggerSync: false,
      );
    });
    SyncService.instance.syncNowIfOnline();
    if (detalle.compra.ordenCompraId != null) {
      await _actualizarEstadoOrden(detalle.compra.ordenCompraId!);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════════

  Future<DashboardComercial> getDashboard() async {
    await _marcarCotizacionesVencidas();
    final proveedores = await getProveedores();
    final cotizaciones = await getCotizaciones();
    final ordenes = await getOrdenesCompra();
    final compras = await getCompras();

    int cotPendientes = 0, ocPendientes = 0, comPendientes = 0;
    double montoCot = 0, montoOC = 0, montoCom = 0;

    for (final c in cotizaciones) {
      if (c.estado == EstadoCotizacion.enviada || c.estado == EstadoCotizacion.borrador) {
        cotPendientes++;
      }
      montoCot += c.total;
    }
    for (final o in ordenes) {
      if (o.estado == EstadoOrdenCompra.enviada || o.estado == EstadoOrdenCompra.borrador) {
        ocPendientes++;
      }
      montoOC += o.total;
    }
    for (final c in compras) {
      if (c.estado == EstadoCompra.pendiente || c.estado == EstadoCompra.parcial) {
        comPendientes++;
      }
      montoCom += c.total;
    }

    return DashboardComercial(
      totalProveedores: proveedores.length,
      cotizacionesPendientes: cotPendientes,
      ordenesPendientes: ocPendientes,
      comprasPendientes: comPendientes,
      montoCotizaciones: montoCot,
      montoOrdenes: montoOC,
      montoCompras: montoCom,
    );
  }
}
