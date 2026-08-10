import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/canal_tradicional_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';

/// Servicio POS completo con offline-first, promociones, crédito, arqueo
class PosService {
  PosService._();
  static final PosService instance = PosService._();

  final AppDatabase _db = LocalDatabaseService.instance.database;
  final SyncService _syncService = SyncService.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  String? _currentEmpresaId;
  String? _currentTerminalId;
  String? _currentUsuarioId;

  // Configuración terminal
  int _decimales = 2;
  String _moneda = 'L';

  void setContext({
    required String empresaId,
    required String terminalId,
    required String usuarioId,
  }) {
    _currentEmpresaId = empresaId;
    _currentTerminalId = terminalId;
    _currentUsuarioId = usuarioId;
    CanalTradicionalService.instance.setContext(
      empresaId: empresaId,
      usuarioId: usuarioId,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VENTAS (offline-first)
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene correlativo siguiente para venta
  Future<String> getNextCorrelativo() async {
    final ahora = DateTime.now();
    final prefijo = 'POS-${ahora.year}${ahora.month.toString().padLeft(2, '0')}';
    
    final ultimaVenta = await (_db.select(_db.posVentas)
          ..where((v) => v.empresaId.equals(_currentEmpresaId!) & v.correlativo.like('$prefijo%'))
          ..orderBy([(v) => OrderingTerm.desc(v.correlativo)])
          ..limit(1))
        .getSingleOrNull();

    int siguiente = 1;
    if (ultimaVenta != null && ultimaVenta.correlativo != null) {
      final partes = ultimaVenta.correlativo!.split('-');
      if (partes.length >= 3) {
        siguiente = (int.tryParse(partes.last) ?? 0) + 1;
      }
    }

    return '$prefijo-${siguiente.toString().padLeft(6, '0')}';
  }

  /// Registra una venta completa (cabecera + items + descuento stock)
  Future<PosVenta?> registrarVenta({
    required List<PosVentaItemInput> items,
    required String metodoPago,
    String? clienteId,
    String? clienteNombre,
    String? clienteRtn,
    double descuentoGlobal = 0,
    String? notas,
    bool esCredito = false,
  }) async {
    if (_currentEmpresaId == null || _currentUsuarioId == null) {
      throw StateError('Contexto POS no inicializado');
    }

    final correlativo = await getNextCorrelativo();
    final ventaId = DateTime.now().microsecondsSinceEpoch.toString();
    final ahora = DateTime.now();

    // Calcular totales
    double subtotal = 0;
    double isv15 = 0;
    double isv18 = 0;

    for (final item in items) {
      final itemSubtotal = item.precioUnitario * item.cantidad - item.descuento;
      subtotal += itemSubtotal;
      
      if (item.isvRate >= 18) {
        isv18 += itemSubtotal * 0.18;
      } else {
        isv15 += itemSubtotal * 0.15;
      }
    }

    final total = subtotal - descuentoGlobal + isv15 + isv18;

    // Insertar cabecera
    final venta = PosVentasCompanion.insert(
      id: ventaId,
      empresaId: _currentEmpresaId!,
      usuarioId: Value(_currentUsuarioId!),
      terminalId: Value(_currentTerminalId!),
      correlativo: Value(correlativo),
      clienteId: Value(clienteId),
      clienteNombre: Value(clienteNombre),
      clienteRtn: Value(clienteRtn),
      subtotal: Value(subtotal),
      descuento: Value(descuentoGlobal),
      isv15: Value(isv15),
      isv18: Value(isv18),
      total: Value(total),
      metodoPago: Value(metodoPago),
      estado: Value(esCredito ? 'pendiente_pago' : 'completada'),
      notas: Value(notas),
      createdAt: Value(ahora),
      updatedAt: Value(ahora),
      synced: const Value(false),
    );

    await _db.into(_db.posVentas).insertOnConflictUpdate(venta);

    // Insertar items y descontar stock
    for (final item in items) {
      final itemId = '${ventaId}_${item.productoId}_${item.cantidad}';
      final itemSubtotal = item.precioUnitario * item.cantidad - item.descuento;

      final ventaItem = PosVentaItemsCompanion.insert(
        id: itemId,
        ventaId: ventaId,
        productoId: Value(item.productoId),
        productoCodigo: Value(item.codigo),
        productoNombre: item.nombre,
        precioUnitario: item.precioUnitario,
        cantidad: item.cantidad,
        descuento: Value(item.descuento),
        isvRate: Value(item.isvRate),
        subtotal: itemSubtotal,
        promocionAplicada: Value(item.promocionAplicada),
        createdAt: Value(ahora),
      );

      await _db.into(_db.posVentaItems).insertOnConflictUpdate(ventaItem);

      // Descontar stock local
      if (item.productoId.isNotEmpty) {
        await _descontarStockLocal(item.productoId, item.cantidad);
      }
    }

    // Si es crédito, actualizar cuenta cliente
    if (esCredito && clienteId != null) {
      await _actualizarCreditoCliente(
        clienteId,
        total,
        clienteNombre: clienteNombre,
      );
    }

    // Encolar sync
    await _syncService.enqueueSync(
      tabla: 'pos_ventas',
      operacion: SyncOperation.insert,
      datos: {
        'empresa_codigo': _currentEmpresaId!,
        'venta': {
          'id': ventaId,
          'correlativo': correlativo,
          'cliente_id': clienteId,
          'cliente_nombre': clienteNombre,
          'cliente_rtn': clienteRtn,
          'items': items.map((i) => {
            'producto_id': i.productoId,
            'codigo': i.codigo,
            'nombre': i.nombre,
            'cantidad': i.cantidad,
            'precio_unitario': i.precioUnitario,
            'descuento': i.descuento,
            'isv_rate': i.isvRate,
            'promocion': i.promocionAplicada,
          }).toList(),
          'subtotal': subtotal,
          'descuento': descuentoGlobal,
          'isv_15': isv15,
          'isv_18': isv18,
          'total': total,
          'metodo_pago': metodoPago,
          'estado': esCredito ? 'pendiente_pago' : 'completada',
          'notas': notas,
        },
      },
      empresaId: _currentEmpresaId!,
    );

    // Retornar venta creada
    return await getVentaById(ventaId);
  }

  Future<void> _descontarStockLocal(String productoId, int cantidad) async {
    final producto = await (_db.select(_db.productos)
          ..where((p) => p.id.equals(productoId)))
        .getSingleOrNull();
    
    if (producto != null) {
      final nuevoStock = (producto.stockActual - cantidad).clamp(0, 999999);
      await (_db.update(_db.productos)..where((p) => p.id.equals(productoId))).write(
        ProductosCompanion(
          stockActual: Value(nuevoStock),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    }
  }

  Future<void> _actualizarCreditoCliente(
    String clienteId,
    double monto, {
    String? clienteNombre,
  }) async {
    final credito = await (_db.select(_db.posClienteCredito)
          ..where((c) => c.empresaId.equals(_currentEmpresaId!) & c.clienteId.equals(clienteId)))
        .getSingleOrNull();

    if (credito != null) {
      await (_db.update(_db.posClienteCredito)
            ..where((c) => c.id.equals(credito.id)))
          .write(PosClienteCreditoCompanion(
        clienteNombre: Value(clienteNombre ?? credito.clienteNombre),
        saldoActual: Value(credito.saldoActual + monto),
        estado: const Value('activo'),
        fechaUltimaVenta: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ));
    } else {
      // Si el cliente no tiene cuenta de fiado, se crea automáticamente.
      await _db.into(_db.posClienteCredito).insert(
        PosClienteCreditoCompanion.insert(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          empresaId: _currentEmpresaId!,
          clienteId: clienteId,
          clienteNombre: Value(clienteNombre),
          limiteCredito: const Value(0),
          saldoActual: Value(monto),
          diasVencimiento: const Value(30),
          estado: const Value('activo'),
          fechaUltimaVenta: Value(DateTime.now()),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    }
  }

  Future<PosVenta?> getVentaById(String id) async {
    return await (_db.select(_db.posVentas)
          ..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<PosVenta>> getVentas({
    DateTime? desde,
    DateTime? hasta,
    String? estado,
    String? clienteId,
    int limit = 100,
  }) async {
    var query = _db.select(_db.posVentas)
      ..where((v) => v.empresaId.equals(_currentEmpresaId!))
      ..orderBy([(v) => OrderingTerm.desc(v.createdAt)])
      ..limit(limit);

    if (desde != null) {
      query = query..where((v) => v.createdAt.isBiggerOrEqualValue(desde));
    }
    if (hasta != null) {
      query = query..where((v) => v.createdAt.isSmallerOrEqualValue(hasta));
    }
    if (estado != null) {
      query = query..where((v) => v.estado.equals(estado));
    }
    if (clienteId != null) {
      query = query..where((v) => v.clienteId.equals(clienteId));
    }

    return await query.get();
  }

  Future<List<PosVentaItem>> getVentaItems(String ventaId) async {
    return await (_db.select(_db.posVentaItems)
          ..where((i) => i.ventaId.equals(ventaId)))
        .get();
  }

  // ═══════════════════════════════════════════════════════════════
  // PROMOCIONES ENGINE
  // ═══════════════════════════════════════════════════════════════

  /// Aplica promociones activas al carrito
  Future<List<PosCarritoItem>> aplicarPromociones(List<PosCarritoItem> carrito) async {
    final promociones = await _getPromocionesActivas();
    
    for (final promo in promociones) {
      carrito = _aplicarPromocion(carrito, promo);
    }
    
    return carrito;
  }

  Future<List<PosPromocione>> _getPromocionesActivas() async {
    final ahora = DateTime.now();
    return await (_db.select(_db.posPromociones)
          ..where((p) => p.empresaId.equals(_currentEmpresaId!) 
            & p.activo.equals(true)
            & (p.fechaInicio.isNull() | p.fechaInicio.isSmallerOrEqualValue(ahora))
            & (p.fechaFin.isNull() | p.fechaFin.isBiggerOrEqualValue(ahora)))
          ..orderBy([(p) => OrderingTerm.desc(p.prioridad)]))
        .get();
  }

  List<PosCarritoItem> _aplicarPromocion(List<PosCarritoItem> carrito, PosPromocione promo) {
    final config = promo.configuracion != null 
      ? jsonDecode(utf8.decode(promo.configuracion!)) as Map<String, dynamic>
      : {};

    switch (promo.tipo) {
      case '2x1':
        return _aplicar2x1(carrito, promo, config);
      case 'descuento_volumen':
        return _aplicarDescuentoVolumen(carrito, promo, config);
      case 'combo':
        return _aplicarCombo(carrito, promo, config);
      case 'descuento_porcentaje':
        return _aplicarDescuentoPorcentaje(carrito, promo, config);
      case 'precio_especial':
        return _aplicarPrecioEspecial(carrito, promo, config);
      default:
        return carrito;
    }
  }

  List<PosCarritoItem> _aplicar2x1(List<PosCarritoItem> carrito, PosPromocione promo, Map config) {
    final productosIds = config['productos'] as List<dynamic>? ?? [];
    final aplicaTodos = promo.aplicaTodosProductos;

    for (final item in carrito) {
      if (aplicaTodos || productosIds.contains(item.productoId)) {
        final pares = item.cantidad ~/ 2;
        if (pares > 0) {
          final descuento = pares * item.precioUnitario;
          item.descuento += descuento;
          item.promocionAplicada = promo.nombre;
        }
      }
    }
    return carrito;
  }

  List<PosCarritoItem> _aplicarDescuentoVolumen(List<PosCarritoItem> carrito, PosPromocione promo, Map config) {
    final reglas = config['reglas'] as List<dynamic>? ?? [];
    
    for (final item in carrito) {
      for (final regla in reglas) {
        final minCant = regla['min_cantidad'] as int? ?? 0;
        final descPct = regla['descuento_porcentaje'] as double? ?? 0;
        
        if (item.cantidad >= minCant) {
          final descuento = item.precioUnitario * item.cantidad * (descPct / 100);
          item.descuento = math.max(item.descuento, descuento);
          item.promocionAplicada = promo.nombre;
        }
      }
    }
    return carrito;
  }

  List<PosCarritoItem> _aplicarCombo(List<PosCarritoItem> carrito, PosPromocione promo, Map config) {
    final productosCombo = config['productos'] as List<dynamic>? ?? [];
    final precioCombo = config['precio_combo'] as double? ?? 0;
    
    // Verificar si todos los productos del combo están en el carrito
    final itemsCombo = carrito.where((i) => productosCombo.contains(i.productoId)).toList();
    if (itemsCombo.length == productosCombo.length) {
      final totalNormal = itemsCombo.fold<double>(0, (s, i) => s + i.precioUnitario * i.cantidad);
      final ahorro = totalNormal - precioCombo;
      
      if (ahorro > 0) {
        // Aplicar descuento distribuido
        for (final item in itemsCombo) {
          final proporcion = (item.precioUnitario * item.cantidad) / totalNormal;
          item.descuento += ahorro * proporcion;
          item.promocionAplicada = promo.nombre;
        }
      }
    }
    return carrito;
  }

  List<PosCarritoItem> _aplicarDescuentoPorcentaje(List<PosCarritoItem> carrito, PosPromocione promo, Map config) {
    final porcentaje = config['porcentaje'] as double? ?? 0;
    final productosIds = config['productos'] as List<dynamic>? ?? [];
    final aplicaTodos = promo.aplicaTodosProductos;

    for (final item in carrito) {
      if (aplicaTodos || productosIds.contains(item.productoId)) {
        final descuento = item.precioUnitario * item.cantidad * (porcentaje / 100);
        item.descuento += descuento;
        item.promocionAplicada = promo.nombre;
      }
    }
    return carrito;
  }

  List<PosCarritoItem> _aplicarPrecioEspecial(List<PosCarritoItem> carrito, PosPromocione promo, Map config) {
    final precios = config['precios'] as Map<String, dynamic>? ?? {};
    final aplicaTodos = promo.aplicaTodosProductos;

    for (final item in carrito) {
      if (aplicaTodos || precios.containsKey(item.productoId)) {
        final precioEspecial = (precios[item.productoId] as num?)?.toDouble();
        if (precioEspecial != null && precioEspecial < item.precioUnitario) {
          item.precioOriginal = item.precioUnitario;
          item.precioUnitario = precioEspecial;
          item.promocionAplicada = promo.nombre;
        }
      }
    }
    return carrito;
  }

  // ═══════════════════════════════════════════════════════════════
  // CRÉDITO CLIENTE
  // ═══════════════════════════════════════════════════════════════

  Future<PosClienteCreditoData?> getCreditoCliente(String clienteId) async {
    return await (_db.select(_db.posClienteCredito)
          ..where((c) => c.empresaId.equals(_currentEmpresaId!) & c.clienteId.equals(clienteId)))
        .getSingleOrNull();
  }

  Future<void> configurarCreditoCliente({
    required String clienteId,
    required double limiteCredito,
    int diasVencimiento = 30,
  }) async {
    final existing = await getCreditoCliente(clienteId);
    
    if (existing != null) {
      await (_db.update(_db.posClienteCredito)..where((c) => c.id.equals(existing.id))).write(
        PosClienteCreditoCompanion(
          limiteCredito: Value(limiteCredito),
          diasVencimiento: Value(diasVencimiento),
          estado: const Value('activo'),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    } else {
      await _db.into(_db.posClienteCredito).insert(
        PosClienteCreditoCompanion.insert(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          empresaId: _currentEmpresaId!,
          clienteId: clienteId,
          limiteCredito: Value(limiteCredito),
          diasVencimiento: Value(diasVencimiento),
          estado: const Value('activo'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    }
  }

  Future<void> registrarPagoCredito({
    required String clienteId,
    required double monto,
    required String metodoPago,
    String? referencia,
  }) async {
    // Delega al servicio de Canal Tradicional para dejar historial de abonos.
    await CanalTradicionalService.instance.registrarAbono(
      clienteId: clienteId,
      monto: monto,
      metodoPago: metodoPago,
      referencia: referencia,
      ventaId: null,
    );
  }

  Future<List<PosClienteCreditoData>> getClientesConCreditoVencido() async {
    // Simplificado: retorna todos con saldo > 0
    return await (_db.select(_db.posClienteCredito)
          ..where((c) => c.empresaId.equals(_currentEmpresaId!) & c.saldoActual.isBiggerThanValue(0)))
        .get();
  }

  // ═══════════════════════════════════════════════════════════════
  // ARQUEO DE CAJA
  // ═══════════════════════════════════════════════════════════════

  Future<PosArqueoCajaData?> getArqueoAbierto() async {
    return await (_db.select(_db.posArqueoCaja)
          ..where((a) => a.empresaId.equals(_currentEmpresaId!) 
            & a.terminalId.equals(_currentTerminalId!)
            & a.estado.equals('abierto'))
          ..orderBy([(a) => OrderingTerm.desc(a.fechaApertura)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<PosArqueoCajaData> abrirCaja({
    required double fondoInicial,
    Map<int, int>? denominacionesIniciales,
  }) async {
    final arqueoId = DateTime.now().microsecondsSinceEpoch.toString();
    final ahora = DateTime.now();

    final arqueo = PosArqueoCajaCompanion(
      id: Value(arqueoId),
      empresaId: Value(_currentEmpresaId!),
      usuarioId: Value(_currentUsuarioId!),
      terminalId: Value(_currentTerminalId!),
      fechaApertura: Value(ahora),
      fondoInicial: Value(fondoInicial),
      estado: const Value('abierto'),
      detalleDenominaciones: denominacionesIniciales != null
          ? Value(Uint8List.fromList(utf8.encode(jsonEncode(denominacionesIniciales))))
          : const Value.absent(),
      createdAt: Value(ahora),
      updatedAt: Value(ahora),
      synced: const Value(false),
    );

    await _db.into(_db.posArqueoCaja).insertOnConflictUpdate(arqueo);
    
    // Registrar entrada de fondo inicial
    await _registrarMovimientoCaja('entrada', 'Fondo inicial', fondoInicial, 'efectivo');
    
    return await getArqueoAbierto() as PosArqueoCajaData;
  }

  Future<void> cerrarCaja({
    required double conteoFisico,
    Map<int, int>? denominacionesFinales,
    String? observaciones,
  }) async {
    final arqueo = await getArqueoAbierto();
    if (arqueo == null) throw StateError('No hay caja abierta');

    // Calcular totales del sistema
    final ventas = await (_db.select(_db.posVentas)
          ..where((v) => v.empresaId.equals(_currentEmpresaId!) 
            & v.terminalId.equals(_currentTerminalId!)
            & v.createdAt.isBiggerOrEqualValue(arqueo.fechaApertura)
            & v.estado.equals('completada')))
        .get();

    double totalEfectivo = 0;
    double totalTarjeta = 0;
    double totalTransferencia = 0;
    double totalMixto = 0;

    for (final v in ventas) {
      switch (v.metodoPago) {
        case 'efectivo':
          totalEfectivo += v.total;
          break;
        case 'tarjeta':
          totalTarjeta += v.total;
          break;
        case 'transferencia':
          totalTransferencia += v.total;
          break;
        default:
          totalMixto += v.total;
      }
    }

    // Obtener gastos/entradas/salidas
    final transacciones = await (_db.select(_db.transacciones)
          ..where((t) => t.empresaId.equals(_currentEmpresaId!) 
            & t.fecha.isBiggerOrEqualValue(arqueo.fechaApertura)))
        .get();

    double totalGastos = 0;
    double totalEntradas = 0;
    double totalSalidas = 0;

    for (final t in transacciones) {
      if (t.tipo == 'gasto') totalGastos += t.monto;
      else if (t.tipo == 'ingreso' && t.categoria != 'Venta POS') totalEntradas += t.monto;
    }

    final sistemaTotal = arqueo.fondoInicial + totalEfectivo + totalEntradas - totalGastos - totalSalidas;
    final diferencia = conteoFisico - sistemaTotal;

    await (_db.update(_db.posArqueoCaja)..where((a) => a.id.equals(arqueo.id))).write(
      PosArqueoCajaCompanion(
        fechaCierre: Value(DateTime.now()),
        totalVentasEfectivo: Value(totalEfectivo),
        totalVentasTarjeta: Value(totalTarjeta),
        totalVentasTransferencia: Value(totalTransferencia),
        totalVentasMixto: Value(totalMixto),
        totalGastos: Value(totalGastos),
        totalEntradas: Value(totalEntradas),
        totalSalidas: Value(totalSalidas),
        sistemaTotal: Value(sistemaTotal),
        conteoFisico: Value(conteoFisico),
        diferencia: Value(diferencia),
        observaciones: Value(observaciones),
        estado: const Value('cerrado'),
        detalleDenominaciones: denominacionesFinales != null
            ? Value(Uint8List.fromList(utf8.encode(jsonEncode(denominacionesFinales))))
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  Future<void> _registrarMovimientoCaja(String tipo, String descripcion, double monto, String metodoPago) async {
    await _localDb.insertTransaccionLocal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      empresaId: _currentEmpresaId!,
      tipo: tipo,
      categoria: descripcion,
      descripcion: descripcion,
      monto: monto,
      metodoPago: metodoPago,
      fecha: DateTime.now(),
    );
  }

  Future<void> registrarGastoCaja({
    required String descripcion,
    required double monto,
    String? metodoPago,
  }) async {
    await _registrarMovimientoCaja('gasto', descripcion, monto, metodoPago ?? 'efectivo');
  }

  Future<void> registrarEntradaCaja({
    required String descripcion,
    required double monto,
  }) async {
    await _registrarMovimientoCaja('entrada', descripcion, monto, 'efectivo');
  }

  // ═══════════════════════════════════════════════════════════════
  // REPORTES
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getReporteZ() async {
    final arqueo = await getArqueoAbierto();
    final inicio = arqueo?.fechaApertura ?? DateTime.now().subtract(const Duration(days: 1));
    
    final ventas = await (_db.select(_db.posVentas)
          ..where((v) => v.empresaId.equals(_currentEmpresaId!) 
            & v.createdAt.isBiggerOrEqualValue(inicio)
            & v.estado.equals('completada')))
        .get();

    final items = await (_db.select(_db.posVentaItems)
          ..where((i) => i.ventaId.isIn(ventas.map((v) => v.id).toList())))
        .get();

    double totalVentas = 0;
    double totalEfectivo = 0;
    double totalTarjeta = 0;
    double totalTransferencia = 0;
    int totalItems = 0;
    int totalTransacciones = ventas.length;

    Map<String, int> itemsPorProducto = {};

    for (final v in ventas) {
      totalVentas += v.total;
      totalItems += v.total > 0 ? 1 : 0;
      
      switch (v.metodoPago) {
        case 'efectivo':
          totalEfectivo += v.total;
          break;
        case 'tarjeta':
          totalTarjeta += v.total;
          break;
        case 'transferencia':
          totalTransferencia += v.total;
          break;
      }
    }

    for (final item in items) {
      itemsPorProducto[item.productoNombre] = (itemsPorProducto[item.productoNombre] ?? 0) + item.cantidad;
    }

    return {
      'periodo': '${_formatDate(inicio)} - ${_formatDate(DateTime.now())}',
      'total_ventas': totalVentas,
      'total_transacciones': totalTransacciones,
      'total_items': itemsPorProducto.values.fold(0, (a, b) => a + b),
      'efectivo': totalEfectivo,
      'tarjeta': totalTarjeta,
      'transferencia': totalTransferencia,
      'promedio_ticket': totalTransacciones > 0 ? totalVentas / totalTransacciones : 0,
      'top_productos': itemsPorProducto.entries
          .map((e) => {'producto': e.key, 'cantidad': e.value})
          .toList()
        ..sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int))
        ..take(10)
        .toList(),
      'arqueo': arqueo != null ? {
        'fondo_inicial': arqueo.fondoInicial,
        'sistema_total': arqueo.sistemaTotal,
        'conteo_fisico': arqueo.conteoFisico,
        'diferencia': arqueo.diferencia,
      } : null,
    };
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════

  String formatCurrency(double value) => 
    '$_moneda ${value.toStringAsFixed(_decimales).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

// Modelos auxiliares
class PosVentaItemInput {
  final String productoId;
  final String codigo;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double descuento;
  final double isvRate;
  final String? promocionAplicada;

  PosVentaItemInput({
    required this.productoId,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.descuento = 0,
    this.isvRate = 15,
    this.promocionAplicada,
  });
}

class PosCarritoItem {
  final String productoId;
  final String codigo;
  final String nombre;
  int cantidad;
  double precioUnitario;
  double precioOriginal;
  double descuento;
  double isvRate;
  String? promocionAplicada;

  PosCarritoItem({
    required this.productoId,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.precioOriginal = 0,
    this.descuento = 0,
    this.isvRate = 15,
    this.promocionAplicada,
  });

  PosCarritoItem copyWith({
    int? cantidad,
    double? descuento,
    String? promocionAplicada,
    double? precioUnitario,
  }) {
    return PosCarritoItem(
      productoId: productoId,
      codigo: codigo,
      nombre: nombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      precioOriginal: precioOriginal,
      descuento: descuento ?? this.descuento,
      isvRate: isvRate,
      promocionAplicada: promocionAplicada ?? this.promocionAplicada,
    );
  }

  double get subtotal => precioUnitario * cantidad - descuento;
}