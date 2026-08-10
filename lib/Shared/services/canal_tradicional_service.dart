// lib/Shared/services/canal_tradicional_service.dart
// Motor del Canal Tradicional (Paso 5):
//  - Fiado / cuentas por cobrar: límite de crédito, saldo, vencimientos,
//    abonos con historial y alertas de cuentas vencidas.
//  - Rutas de reparto/visita: CRUD de rutas y asignación de clientes.
//  - Régimen fiscal: helpers del Régimen Simplificado (RST) que emite
//    Comprobantes Fiscales (CF) sin CAI.

import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';

/// Regímenes fiscales soportados por la SAR.
class SarRegimen {
  static const String general = 'general';
  static const String simplificado = 'simplificado';

  static bool esSimplificado(String? regimen) => regimen == simplificado;

  static String etiqueta(String? regimen) {
    switch (regimen) {
      case simplificado:
        return 'Régimen Simplificado';
      case general:
        return 'Régimen General';
      default:
        return 'Régimen General';
    }
  }

  static List<String> get opciones => [general, simplificado];
}

/// Estado calculado de una cuenta por cobrar según saldo y vencimiento.
class EstadoFiado {
  static const String alDia = 'al_dia';
  static const String porVencer = 'por_vencer';
  static const String vencido = 'vencido';

  /// Calcula el estado a partir de la última actividad de la cuenta.
  /// vencido: la fecha de vencimiento ya pasó y hay saldo pendiente.
  /// por_vencer: quedan 5 días o menos para vencer.
  static String calcular({
    required double saldo,
    required DateTime? ultimaActividad,
    required int diasVencimiento,
    required DateTime ahora,
  }) {
    if (saldo <= 0) return alDia;
    final base = ultimaActividad ?? DateTime(2020);
    final vence = base.add(Duration(days: diasVencimiento));
    final restante = vence.difference(ahora).inDays;
    if (restante < 0) return vencido;
    if (restante <= 5) return porVencer;
    return alDia;
  }

  static String etiqueta(String estado) {
    switch (estado) {
      case porVencer:
        return 'Por vencer';
      case vencido:
        return 'Vencido';
      default:
        return 'Al día';
    }
  }
}

/// Frecuencias de visita de una ruta.
class RutaFrecuencia {
  static const String semanal = 'semanal';
  static const String quincenal = 'quincenal';
  static const String mensual = 'mensual';

  static const List<String> opciones = [semanal, quincenal, mensual];

  static String etiqueta(String? frecuencia) {
    switch (frecuencia) {
      case quincenal:
        return 'Quincenal';
      case mensual:
        return 'Mensual';
      case semanal:
        return 'Semanal';
      default:
        return 'Semanal';
    }
  }

  static const List<String> diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static String diaEtiqueta(int? dia) {
    if (dia == null || dia < 0 || dia >= diasSemana.length) {
      return 'Sin día fijo';
    }
    return diasSemana[dia];
  }
}

/// Cuenta por cobrar lista para mostrar en la UI.
class FiadoCuenta {
  final PosClienteCreditoData credito;
  final String estado;

  const FiadoCuenta({required this.credito, required this.estado});

  String get nombre =>
      credito.clienteNombre?.trim().isNotEmpty == true
          ? credito.clienteNombre!.trim()
          : credito.clienteId;

  double get saldo => credito.saldoActual;
  double get limite => credito.limiteCredito;
  int get diasVencimiento => credito.diasVencimiento;
}

/// Ruta con el conteo de clientes asignados.
class RutaInfo {
  final Ruta ruta;
  final int clienteCount;

  const RutaInfo({required this.ruta, required this.clienteCount});
}

/// Servicio central del Canal Tradicional.
class CanalTradicionalService {
  CanalTradicionalService._();
  static final CanalTradicionalService instance = CanalTradicionalService._();

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
  // CUENTAS POR COBRAR (FIADO)
  // ═══════════════════════════════════════════════════════════════

  Future<PosClienteCreditoData?> getCuentaFiado(String clienteId) async {
    return await (_db.select(_db.posClienteCredito)
          ..where(
            (c) =>
                c.empresaId.equals(empresaId) &
                c.clienteId.equals(clienteId),
          ))
        .getSingleOrNull();
  }

  Future<PosClienteCreditoData> asegurarCuentaFiado({
    required String clienteId,
    String? clienteNombre,
    double limiteCredito = 0,
    int diasVencimiento = 30,
  }) async {
    final existente = await getCuentaFiado(clienteId);
    if (existente != null) return existente;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.posClienteCredito).insert(
      PosClienteCreditoCompanion.insert(
        id: id,
        empresaId: empresaId,
        clienteId: clienteId,
        clienteNombre: Value(clienteNombre),
        limiteCredito: Value(limiteCredito),
        saldoActual: const Value(0),
        diasVencimiento: Value(diasVencimiento),
        estado: const Value('al_dia'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    return (await getCuentaFiado(clienteId))!;
  }

  Future<void> configurarCuentaFiado({
    required String clienteId,
    String? clienteNombre,
    required double limiteCredito,
    int diasVencimiento = 30,
    String? notas,
  }) async {
    final existente = await getCuentaFiado(clienteId);

    if (existente != null) {
      await (_db.update(_db.posClienteCredito)
            ..where((c) => c.id.equals(existente.id)))
          .write(
            PosClienteCreditoCompanion(
              clienteNombre: Value(clienteNombre ?? existente.clienteNombre),
              limiteCredito: Value(limiteCredito),
              diasVencimiento: Value(diasVencimiento),
              estado: Value(existente.saldoActual > 0 ? 'activo' : 'al_dia'),
              notas: Value(notas),
              updatedAt: Value(DateTime.now()),
              synced: const Value(false),
            ),
          );
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.posClienteCredito).insert(
      PosClienteCreditoCompanion.insert(
        id: id,
        empresaId: empresaId,
        clienteId: clienteId,
        clienteNombre: Value(clienteNombre),
        limiteCredito: Value(limiteCredito),
        saldoActual: const Value(0),
        diasVencimiento: Value(diasVencimiento),
        estado: const Value('al_dia'),
        notas: Value(notas),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  /// Registra una venta al crédito (incrementa el saldo de la cuenta).
  Future<void> cargarVentaACuenta({
    required String clienteId,
    String? clienteNombre,
    required double monto,
    String? ventaId,
    String? facturaId,
  }) async {
    final cuenta = await asegurarCuentaFiado(
      clienteId: clienteId,
      clienteNombre: clienteNombre,
    );
    await (_db.update(_db.posClienteCredito)
          ..where((c) => c.id.equals(cuenta.id)))
        .write(
          PosClienteCreditoCompanion(
            clienteNombre: Value(clienteNombre ?? cuenta.clienteNombre),
            saldoActual: Value(cuenta.saldoActual + monto),
            estado: const Value('activo'),
            fechaUltimaVenta: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
            synced: const Value(false),
          ),
        );
  }

  /// Valida si una venta al crédito supera el límite configurado.
  /// Devuelve null si la venta es permitida.
  Future<String?> validarLimiteCredito({
    required String clienteId,
    required double monto,
  }) async {
    final cuenta = await getCuentaFiado(clienteId);
    if (cuenta == null) return null;
    if (cuenta.limiteCredito <= 0) return null;

    final proyectado = cuenta.saldoActual + monto;
    if (proyectado > cuenta.limiteCredito) {
      final exceso = proyectado - cuenta.limiteCredito;
      return 'Supera el límite de crédito del cliente '
          '(L.${_fmt(cuenta.limiteCredito)}). Exceso de L.${_fmt(exceso)}. '
          'Actualizá el límite en Fiado para continuar.';
    }
    return null;
  }

  /// Registra un abono contra la cuenta por cobrar y deja historial.
  Future<void> registrarAbono({
    required String clienteId,
    String? clienteNombre,
    required double monto,
    String metodoPago = 'efectivo',
    String? referencia,
    String? notas,
    String? ventaId,
    String? facturaId,
  }) async {
    if (monto <= 0) {
      throw ArgumentError('El monto del abono debe ser mayor a cero.');
    }
    final cuenta = await getCuentaFiado(clienteId);
    if (cuenta == null) {
      throw StateError('El cliente no tiene cuenta de fiado configurada.');
    }

    final abono = math.min(monto, cuenta.saldoActual);
    final nuevoSaldo = (cuenta.saldoActual - abono).clamp(
      0,
      double.infinity,
    ).toDouble();

    await (_db.update(_db.posClienteCredito)
          ..where((c) => c.id.equals(cuenta.id)))
        .write(
          PosClienteCreditoCompanion(
            saldoActual: Value(nuevoSaldo),
            fechaUltimoPago: Value(DateTime.now()),
            montoUltimoPago: Value(abono),
            estado: Value(nuevoSaldo == 0 ? 'al_dia' : 'activo'),
            updatedAt: Value(DateTime.now()),
            synced: const Value(false),
          ),
        );

    final fecha = DateTime.now();
    await _db.into(_db.fiadoAbonos).insert(
      FiadoAbonosCompanion.insert(
        id: fecha.microsecondsSinceEpoch.toString(),
        empresaId: empresaId,
        clienteId: clienteId,
        clienteNombre: Value(clienteNombre ?? cuenta.clienteNombre),
        ventaId: Value(ventaId),
        facturaId: Value(facturaId),
        monto: abono,
        metodoPago: Value(metodoPago),
        referencia: Value(referencia),
        notas: Value(notas),
        usuarioId: Value(usuarioId),
        fecha: Value(fecha),
        synced: const Value(false),
      ),
    );

    await _localDb.insertTransaccionLocal(
      id: fecha.microsecondsSinceEpoch.toString(),
      empresaId: empresaId,
      tipo: 'ingreso',
      categoria: 'Abono a cuenta por cobrar',
      descripcion: 'Abono ${clienteNombre ?? clienteId} - $metodoPago',
      monto: abono,
      metodoPago: metodoPago,
      referencia: referencia,
      fecha: fecha,
    );
  }

  /// Lista las cuentas por cobrar (por defecto solo las que tienen saldo).
  Future<List<FiadoCuenta>> getCuentasFiado({bool soloConSaldo = true}) async {
    final ahora = DateTime.now();
    final query = _db.select(_db.posClienteCredito)
      ..where((c) => c.empresaId.equals(empresaId));
    if (soloConSaldo) {
      query.where((c) => c.saldoActual.isBiggerThanValue(0));
    }
    query.orderBy([(c) => OrderingTerm.desc(c.saldoActual)]);
    final rows = await query.get();

    return rows.map((r) {
      final ultima =
          r.fechaUltimaVenta ?? r.fechaUltimoPago ?? r.createdAt;
      return FiadoCuenta(
        credito: r,
        estado: EstadoFiado.calcular(
          saldo: r.saldoActual,
          ultimaActividad: ultima,
          diasVencimiento: r.diasVencimiento,
          ahora: ahora,
        ),
      );
    }).toList();
  }

  Future<List<PosClienteCreditoData>> getClientesConCreditoVencido() async {
    final cuentas = await getCuentasFiado(soloConSaldo: true);
    return cuentas
        .where((c) => c.estado == EstadoFiado.vencido)
        .map((c) => c.credito)
        .toList();
  }

  Future<List<FiadoAbono>> getAbonosCliente(String clienteId) async {
    final query = _db.select(_db.fiadoAbonos)
      ..where(
        (a) => a.empresaId.equals(empresaId) & a.clienteId.equals(clienteId),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.fecha)]);
    return await query.get();
  }

  // ═══════════════════════════════════════════════════════════════
  // RUTAS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Cliente>> getClientes() async {
    return await _localDb.getClientes(empresaId);
  }

  Future<Ruta> crearRuta({
    required String nombre,
    String? vendedor,
    String frecuencia = RutaFrecuencia.semanal,
    int? diaSemana,
    String? descripcion,
    bool activo = true,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.rutas).insert(
      RutasCompanion.insert(
        id: id,
        empresaId: empresaId,
        nombre: nombre.trim(),
        vendedor: Value(vendedor?.trim()),
        frecuencia: Value(frecuencia),
        diaSemana: Value(diaSemana),
        descripcion: Value(descripcion),
        activo: Value(activo),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    final q = _db.select(_db.rutas)..where((r) => r.id.equals(id));
    return await q.getSingle();
  }

  Future<void> actualizarRuta({
    required String id,
    required String nombre,
    String? vendedor,
    String frecuencia = RutaFrecuencia.semanal,
    int? diaSemana,
    String? descripcion,
    bool activo = true,
  }) async {
    await (_db.update(_db.rutas)..where((r) => r.id.equals(id))).write(
      RutasCompanion(
        nombre: Value(nombre.trim()),
        vendedor: Value(vendedor?.trim()),
        frecuencia: Value(frecuencia),
        diaSemana: Value(diaSemana),
        descripcion: Value(descripcion),
        activo: Value(activo),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  Future<void> eliminarRuta(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.rutaClientes)
            ..where((rc) => rc.rutaId.equals(id)))
          .go();
      await (_db.delete(_db.rutas)..where((r) => r.id.equals(id))).go();
    });
  }

  Future<List<RutaInfo>> getRutas() async {
    final rutas = await (_db.select(_db.rutas)
          ..where((r) => r.empresaId.equals(empresaId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();

    final resultado = <RutaInfo>[];
    for (final r in rutas) {
      final clientes = await (_db.select(_db.rutaClientes)
            ..where(
              (rc) => rc.rutaId.equals(r.id) & rc.activo.equals(true),
            ))
          .get();
      resultado.add(RutaInfo(ruta: r, clienteCount: clientes.length));
    }
    return resultado;
  }

  Future<Ruta?> getRuta(String id) async {
    final q = _db.select(_db.rutas)..where((r) => r.id.equals(id));
    return await q.getSingleOrNull();
  }

  Future<List<RutaCliente>> getClientesRuta(String rutaId) async {
    return await (_db.select(_db.rutaClientes)
          ..where((rc) => rc.rutaId.equals(rutaId) & rc.activo.equals(true))
          ..orderBy([(rc) => OrderingTerm.asc(rc.orden)]))
        .get();
  }

  /// Reemplaza la asignación de clientes de una ruta.
  Future<void> asignarClientesRuta({
    required String rutaId,
    required List<String> clienteIds,
    Map<String, String>? nombresPorId,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.rutaClientes)
            ..where((rc) => rc.rutaId.equals(rutaId)))
          .go();
      for (var i = 0; i < clienteIds.length; i++) {
        final id = clienteIds[i];
        await _db.into(_db.rutaClientes).insert(
          RutaClientesCompanion.insert(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            rutaId: rutaId,
            empresaId: empresaId,
            clienteId: id,
            clienteNombre: Value(nombresPorId?[id]),
            orden: Value(i),
            activo: const Value(true),
            createdAt: Value(DateTime.now()),
            synced: const Value(false),
          ),
        );
      }
    });
  }

  Future<List<Cliente>> getClientesSinRuta() async {
    final asignados = await (_db.select(_db.rutaClientes)
          ..where((rc) => rc.empresaId.equals(empresaId)))
        .get();
    final idsAsignados = asignados.map((a) => a.clienteId).toSet();
    final clientes = await getClientes();
    return clientes.where((c) => !idsAsignados.contains(c.id)).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // RÉGIMEN FISCAL
  // ═══════════════════════════════════════════════════════════════

  Future<String> getRegimenFiscal() async {
    final config = await SarService.instance.getConfiguracion();
    return config?.regimen ?? SarRegimen.general;
  }

  static String _fmt(double v) => v.toStringAsFixed(2);
}
