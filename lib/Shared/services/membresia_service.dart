// lib/Shared/services/membresia_service.dart
// Motor de Membresías (Paso 7):
//  - Planes (Membresias): precio, descuento preferencial y vigencia en meses.
//  - Socios: catálogo de miembros del programa.
//  - Afiliaciones (SocioMembresias): vigencias con ciclo
//    activa -> vencida | cancelada, más renovaciones.
//  - Precios preferenciales (SocioPrecios): precio especial por producto
//    asignado a un socio; si no existe, se aplica el descuento del plan.

import 'package:drift/drift.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

/// Estados del ciclo de una afiliación (vigencia).
class EstadoAfiliacion {
  static const String activa = 'activa';
  static const String vencida = 'vencida';
  static const String cancelada = 'cancelada';

  static String etiqueta(String estado) {
    switch (estado) {
      case vencida:
        return 'Vencida';
      case cancelada:
        return 'Cancelada';
      default:
        return 'Activa';
    }
  }
}

/// Un socio junto con su afiliación vigente (si existe).
class SocioFila {
  final Socio socio;
  final SocioMembresia? afiliacionActiva;

  const SocioFila({required this.socio, this.afiliacionActiva});
}

/// Detalle completo de un socio: afiliaciones y precios preferenciales.
class SocioDetalle {
  final Socio socio;
  final List<SocioMembresia> afiliaciones;
  final List<SocioPrecio> precios;

  const SocioDetalle({
    required this.socio,
    required this.afiliaciones,
    required this.precios,
  });

  SocioMembresia? get afiliacionVigente {
    for (final a in afiliaciones) {
      if (a.estado == EstadoAfiliacion.activa &&
          !a.fechaFin.isBefore(DateTime.now())) {
        return a;
      }
    }
    return null;
  }
}

/// Resumen del programa de membresías.
class DashboardMembresias {
  final int totalSocios;
  final int sociosActivos;
  final int sociosVencidos;
  final int planesActivos;
  final int porVencer;
  final double ingresoMembresias;

  const DashboardMembresias({
    required this.totalSocios,
    required this.sociosActivos,
    required this.sociosVencidos,
    required this.planesActivos,
    required this.porVencer,
    required this.ingresoMembresias,
  });
}

/// Servicio central de Membresías.
class MembresiaService {
  MembresiaService._();
  static final MembresiaService instance = MembresiaService._();

  final AppDatabase _db = LocalDatabaseService.instance.database;

  String? _empresaId;
  String? _usuarioId;

  void setContext({required String empresaId, String? usuarioId}) {
    _empresaId = empresaId;
    _usuarioId = usuarioId;
  }

  String get empresaId => _empresaId ?? 'ROOT';
  String get usuarioId => _usuarioId ?? '';

  // ═══════════════════════════════════════════════════════════════
  // MEMBRESÍAS (PLANES)
  // ═══════════════════════════════════════════════════════════════

  Future<List<Membresia>> getMembresias() async {
    return await (_db.select(_db.membresias)
          ..where((m) => m.empresaId.equals(empresaId))
          ..orderBy([(m) => OrderingTerm.asc(m.nombre)]))
        .get();
  }

  Future<Membresia?> getMembresia(String id) async {
    final q = _db.select(_db.membresias)..where((m) => m.id.equals(id));
    return await q.getSingleOrNull();
  }

  Future<Membresia> crearMembresia({
    required String nombre,
    String? descripcion,
    double precio = 0,
    double descuentoPorcentaje = 0,
    int vigenciaMeses = 1,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.membresias).insert(
      MembresiasCompanion.insert(
        id: id,
        empresaId: empresaId,
        nombre: nombre.trim(),
        descripcion: Value(descripcion?.trim()),
        precio: Value(precio),
        descuentoPorcentaje: Value(descuentoPorcentaje),
        vigenciaMeses: Value(vigenciaMeses),
        activo: const Value(true),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    final q = _db.select(_db.membresias)..where((m) => m.id.equals(id));
    return await q.getSingle();
  }

  Future<void> actualizarMembresia({
    required String id,
    required String nombre,
    String? descripcion,
    double precio = 0,
    double descuentoPorcentaje = 0,
    int vigenciaMeses = 1,
    bool activo = true,
  }) async {
    await (_db.update(_db.membresias)..where((m) => m.id.equals(id))).write(
      MembresiasCompanion(
        nombre: Value(nombre.trim()),
        descripcion: Value(descripcion?.trim()),
        precio: Value(precio),
        descuentoPorcentaje: Value(descuentoPorcentaje),
        vigenciaMeses: Value(vigenciaMeses),
        activo: Value(activo),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  Future<void> eliminarMembresia(String id) async {
    final usadas = await (_db.select(_db.socioMembresias)
          ..where((a) => a.membresiaId.equals(id) & a.empresaId.equals(empresaId)))
        .get();
    if (usadas.isNotEmpty) {
      throw StateError(
        'El plan tiene socios afiliados. No se puede eliminar; desactívalo en su lugar.',
      );
    }
    await (_db.delete(_db.membresias)..where((m) => m.id.equals(id))).go();
  }

  // ═══════════════════════════════════════════════════════════════
  // SOCIOS
  // ═══════════════════════════════════════════════════════════════

  Future<List<Socio>> getSocios() async {
    return await (_db.select(_db.socios)
          ..where((s) => s.empresaId.equals(empresaId))
          ..orderBy([(s) => OrderingTerm.asc(s.nombre)]))
        .get();
  }

  Future<Socio?> getSocio(String id) async {
    final q = _db.select(_db.socios)..where((s) => s.id.equals(id));
    return await q.getSingleOrNull();
  }

  Future<Socio> crearSocio({
    required String nombre,
    String? telefono,
    String? email,
    String? documento,
    String? direccion,
    String? notas,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.socios).insert(
      SociosCompanion.insert(
        id: id,
        empresaId: empresaId,
        nombre: nombre.trim(),
        telefono: Value(telefono?.trim()),
        email: Value(email?.trim()),
        documento: Value(documento?.trim()),
        direccion: Value(direccion?.trim()),
        notas: Value(notas?.trim()),
        activo: const Value(true),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    final q = _db.select(_db.socios)..where((s) => s.id.equals(id));
    return await q.getSingle();
  }

  Future<void> actualizarSocio({
    required String id,
    required String nombre,
    String? telefono,
    String? email,
    String? documento,
    String? direccion,
    String? notas,
    bool activo = true,
  }) async {
    await (_db.update(_db.socios)..where((s) => s.id.equals(id))).write(
      SociosCompanion(
        nombre: Value(nombre.trim()),
        telefono: Value(telefono?.trim()),
        email: Value(email?.trim()),
        documento: Value(documento?.trim()),
        direccion: Value(direccion?.trim()),
        notas: Value(notas?.trim()),
        activo: Value(activo),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  Future<void> eliminarSocio(String id) async {
    final activas = await (_db.select(_db.socioMembresias)
          ..where(
            (a) => a.socioId.equals(id) &
                a.empresaId.equals(empresaId) &
                a.estado.equals(EstadoAfiliacion.activa),
          ))
        .get();
    if (activas.isNotEmpty) {
      throw StateError(
        'El socio tiene una membresía activa. Cancelala antes de eliminar.',
      );
    }
    await (_db.delete(_db.socioPrecios)
          ..where((p) => p.socioId.equals(id) & p.empresaId.equals(empresaId)))
        .go();
    await (_db.delete(_db.socios)..where((s) => s.id.equals(id))).go();
  }

  /// Socios con su membresía vigente (para la lista principal).
  Future<List<SocioFila>> getSociosFila() async {
    await _marcarVencidas();
    final socios = await getSocios();
    final afiliaciones = await getAfiliaciones();
    final filas = <SocioFila>[];
    for (final s in socios) {
      final delSocio = afiliaciones.where((a) => a.socioId == s.id).toList()
        ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      SocioMembresia? activa;
      for (final a in delSocio) {
        if (estadoEfectivo(a) == EstadoAfiliacion.activa) {
          activa = a;
          break;
        }
      }
      filas.add(SocioFila(socio: s, afiliacionActiva: activa));
    }
    return filas;
  }

  Future<SocioDetalle?> getSocioDetalle(String socioId) async {
    await _marcarVencidas();
    final socio = await getSocio(socioId);
    if (socio == null) return null;
    final afiliaciones = await (_db.select(_db.socioMembresias)
          ..where(
            (a) => a.socioId.equals(socioId) & a.empresaId.equals(empresaId),
          )
          ..orderBy([(a) => OrderingTerm.desc(a.fechaInicio)]))
        .get();
    final precios = await (_db.select(_db.socioPrecios)
          ..where(
            (p) => p.socioId.equals(socioId) & p.empresaId.equals(empresaId),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.productoNombre)]))
        .get();
    return SocioDetalle(
      socio: socio,
      afiliaciones: afiliaciones,
      precios: precios,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AFILIACIONES / VIGENCIAS
  // ═══════════════════════════════════════════════════════════════

  Future<List<SocioMembresia>> getAfiliaciones() async {
    return await (_db.select(_db.socioMembresias)
          ..where((a) => a.empresaId.equals(empresaId))
          ..orderBy([(a) => OrderingTerm.desc(a.fechaInicio)]))
        .get();
  }

  /// Estado considerando la fecha de vencimiento.
  String estadoEfectivo(SocioMembresia a) {
    if (a.estado == EstadoAfiliacion.activa &&
        a.fechaFin.isBefore(DateTime.now())) {
      return EstadoAfiliacion.vencida;
    }
    return a.estado;
  }

  Future<void> _marcarVencidas() async {
    await (_db.update(_db.socioMembresias)
          ..where(
            (a) =>
                a.empresaId.equals(empresaId) &
                a.estado.equals(EstadoAfiliacion.activa) &
                a.fechaFin.isSmallerThanValue(DateTime.now()),
          ))
        .write(
      SocioMembresiasCompanion(
        estado: const Value(EstadoAfiliacion.vencida),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  /// Asigna un plan a un socio. `fechaInicio` por defecto = hoy.
  Future<SocioMembresia> asignarMembresia({
    required String socioId,
    required String membresiaId,
    DateTime? fechaInicio,
    double? precioPagado,
    String? notas,
  }) async {
    final socio = await getSocio(socioId);
    final plan = await getMembresia(membresiaId);
    if (socio == null) throw StateError('Socio no encontrado.');
    if (plan == null) throw StateError('Plan de membresía no encontrado.');

    final inicio = fechaInicio ?? DateTime.now();
    final fin = DateTime(inicio.year, inicio.month + plan.vigenciaMeses, inicio.day)
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.socioMembresias).insert(
      SocioMembresiasCompanion.insert(
        id: id,
        empresaId: empresaId,
        socioId: socioId,
        socioNombre: socio.nombre,
        membresiaId: membresiaId,
        membresiaNombre: plan.nombre,
        descuentoPorcentaje: Value(plan.descuentoPorcentaje),
        precioPagado: Value(precioPagado ?? plan.precio),
        fechaInicio: inicio,
        fechaFin: fin,
        estado: const Value(EstadoAfiliacion.activa),
        notas: Value(notas?.trim()),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );

    // Renueva nombres si el socio/plan cambiaron.
    await _renovarNombres(socioId, socio.nombre, membresiaId, plan.nombre);

    final q = _db.select(_db.socioMembresias)..where((a) => a.id.equals(id));
    return await q.getSingle();
  }

  Future<void> _renovarNombres(
    String socioId,
    String socioNombre,
    String membresiaId,
    String membresiaNombre,
  ) async {
    await (_db.update(_db.socioMembresias)
          ..where(
            (a) => a.socioId.equals(socioId) & a.empresaId.equals(empresaId),
          ))
        .write(
      SocioMembresiasCompanion(
        socioNombre: Value(socioNombre),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await (_db.update(_db.socioMembresias)
          ..where(
            (a) =>
                a.membresiaId.equals(membresiaId) &
                a.empresaId.equals(empresaId),
          ))
        .write(
      SocioMembresiasCompanion(
        membresiaNombre: Value(membresiaNombre),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Renueva una afiliación activa extendiendo su fecha de fin.
  Future<SocioMembresia> renovarMembresia({
    required String afiliacionId,
    int? meses,
    double? precioPagado,
    String? notas,
  }) async {
    final q = _db.select(_db.socioMembresias)..where((a) => a.id.equals(afiliacionId));
    final actual = await q.getSingleOrNull();
    if (actual == null) throw StateError('Afiliación no encontrada.');

    final plan = await getMembresia(actual.membresiaId);
    if (plan == null) throw StateError('Plan de membresía no encontrado.');

    if (actual.estado != EstadoAfiliacion.activa ||
        actual.fechaFin.isBefore(DateTime.now())) {
      throw StateError(
        'La membresía está ${EstadoAfiliacion.etiqueta(estadoEfectivo(actual))} a la baja. '
        'Asignala de nuevo para renovarla.',
      );
    }

    final mesesRenovacion = meses ?? plan.vigenciaMeses;
    final nuevaFin =
        DateTime(actual.fechaFin.year, actual.fechaFin.month + mesesRenovacion, actual.fechaFin.day)
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));

    await (_db.update(_db.socioMembresias)..where((a) => a.id.equals(afiliacionId)))
        .write(
      SocioMembresiasCompanion(
        fechaFin: Value(nuevaFin),
        precioPagado: Value(precioPagado ?? plan.precio),
        notas: Value(notas?.trim() ?? actual.notas),
        estado: const Value(EstadoAfiliacion.activa),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    final q2 = _db.select(_db.socioMembresias)..where((a) => a.id.equals(afiliacionId));
    return await q2.getSingle();
  }

  Future<void> cancelarAfiliacion(String id) async {
    final q = _db.select(_db.socioMembresias)..where((a) => a.id.equals(id));
    final actual = await q.getSingleOrNull();
    if (actual == null) throw StateError('Afiliación no encontrada.');
    if (actual.estado == EstadoAfiliacion.cancelada) return;
    await (_db.update(_db.socioMembresias)..where((a) => a.id.equals(id))).write(
      SocioMembresiasCompanion(
        estado: const Value(EstadoAfiliacion.cancelada),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PRECIOS PREFERENCIALES
  // ═══════════════════════════════════════════════════════════════

  Future<List<SocioPrecio>> getPreciosPreferenciales({String? socioId}) async {
    final q = _db.select(_db.socioPrecios)
      ..orderBy([(p) => OrderingTerm.asc(p.productoNombre)]);
    if (socioId != null) {
      q.where((p) => p.empresaId.equals(empresaId) & p.socioId.equals(socioId));
    } else {
      q.where((p) => p.empresaId.equals(empresaId));
    }
    return await q.get();
  }

  Future<SocioPrecio> asignarPrecioPreferencial({
    required String socioId,
    required Producto producto,
    required double precio,
  }) async {
    if (precio <= 0) {
      throw ArgumentError('El precio preferencial debe ser mayor a cero.');
    }
    final existente = await (_db.select(_db.socioPrecios)
          ..where(
            (p) =>
                p.empresaId.equals(empresaId) &
                p.socioId.equals(socioId) &
                p.productoId.equals(producto.id),
          ))
        .getSingleOrNull();

    if (existente != null) {
      await (_db.update(_db.socioPrecios)
            ..where((p) => p.id.equals(existente.id)))
          .write(
        SocioPreciosCompanion(
          precioPreferencial: Value(precio),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
      final q = _db.select(_db.socioPrecios)..where((p) => p.id.equals(existente.id));
      return await q.getSingle();
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db.into(_db.socioPrecios).insert(
      SocioPreciosCompanion.insert(
        id: id,
        empresaId: empresaId,
        socioId: socioId,
        productoId: producto.id,
        productoCodigo: Value(producto.codigo),
        productoNombre: producto.nombre,
        precioPreferencial: precio,
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
    final q = _db.select(_db.socioPrecios)..where((p) => p.id.equals(id));
    return await q.getSingle();
  }

  Future<void> eliminarPrecioPreferencial(String id) async {
    await (_db.delete(_db.socioPrecios)..where((p) => p.id.equals(id))).go();
  }

  /// Precio efectivo para un socio: precio preferencial por producto si
  /// existe; si no, precio de venta con el descuento del plan vigente.
  Future<double> precioParaSocio(String socioId, Producto producto) async {
    final preferencial = await (_db.select(_db.socioPrecios)
          ..where(
            (p) =>
                p.empresaId.equals(empresaId) &
                p.socioId.equals(socioId) &
                p.productoId.equals(producto.id),
          ))
        .getSingleOrNull();
    if (preferencial != null) return preferencial.precioPreferencial;

    final afiliaciones = await (_db.select(_db.socioMembresias)
          ..where(
            (a) =>
                a.empresaId.equals(empresaId) &
                a.socioId.equals(socioId) &
                a.estado.equals(EstadoAfiliacion.activa) &
                a.fechaFin.isBiggerThanValue(DateTime.now()),
          ))
        .get();
    if (afiliaciones.isNotEmpty) {
      final dcto = afiliaciones.first.descuentoPorcentaje;
      if (dcto > 0) {
        return producto.precioVenta * (1 - dcto / 100);
      }
    }
    return producto.precioVenta;
  }

  // ═══════════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════════

  Future<DashboardMembresias> getDashboard() async {
    await _marcarVencidas();
    final socios = await getSocios();
    final afiliaciones = await getAfiliaciones();
    final planes = await getMembresias();

    int activas = 0;
    int vencidas = 0;
    int porVencer = 0;
    final hoy = DateTime.now();
    final limite = hoy.add(const Duration(days: 7));
    double ingreso = 0;

    for (final a in afiliaciones) {
      ingreso += a.precioPagado;
      final st = estadoEfectivo(a);
      if (st == EstadoAfiliacion.activa) {
        activas++;
        if (a.fechaFin.isBefore(limite)) porVencer++;
      } else if (st == EstadoAfiliacion.vencida) {
        vencidas++;
      }
    }

    return DashboardMembresias(
      totalSocios: socios.length,
      sociosActivos: activas,
      sociosVencidos: vencidas,
      planesActivos: planes.where((p) => p.activo).length,
      porVencer: porVencer,
      ingresoMembresias: ingreso,
    );
  }
}
