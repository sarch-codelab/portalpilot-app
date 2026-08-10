// lib/Shared/services/canal_moderno_service.dart
// Motor del Canal Moderno (Paso 6):
//  - Multi-sucursal: CRUD de sucursales. Cada sucursal es una bodega
//    de inventario (productos.bodega) identificada por su código.
//  - Transferencias: traslado de inventario entre sucursales con ciclo
//    pendiente -> en_transito -> recibida | cancelada.
//  - Consolidado: dashboard agregado de sucursales, stock, valor de
//    inventario y ventas de la empresa.

import 'package:drift/drift.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

/// Estados del ciclo de una transferencia.
class EstadoTransferencia {
  static const String pendiente = 'pendiente';
  static const String enTransito = 'en_transito';
  static const String recibida = 'recibida';
  static const String cancelada = 'cancelada';

  static String etiqueta(String? estado) {
    switch (estado) {
      case enTransito:
        return 'En tránsito';
      case recibida:
        return 'Recibida';
      case cancelada:
        return 'Cancelada';
      case pendiente:
        return 'Pendiente';
      default:
        return 'Pendiente';
    }
  }
}

/// Transferencia junto con sus items.
class TransferenciaDetalle {
  final Transferencia transferencia;
  final List<TransferenciaItem> items;

  const TransferenciaDetalle({
    required this.transferencia,
    required this.items,
  });

  int get totalUnidades =>
      items.fold<int>(0, (s, i) => s + i.cantidad);
}

/// Resumen consolidado de una sucursal.
class ConsolidadoSucursal {
  final Sucursale sucursal;
  final int stockUnidades;
  final double valorInventario;
  final int productos;
  final int enviadas;
  final int recibidas;

  const ConsolidadoSucursal({
    required this.sucursal,
    required this.stockUnidades,
    required this.valorInventario,
    required this.productos,
    required this.enviadas,
    required this.recibidas,
  });
}

/// Dashboard consolidado de la empresa.
class Consolidado {
  final int totalSucursales;
  final int totalProductos;
  final int stockTotal;
  final double valorInventario;
  final double ventasTotales;
  final Map<String, double> ventasPorMetodo;
  final int enTransito;
  final List<ConsolidadoSucursal> porSucursal;

  const Consolidado({
    required this.totalSucursales,
    required this.totalProductos,
    required this.stockTotal,
    required this.valorInventario,
    required this.ventasTotales,
    required this.ventasPorMetodo,
    required this.enTransito,
    required this.porSucursal,
  });
}

/// Servicio central del Canal Moderno.
class CanalModernoService {
  CanalModernoService._();
  static final CanalModernoService instance = CanalModernoService._();

  final AppDatabase _db = LocalDatabaseService.instance.database;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  String? _empresaId;
  String? _usuarioId;

  void setContext({required String empresaId, String? usuarioId}) {
    _empresaId = empresaId;
    _usuarioId = usuarioId;
  }

  String get empresaId => _empresaId ?? 'ROOT';
  String get usuarioId => _usuarioId ?? '';

  // ═══════════════════════════════════════════════════════════════
  // SUCURSALES
  // ═══════════════════════════════════════════════════════════════

  Future<List<Sucursale>> getSucursales() async {
    return await (_db.select(_db.sucursales)
          ..where((s) => s.empresaId.equals(empresaId))
          ..orderBy([
            (s) => OrderingTerm.desc(s.esPrincipal),
            (s) => OrderingTerm.asc(s.nombre),
          ]))
        .get();
  }

  Future<Sucursale?> getSucursal(String id) async {
    final q = _db.select(_db.sucursales)..where((s) => s.id.equals(id));
    return await q.getSingleOrNull();
  }

  /// Nombre de bodega asociado a una sucursal.
  String bodegaDe(Sucursale s) =>
      (s.codigo?.trim().isNotEmpty == true) ? s.codigo!.trim() : s.nombre;

  Future<Sucursale> crearSucursal({
    required String nombre,
    String? codigo,
    String? direccion,
    String? telefono,
    String? encargado,
    bool esPrincipal = false,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final n = nombre.trim();
    final c = codigo?.trim().isNotEmpty == true
        ? codigo!.trim()
        : 'SUC-${id.substring(id.length - 6)}';

    final existentes = await getSucursales();
    final esPrincipalFinal = esPrincipal || existentes.isEmpty;

    if (esPrincipalFinal) {
      await (_db.update(_db.sucursales)..where((s) => s.empresaId.equals(empresaId)))
          .write(SucursalesCompanion(esPrincipal: const Value(false)));
    }

    await _db.into(_db.sucursales).insert(
      SucursalesCompanion.insert(
        id: id,
        empresaId: empresaId,
        codigo: Value(c),
        nombre: n,
        direccion: Value(direccion?.trim()),
        telefono: Value(telefono?.trim()),
        encargado: Value(encargado?.trim()),
        activo: const Value(true),
        esPrincipal: Value(esPrincipalFinal),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );

    final q = _db.select(_db.sucursales)..where((s) => s.id.equals(id));
    return await q.getSingle();
  }

  Future<void> actualizarSucursal({
    required String id,
    required String nombre,
    String? codigo,
    String? direccion,
    String? telefono,
    String? encargado,
    bool esPrincipal = false,
    bool activo = true,
  }) async {
    final actual = await getSucursal(id);
    if (actual == null) throw StateError('Sucursal no encontrada');

    if (esPrincipal && !actual.esPrincipal) {
      await (_db.update(_db.sucursales)..where((s) => s.empresaId.equals(empresaId)))
          .write(SucursalesCompanion(esPrincipal: const Value(false)));
    }

    await (_db.update(_db.sucursales)..where((s) => s.id.equals(id))).write(
      SucursalesCompanion(
        nombre: Value(nombre.trim()),
        codigo: Value(
          codigo?.trim().isNotEmpty == true ? codigo!.trim() : actual.codigo,
        ),
        direccion: Value(direccion?.trim()),
        telefono: Value(telefono?.trim()),
        encargado: Value(encargado?.trim()),
        esPrincipal: Value(esPrincipal || actual.esPrincipal),
        activo: Value(activo),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  Future<void> eliminarSucursal(String id) async {
    final activas = await (_db.select(_db.transferencias)
          ..where(
            (t) =>
                (t.origenId.equals(id) | t.destinoId.equals(id)) &
                (t.estado.equals(EstadoTransferencia.pendiente) |
                    t.estado.equals(EstadoTransferencia.enTransito)),
          ))
        .get();
    if (activas.isNotEmpty) {
      throw StateError(
        'La sucursal tiene transferencias activas. Completalas o cancelalas antes de eliminarla.',
      );
    }
    await (_db.delete(_db.sucursales)..where((s) => s.id.equals(id))).go();
  }

  // ═══════════════════════════════════════════════════════════════
  // TRANSFERENCIAS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Transferencia>> getTransferencias() async {
    return await (_db.select(_db.transferencias)
          ..where((t) => t.empresaId.equals(empresaId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<TransferenciaDetalle?> getTransferencia(String id) async {
    final q = _db.select(_db.transferencias)..where((t) => t.id.equals(id));
    final t = await q.getSingleOrNull();
    if (t == null) return null;

    final items = await (_db.select(_db.transferenciaItems)
          ..where((i) => i.transferenciaId.equals(id))
          ..orderBy([(i) => OrderingTerm.asc(i.productoNombre)]))
        .get();
    return TransferenciaDetalle(transferencia: t, items: items);
  }

  Future<String> _siguienteCorrelativo() async {
    final ahora = DateTime.now();
    final prefijo =
        'TR-${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-';
    final ultima = await (_db.select(_db.transferencias)
          ..where(
            (t) =>
                t.empresaId.equals(empresaId) &
                t.correlativo.like('$prefijo%'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.correlativo)])
          ..limit(1))
        .getSingleOrNull();
    int n = 1;
    if (ultima?.correlativo != null) {
      n = int.tryParse(ultima!.correlativo!.substring(prefijo.length)) ?? 1;
      n++;
    }
    return '$prefijo${n.toString().padLeft(4, '0')}';
  }

  /// Crea una transferencia en estado pendiente. `items` es una lista de
  /// pares (producto, cantidad).
  Future<Transferencia> crearTransferencia({
    required String origenId,
    required String destinoId,
    required List<(Producto, int)> items,
    String? observaciones,
  }) async {
    if (origenId == destinoId) {
      throw ArgumentError('Origen y destino deben ser distintos.');
    }
    if (items.isEmpty) {
      throw ArgumentError('Agregá al menos un producto a la transferencia.');
    }
    final origen = await getSucursal(origenId);
    final destino = await getSucursal(destinoId);
    if (origen == null || destino == null) {
      throw StateError('Sucursal de origen o destino no encontrada.');
    }

    final bodegaOrigen = bodegaDe(origen);
    for (final (p, cantidad) in items) {
      if (cantidad <= 0) {
        throw ArgumentError('Las cantidades deben ser mayores a cero.');
      }
      if (p.bodega != bodegaOrigen) {
        throw StateError(
          'El producto "${p.nombre}" no pertenece a la sucursal "${origen.nombre}".',
        );
      }
      if (p.stockActual < cantidad) {
        throw StateError(
          'Stock insuficiente de "${p.nombre}" en "${origen.nombre}" '
          '(disponible: ${p.stockActual}).',
        );
      }
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final correlativo = await _siguienteCorrelativo();
    await _db.into(_db.transferencias).insert(
      TransferenciasCompanion.insert(
        id: id,
        empresaId: empresaId,
        correlativo: Value(correlativo),
        origenId: origenId,
        origenNombre: origen.nombre,
        destinoId: destinoId,
        destinoNombre: destino.nombre,
        estado: const Value(EstadoTransferencia.pendiente),
        observaciones: Value(observaciones?.trim()),
        usuarioId: Value(usuarioId),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );

    for (final (p, cantidad) in items) {
      await _db.into(_db.transferenciaItems).insert(
        TransferenciaItemsCompanion.insert(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          transferenciaId: id,
          empresaId: empresaId,
          productoId: p.id,
          productoCodigo: Value(p.codigo),
          productoNombre: p.nombre,
          cantidad: cantidad,
          createdAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    }

    final q = _db.select(_db.transferencias)..where((t) => t.id.equals(id));
    return await q.getSingle();
  }

  /// Envía la transferencia: sale del inventario de la sucursal de origen.
  Future<void> enviarTransferencia(String id) async {
    final detalle = await getTransferencia(id);
    if (detalle == null) throw StateError('Transferencia no encontrada.');
    if (detalle.transferencia.estado != EstadoTransferencia.pendiente) {
      throw StateError('Solo se pueden enviar transferencias pendientes.');
    }

    final origen = await getSucursal(detalle.transferencia.origenId);
    if (origen == null) throw StateError('Sucursal de origen no encontrada.');
    final bodegaOrigen = bodegaDe(origen);

    await _db.transaction(() async {
      for (final item in detalle.items) {
        final q = _db.select(_db.productos)
          ..where(
            (p) =>
                p.id.equals(item.productoId) &
                p.empresaId.equals(empresaId),
          );
        final producto = await q.getSingleOrNull();
        if (producto == null) {
          throw StateError('Producto "${item.productoNombre}" no encontrado.');
        }
        if (producto.bodega != bodegaOrigen) {
          throw StateError(
            'El producto "${producto.nombre}" ya no está en la sucursal de origen.',
          );
        }
        if (producto.stockActual < item.cantidad) {
          throw StateError(
            'Stock insuficiente de "${producto.nombre}" '
            '(disponible: ${producto.stockActual}).',
          );
        }
        await (_db.update(_db.productos)..where((p) => p.id.equals(producto.id)))
            .write(
          ProductosCompanion(
            stockActual: Value(producto.stockActual - item.cantidad),
            updatedAt: Value(DateTime.now()),
            synced: const Value(false),
          ),
        );
      }
      await (_db.update(_db.transferencias)..where((t) => t.id.equals(id)))
          .write(
        TransferenciasCompanion(
          estado: const Value(EstadoTransferencia.enTransito),
          fechaEnvio: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    });
  }

  /// Recibe la transferencia: el inventario entra a la sucursal de destino.
  Future<void> recibirTransferencia(String id) async {
    final detalle = await getTransferencia(id);
    if (detalle == null) throw StateError('Transferencia no encontrada.');
    if (detalle.transferencia.estado != EstadoTransferencia.enTransito) {
      throw StateError('Solo se pueden recibir transferencias en tránsito.');
    }

    final destino = await getSucursal(detalle.transferencia.destinoId);
    if (destino == null) throw StateError('Sucursal de destino no encontrada.');
    final bodegaDestino = bodegaDe(destino);

    await _db.transaction(() async {
      for (final item in detalle.items) {
        await _incrementarStockEnBodega(
          productoId: item.productoId,
          codigo: item.productoCodigo,
          nombre: item.productoNombre,
          bodegaDestino: bodegaDestino,
          cantidad: item.cantidad,
        );
      }
      await (_db.update(_db.transferencias)..where((t) => t.id.equals(id)))
          .write(
        TransferenciasCompanion(
          estado: const Value(EstadoTransferencia.recibida),
          fechaRecepcion: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    });
  }

  /// Cancela la transferencia. Si ya estaba en tránsito, devuelve el stock
  /// a la sucursal de origen.
  Future<void> cancelarTransferencia(String id) async {
    final detalle = await getTransferencia(id);
    if (detalle == null) throw StateError('Transferencia no encontrada.');
    if (detalle.transferencia.estado == EstadoTransferencia.recibida) {
      throw StateError('Una transferencia recibida no se puede cancelar.');
    }
    if (detalle.transferencia.estado == EstadoTransferencia.cancelada) {
      return;
    }

    final estadoActual = detalle.transferencia.estado;
    final origen = await getSucursal(detalle.transferencia.origenId);
    final bodegaOrigen = origen != null ? bodegaDe(origen) : null;

    await _db.transaction(() async {
      if (estadoActual == EstadoTransferencia.enTransito &&
          bodegaOrigen != null) {
        for (final item in detalle.items) {
          final q = _db.select(_db.productos)
            ..where(
              (p) =>
                  p.id.equals(item.productoId) &
                  p.empresaId.equals(empresaId),
            );
          final producto = await q.getSingleOrNull();
          if (producto == null) continue;
          await (_db.update(_db.productos)
                ..where((p) => p.id.equals(producto.id)))
              .write(
            ProductosCompanion(
              stockActual: Value(producto.stockActual + item.cantidad),
              updatedAt: Value(DateTime.now()),
              synced: const Value(false),
            ),
          );
        }
      }
      await (_db.update(_db.transferencias)..where((t) => t.id.equals(id)))
          .write(
        TransferenciasCompanion(
          estado: const Value(EstadoTransferencia.cancelada),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    });
  }

  Future<void> _incrementarStockEnBodega({
    required String productoId,
    required String? codigo,
    required String nombre,
    required String bodegaDestino,
    required int cantidad,
  }) async {
    final existente = codigo != null && codigo.isNotEmpty
        ? await (_db.select(_db.productos)
              ..where(
                (p) =>
                    p.empresaId.equals(empresaId) &
                    p.codigo.equals(codigo) &
                    p.bodega.equals(bodegaDestino),
              ))
            .getSingleOrNull()
        : null;

    if (existente != null) {
      await (_db.update(_db.productos)
            ..where((p) => p.id.equals(existente.id)))
          .write(
        ProductosCompanion(
          stockActual: Value(existente.stockActual + cantidad),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
      return;
    }

    final origen = await (_db.select(_db.productos)
          ..where(
            (p) => p.id.equals(productoId) & p.empresaId.equals(empresaId),
          ))
        .getSingleOrNull();

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.productos).insert(
      ProductosCompanion.insert(
        id: id,
        empresaId: empresaId,
        codigo: Value(codigo),
        nombre: nombre,
        descripcion: Value(origen?.descripcion),
        categoria: Value(origen?.categoria),
        unidadMedida: Value(origen?.unidadMedida ?? 'Unidad'),
        precioCompra: Value(origen?.precioCompra ?? 0.0),
        precioVenta: Value(origen?.precioVenta ?? 0.0),
        stockMinimo: Value(origen?.stockMinimo ?? 0),
        stockActual: Value(cantidad),
        bodega: Value(bodegaDestino),
        isvRate: Value(origen?.isvRate ?? 15.0),
        exento: Value(origen?.exento ?? false),
        imagenUrl: Value(origen?.imagenUrl),
        activo: const Value(true),
        synced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONSOLIDADO
  // ═══════════════════════════════════════════════════════════════

  Future<Consolidado> getConsolidado() async {
    final sucursales = await getSucursales();
    final productos = await _localDb.getProductos(empresaId);
    final ventas = await (_db.select(_db.posVentas)
          ..where((v) => v.empresaId.equals(empresaId)))
        .get();
    final transferencias = await getTransferencias();

    final enTransito = transferencias
        .where((t) => t.estado == EstadoTransferencia.enTransito)
        .length;

    final ventasTotales =
        ventas.fold<double>(0, (s, v) => s + v.total);
    final ventasPorMetodo = <String, double>{};
    for (final v in ventas) {
      final m = v.metodoPago.isEmpty ? 'otro' : v.metodoPago;
      ventasPorMetodo[m] = (ventasPorMetodo[m] ?? 0) + v.total;
    }

    final porSucursal = <ConsolidadoSucursal>[];
    for (final s in sucursales) {
      final bodega = bodegaDe(s);
      final prods = productos.where((p) => p.bodega == bodega).toList();
      final stock = prods.fold<int>(0, (a, p) => a + p.stockActual);
      final valor = prods.fold<double>(
        0,
        (a, p) => a + (p.stockActual * p.precioCompra),
      );
      porSucursal.add(
        ConsolidadoSucursal(
          sucursal: s,
          stockUnidades: stock,
          valorInventario: valor,
          productos: prods.length,
          enviadas: transferencias
              .where((t) => t.origenId == s.id)
              .length,
          recibidas: transferencias
              .where((t) => t.destinoId == s.id)
              .length,
        ),
      );
    }

    return Consolidado(
      totalSucursales: sucursales.length,
      totalProductos: productos.length,
      stockTotal: productos.fold<int>(0, (a, p) => a + p.stockActual),
      valorInventario: productos.fold<double>(
        0,
        (a, p) => a + (p.stockActual * p.precioCompra),
      ),
      ventasTotales: ventasTotales,
      ventasPorMetodo: ventasPorMetodo,
      enTransito: enTransito,
      porSucursal: porSucursal,
    );
  }
}
