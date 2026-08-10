// lib/Shared/services/sar_service.dart
// Motor de Facturación SAR Honduras (Paso 3).
// Gestión de CAI, correlativos controlados, validación RTN/CAI, motor ISV,
// régimen de contingencia, reporte mensual ISV y conversión de montos a letras.

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

/// Tipos de documento fiscal autorizados por la DEI/SAR.
class SarTipoDocumento {
  static const String factura = '01';
  static const String notaCredito = '02';
  static const String notaDebito = '03';
  static const String facturaExportacion = '04';
  static const String tiquete = '05';
  static const String cf = 'CF';
  static const String comprobanteContingencia = '99';

  static String etiqueta(String tipo) {
    switch (tipo) {
      case factura:
        return 'Factura';
      case notaCredito:
        return 'Nota de Crédito';
      case notaDebito:
        return 'Nota de Débito';
      case facturaExportacion:
        return 'Factura Exportación';
      case tiquete:
        return 'Tiquete';
      case cf:
        return 'Comprobante Fiscal (RST)';
      case comprobanteContingencia:
        return 'Comprobante Contingencia';
      default:
        return 'Documento $tipo';
    }
  }

  static String codigoPorNombre(String nombre) {
    switch (nombre) {
      case 'Nota de Crédito':
      case 'Nota Crédito':
        return notaCredito;
      case 'Nota de Débito':
      case 'Nota Débito':
        return notaDebito;
      case 'Factura Exportación':
        return facturaExportacion;
      case 'Tiquete':
        return tiquete;
      case 'Comprobante Fiscal (RST)':
      case 'Comprobante Fiscal':
      case 'CF':
        return cf;
      default:
        return factura;
    }
  }

  static List<String> get tiposHabituales => [
    factura,
    notaCredito,
    notaDebito,
    facturaExportacion,
    tiquete,
  ];
}

/// Resultado de validación de emisión de un documento fiscal.
class SarValidacion {
  final bool ok;
  final String codigo;
  final String mensaje;

  const SarValidacion({
    required this.ok,
    required this.codigo,
    required this.mensaje,
  });

  const SarValidacion.ok() : ok = true, codigo = 'ok', mensaje = '';
}

/// Estado consolidado de la configuración SAR de la empresa.
class EstadoSAR {
  final bool configurado;
  final bool rtnValido;
  final bool caiConfigurado;
  final bool caiVencido;
  final int diasRestantes;
  final int rangoUsado;
  final int rangoTotal;
  final double porcentajeUso;
  final bool rangoAgotado;
  final bool contingenciaActiva;
  final String? motivoContingencia;
  final String? rangoInicio;
  final String? rangoFin;
  final String? cai;
  final String? fechaLimite;

  const EstadoSAR({
    required this.configurado,
    required this.rtnValido,
    required this.caiConfigurado,
    required this.caiVencido,
    required this.diasRestantes,
    required this.rangoUsado,
    required this.rangoTotal,
    required this.porcentajeUso,
    required this.rangoAgotado,
    required this.contingenciaActiva,
    this.motivoContingencia,
    this.rangoInicio,
    this.rangoFin,
    this.cai,
    this.fechaLimite,
  });
}

/// Totales calculados por el motor ISV de Honduras.
class SarTotales {
  final double base15;
  final double base18;
  final double baseExenta;
  final double subtotal;
  final double isv15;
  final double isv18;
  final double totalIsv;
  final double descuento;
  final double total;

  const SarTotales({
    required this.base15,
    required this.base18,
    required this.baseExenta,
    required this.subtotal,
    required this.isv15,
    required this.isv18,
    required this.totalIsv,
    required this.descuento,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'base_15': base15,
    'base_18': base18,
    'base_exenta': baseExenta,
    'subtotal': subtotal,
    'isv_15': isv15,
    'isv_18': isv18,
    'total_isv': totalIsv,
    'descuento': descuento,
    'total': total,
  };
}

class SarService {
  SarService._();
  static final SarService instance = SarService._();

  final AppDatabase _db = LocalDatabaseService.instance.database;

  String? _empresaId;
  String? _usuarioId;

  void setContext({required String empresaId, String? usuarioId}) {
    _empresaId = empresaId;
    _usuarioId = usuarioId;
  }

  /// Inicializa el servicio. Por ahora no requiere setup adicional,
  /// pero se invoca al arrancar la app para asegurar el contexto.
  Future<void> initialize() async {}

  String get empresaId => _empresaId ?? 'ROOT';

  String get usuarioId => _usuarioId ?? '';

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURACIÓN SAR
  // ═══════════════════════════════════════════════════════════════

  Future<SarConfiguracionData?> getConfiguracion() async {
    return await (_db.select(
      _db.sarConfiguracion,
    )..where((c) => c.empresaId.equals(empresaId))).getSingleOrNull();
  }

  Future<SarConfiguracionData> getConfiguracionOCrear() async {
    final existente = await getConfiguracion();
    if (existente != null) return existente;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db
        .into(_db.sarConfiguracion)
        .insert(
          SarConfiguracionCompanion.insert(
            id: id,
            empresaId: empresaId,
            updatedAt: Value(DateTime.now()),
          ),
        );
    return (await getConfiguracion())!;
  }

  Future<void> guardarConfiguracion({
    required String rtn,
    required String razonSocial,
    String? nombreComercial,
    String? direccion,
    String? telefono,
    String? email,
    String? representanteLegal,
    String? actividadEconomica,
    String? establecimiento,
    String? puntoEmision,
    String? regimen,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db
        .into(_db.sarConfiguracion)
        .insertOnConflictUpdate(
          SarConfiguracionCompanion(
            id: Value(id),
            empresaId: Value(empresaId),
            rtn: Value(rtn.trim()),
            razonSocial: Value(razonSocial.trim()),
            nombreComercial: Value(nombreComercial?.trim()),
            direccion: Value(direccion?.trim()),
            telefono: Value(telefono?.trim()),
            email: Value(email?.trim()),
            representanteLegal: Value(representanteLegal?.trim()),
            actividadEconomica: Value(actividadEconomica?.trim()),
            establecimiento: Value((establecimiento ?? '001').trim()),
            puntoEmision: Value((puntoEmision ?? '001').trim()),
            regimen: Value(regimen?.trim() ?? 'general'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    debugPrint('✅ Configuración SAR guardada para $empresaId');
  }

  /// Guarda/actualiza el CAI y rango de un tipo de documento.
  Future<void> guardarCaiPorTipo({
    required String tipoDocumento,
    String? cai,
    String? numeroResolucion,
    String? rangoInicio,
    String? rangoFin,
    DateTime? fechaLimiteEmision,
  }) async {
    final existente =
        await (_db.select(_db.sarCorrelativo)..where(
              (c) =>
                  c.empresaId.equals(empresaId) &
                  c.tipoDocumento.equals(tipoDocumento),
            ))
            .getSingleOrNull();

    final numeroInicial = SarService.numeroDeCorrelativo(rangoInicio) ?? 1;

    if (existente != null) {
      await (_db.update(
        _db.sarCorrelativo,
      )..where((c) => c.id.equals(existente.id))).write(
        SarCorrelativoCompanion(
          cai: Value(cai?.trim()),
          numeroResolucion: Value(numeroResolucion?.trim()),
          rangoInicio: Value(rangoInicio?.trim()),
          rangoFin: Value(rangoFin?.trim()),
          fechaLimiteEmision: Value(fechaLimiteEmision),
          // Al reconfigurar, si el correlativo se quedó fuera del rango, lo restablece.
          siguienteNumero: Value(
            numeroInicial > existente.siguienteNumero
                ? numeroInicial
                : existente.siguienteNumero,
          ),
          agotado: const Value(false),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    } else {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      await _db
          .into(_db.sarCorrelativo)
          .insert(
            SarCorrelativoCompanion.insert(
              id: id,
              empresaId: empresaId,
              tipoDocumento: Value(tipoDocumento),
              cai: Value(cai?.trim()),
              numeroResolucion: Value(numeroResolucion?.trim()),
              rangoInicio: Value(rangoInicio?.trim()),
              rangoFin: Value(rangoFin?.trim()),
              fechaLimiteEmision: Value(fechaLimiteEmision),
              siguienteNumero: const Value(1),
              agotado: const Value(false),
            ),
          );
    }
  }

  Future<List<SarCorrelativoData>> getCorrelativos() async {
    return await (_db.select(
      _db.sarCorrelativo,
    )..where((c) => c.empresaId.equals(empresaId))).get();
  }

  Future<SarCorrelativoData> getCorrelativoPorTipo(String tipo) async {
    return _getOrCreateCorrelativo(tipo);
  }

  // ═══════════════════════════════════════════════════════════════
  // ESTADO SAR
  // ═══════════════════════════════════════════════════════════════

  Future<EstadoSAR> obtenerEstadoSAR({
    String tipoDocumento = SarTipoDocumento.factura,
  }) async {
    final config = await getConfiguracion();
    if (config == null) {
      return const EstadoSAR(
        configurado: false,
        rtnValido: false,
        caiConfigurado: false,
        caiVencido: false,
        diasRestantes: 0,
        rangoUsado: 0,
        rangoTotal: 0,
        porcentajeUso: 0,
        rangoAgotado: false,
        contingenciaActiva: false,
      );
    }

    final row = await _getOrCreateCorrelativo(tipoDocumento);
    final caiConfigurado = (row.cai ?? '').isNotEmpty;
    final fechaLimite = row.fechaLimiteEmision;
    final vencido =
        caiConfigurado &&
        fechaLimite != null &&
        fechaLimite.isBefore(DateTime.now());
    final diasRestantes = fechaLimite != null
        ? fechaLimite.difference(DateTime.now()).inDays.clamp(0, 99999)
        : 0;

    final numInicio = numeroDeCorrelativo(row.rangoInicio) ?? 1;
    final numFin = numeroDeCorrelativo(row.rangoFin);
    final rangoTotal = numFin != null && numFin >= numInicio
        ? numFin - numInicio + 1
        : 0;
    final rangoUsado = (row.siguienteNumero - numInicio).clamp(0, rangoTotal);
    final porcentaje = rangoTotal > 0
        ? (rangoUsado / rangoTotal * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;

    return EstadoSAR(
      configurado:
          (config.rtn ?? '').isNotEmpty &&
          (config.razonSocial ?? '').isNotEmpty,
      rtnValido: esRTNValido(config.rtn ?? ''),
      caiConfigurado: caiConfigurado,
      caiVencido: vencido,
      diasRestantes: diasRestantes,
      rangoUsado: rangoUsado,
      rangoTotal: rangoTotal,
      porcentajeUso: porcentaje,
      rangoAgotado:
          row.agotado || (numFin != null && row.siguienteNumero > numFin),
      contingenciaActiva: config.contingenciaActiva,
      motivoContingencia: config.motivoContingencia,
      rangoInicio: row.rangoInicio,
      rangoFin: row.rangoFin,
      cai: row.cai,
      fechaLimite: fechaLimite?.toIso8601String(),
    );
  }

  /// Valida si la empresa puede emitir un documento del tipo indicado.
  Future<SarValidacion> validarEmision(String tipoDocumento) async {
    final config = await getConfiguracion();
    if (config == null) {
      return const SarValidacion(
        ok: false,
        codigo: 'sin_config',
        mensaje:
            'Configurá los datos fiscales de tu empresa antes de facturar.',
      );
    }
    if ((config.rtn ?? '').trim().isEmpty) {
      return const SarValidacion(
        ok: false,
        codigo: 'sin_rtn',
        mensaje: 'Falta el RTN de la empresa en la configuración SAR.',
      );
    }
    if (!esRTNValido(config.rtn!)) {
      return const SarValidacion(
        ok: false,
        codigo: 'rtn_invalido',
        mensaje: 'El RTN de la empresa no es válido. Verificá el dígito.',
      );
    }
    if (config.contingenciaActiva) {
      return const SarValidacion(
        ok: true,
        codigo: 'ok',
        mensaje: 'Régimen de contingencia activo.',
      );
    }

    // Régimen Simplificado (RST): se emite Comprobante Fiscal (CF) sin CAI.
    final regimenSimplificado = config.regimen == 'simplificado';
    if (regimenSimplificado) {
      if (tipoDocumento != SarTipoDocumento.cf &&
          tipoDocumento != SarTipoDocumento.comprobanteContingencia) {
        return SarValidacion(
          ok: false,
          codigo: 'tipo_no_rst',
          mensaje:
              'En el Régimen Simplificado solo se emiten Comprobantes Fiscales (CF). '
              'Seleccioná el tipo "Comprobante Fiscal".',
        );
      }
      return const SarValidacion(
        ok: true,
        codigo: 'ok',
        mensaje: 'Comprobante Fiscal sin CAI (Régimen Simplificado).',
      );
    }

    final row = await _getOrCreateCorrelativo(tipoDocumento);
    if ((row.cai ?? '').trim().isEmpty) {
      return SarValidacion(
        ok: false,
        codigo: 'sin_cai',
        mensaje:
            'El tipo "${SarTipoDocumento.etiqueta(tipoDocumento)}" no tiene CAI configurado.',
      );
    }
    if (row.fechaLimiteEmision != null &&
        row.fechaLimiteEmision!.isBefore(DateTime.now())) {
      return const SarValidacion(
        ok: false,
        codigo: 'cai_vencido',
        mensaje:
            'El CAI está vencido. No es posible emitir documentos con este rango.',
      );
    }
    if (row.agotado) {
      return const SarValidacion(
        ok: false,
        codigo: 'rango_agotado',
        mensaje:
            'El rango de numeración está agotado. Solicitá un nuevo CAI a la SAR.',
      );
    }
    final numFin = numeroDeCorrelativo(row.rangoFin);
    if (numFin != null && row.siguienteNumero > numFin) {
      return const SarValidacion(
        ok: false,
        codigo: 'rango_agotado',
        mensaje:
            'El rango de numeración está agotado. Solicitá un nuevo CAI a la SAR.',
      );
    }
    return const SarValidacion(ok: true, codigo: 'ok', mensaje: '');
  }

  // ═══════════════════════════════════════════════════════════════
  // CORRELATIVOS (control atómico, sin huecos)
  // ═══════════════════════════════════════════════════════════════

  Future<SarCorrelativoData> _getOrCreateCorrelativo(
    String tipoDocumento,
  ) async {
    final existente =
        await (_db.select(_db.sarCorrelativo)..where(
              (c) =>
                  c.empresaId.equals(empresaId) &
                  c.tipoDocumento.equals(tipoDocumento),
            ))
            .getSingleOrNull();
    if (existente != null) return existente;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _db
        .into(_db.sarCorrelativo)
        .insert(
          SarCorrelativoCompanion.insert(
            id: id,
            empresaId: empresaId,
            tipoDocumento: Value(tipoDocumento),
            siguienteNumero: const Value(1),
            agotado: const Value(false),
          ),
        );
    return (await (_db.select(
      _db.sarCorrelativo,
    )..where((c) => c.id.equals(id))).getSingle());
  }

  /// Devuelve el siguiente correlativo SIN consumirlo (vista previa).
  Future<String> correlativoPreview(String tipoDocumento) async {
    final row = await _getOrCreateCorrelativo(tipoDocumento);
    final config = await getConfiguracion();
    return _formatearCorrelativo(config, tipoDocumento, row.siguienteNumero);
  }

  /// Consume el siguiente correlativo de forma atómica y lo devuelve.
  Future<String> siguienteCorrelativo(String tipoDocumento) async {
    final config = await getConfiguracion();
    return _db.transaction(() async {
      final row = await _getOrCreateCorrelativo(tipoDocumento);
      final numero = row.siguienteNumero;
      final numFin = numeroDeCorrelativo(row.rangoFin);
      final siguiente = numero + 1;
      final agotado = numFin != null && siguiente > numFin;

      await (_db.update(
        _db.sarCorrelativo,
      )..where((c) => c.id.equals(row.id))).write(
        SarCorrelativoCompanion(
          siguienteNumero: Value(siguiente),
          agotado: Value(agotado),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return _formatearCorrelativo(config, tipoDocumento, numero);
    });
  }

  String _formatearCorrelativo(
    SarConfiguracionData? config,
    String tipo,
    int numero,
  ) {
    final est = (config?.establecimiento ?? '001').padLeft(3, '0');
    final punto = (config?.puntoEmision ?? '001').padLeft(3, '0');
    return '$est-$punto-$tipo-${numero.toString().padLeft(8, '0')}';
  }

  static int? numeroDeCorrelativo(String? correlativo) {
    if (correlativo == null || correlativo.isEmpty) return null;
    final partes = correlativo.split('-');
    if (partes.isEmpty) return null;
    return int.tryParse(partes.last);
  }

  // ═══════════════════════════════════════════════════════════════
  // RÉGIMEN DE CONTINGENCIA
  // ═══════════════════════════════════════════════════════════════

  Future<void> activarContingencia({required String motivo}) async {
    final config = await getConfiguracionOCrear();
    await (_db.update(
      _db.sarConfiguracion,
    )..where((c) => c.id.equals(config.id))).write(
      SarConfiguracionCompanion(
        contingenciaActiva: const Value(true),
        motivoContingencia: Value(motivo),
        fechaInicioContingencia: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    debugPrint('⚠️ Contingencia activada: $motivo');
  }

  Future<void> desactivarContingencia() async {
    final config = await getConfiguracion();
    if (config == null) return;
    await (_db.update(
      _db.sarConfiguracion,
    )..where((c) => c.id.equals(config.id))).write(
      SarConfiguracionCompanion(
        contingenciaActiva: const Value(false),
        motivoContingencia: const Value(null),
        fechaInicioContingencia: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<bool> esContingenciaActiva() async {
    final config = await getConfiguracion();
    return config?.contingenciaActiva ?? false;
  }

  /// Correlativo para comprobantes de contingencia (serie 99 por tipo).
  Future<String> siguienteCorrelativoContingencia(String tipoDocumento) async {
    final config = await getConfiguracion();
    final ultimo =
        await (_db.select(_db.sarContingencia)
              ..where(
                (c) =>
                    c.empresaId.equals(empresaId) &
                    c.tipoDocumento.equals(tipoDocumento),
              )
              ..orderBy([(c) => OrderingTerm.desc(c.correlativo)])
              ..limit(1))
            .getSingleOrNull();

    int numero = 1;
    if (ultimo != null) {
      numero = (numeroDeCorrelativo(ultimo.correlativo) ?? 0) + 1;
    }
    final est = (config?.establecimiento ?? '001').padLeft(3, '0');
    final punto = (config?.puntoEmision ?? '001').padLeft(3, '0');
    return '$est-$punto-${SarTipoDocumento.comprobanteContingencia}-${numero.toString().padLeft(8, '0')}';
  }

  /// Registra un documento emitido en contingencia para su posterior reporte.
  Future<void> registrarContingencia({
    required String tipoDocumento,
    required String correlativo,
    required double monto,
    String? motivo,
    String? referencia,
  }) async {
    await _db
        .into(_db.sarContingencia)
        .insert(
          SarContingenciaCompanion.insert(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            empresaId: empresaId,
            tipoDocumento: Value(tipoDocumento),
            correlativo: correlativo,
            motivo: Value(motivo),
            referencia: Value(referencia),
            fechaEmision: DateTime.now(),
            monto: Value(monto),
            estado: const Value('emitido'),
          ),
        );
  }

  Future<List<SarContingenciaData>> getContingencias() async {
    return await (_db.select(_db.sarContingencia)
          ..where((c) => c.empresaId.equals(empresaId))
          ..orderBy([(c) => OrderingTerm.desc(c.fechaEmision)]))
        .get();
  }

  // ═══════════════════════════════════════════════════════════════
  // MOTOR ISV HONDURAS (15% bienes, 18% bebidas/tabaco, exenta canasta)
  // ═══════════════════════════════════════════════════════════════

  static SarTotales calcularTotales(
    List<Map<String, dynamic>> items, {
    double descuentoGlobal = 0,
  }) {
    double base15 = 0;
    double base18 = 0;
    double baseExenta = 0;

    for (final item in items) {
      final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0;
      final precio = (item['precio'] as num?)?.toDouble() ?? 0;
      final isvRate = (item['isv'] as num?)?.toDouble() ?? 15.0;
      final exento = item['exento'] == true;

      final linea = cantidad * precio;
      if (exento || isvRate <= 0) {
        baseExenta += linea;
      } else if (isvRate >= 18) {
        base18 += linea;
      } else {
        base15 += linea;
      }
    }

    final subtotalSinDescuento = base15 + base18 + baseExenta;
    final descuento = descuentoGlobal.clamp(0, subtotalSinDescuento).toDouble();
    final subtotal = subtotalSinDescuento - descuento;
    final factor = subtotalSinDescuento > 0
        ? subtotal / subtotalSinDescuento
        : 0;

    final b15 = _redondear(base15 * factor);
    final b18 = _redondear(base18 * factor);
    final bEx = _redondear(baseExenta * factor);
    final isv15 = _redondear(b15 * 0.15);
    final isv18 = _redondear(b18 * 0.18);
    final totalIsv = _redondear(isv15 + isv18);
    final total = _redondear(b15 + b18 + bEx + totalIsv);

    return SarTotales(
      base15: b15,
      base18: b18,
      baseExenta: bEx,
      subtotal: subtotal,
      isv15: isv15,
      isv18: isv18,
      totalIsv: totalIsv,
      descuento: descuento,
      total: total,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VALIDACIÓN RTN / CAI
  // ═══════════════════════════════════════════════════════════════

  /// Valida un RTN hondureño: 14 dígitos con dígito verificador (módulo 11).
  static bool esRTNValido(String rtn, {bool verificarDigito = true}) {
    final limpio = rtn.replaceAll(RegExp(r'[-\s]'), '');
    if (!RegExp(r'^\d{14}$').hasMatch(limpio)) return false;
    if (!verificarDigito) return true;

    const pesos = [3, 2, 7, 6, 5, 4, 3, 2, 7, 6, 5, 4, 3];
    var suma = 0;
    for (var i = 0; i < 13; i++) {
      suma += int.parse(limpio[i]) * pesos[i];
    }
    var dv = 11 - (suma % 11);
    if (dv > 9) dv = 0;
    return dv == int.parse(limpio[13]);
  }

  /// Formatea un RTN de 14 dígitos a XXXX-XXXXXX-XXXXX.
  static String formatearRTN(String rtn) {
    final limpio = rtn.replaceAll(RegExp(r'[-\s]'), '');
    if (limpio.length != 14) return rtn;
    return '${limpio.substring(0, 4)}-${limpio.substring(4, 10)}-${limpio.substring(10)}';
  }

  /// Valida el formato de un CAI de la SAR (25 caracteres alfanuméricos).
  static bool esCAIValido(String cai) {
    final limpio = cai.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (limpio.length != 25) return false;
    return RegExp(r'^[A-Z0-9]+$').hasMatch(limpio);
  }

  /// Devuelve el CAI normalizado (sin guiones, en mayúsculas).
  static String normalizarCAI(String cai) {
    return cai.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════════
  // REPORTE MENSUAL ISV (para declaración SAR)
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> obtenerReporteISV({
    required DateTime inicio,
    required DateTime fin,
  }) async {
    final facturas =
        await (_db.select(_db.facturas)..where(
              (f) =>
                  f.empresaId.equals(empresaId) &
                  f.createdAt.isBiggerOrEqualValue(inicio) &
                  f.createdAt.isSmallerOrEqualValue(fin),
            ))
            .get();

    double base15 = 0, base18 = 0, baseExenta = 0;
    double isv15 = 0, isv18 = 0;
    double totalVentas = 0;
    int emitidas = 0, anuladas = 0;

    for (final f in facturas) {
      if (f.estado == 'anulada') {
        anuladas++;
        continue;
      }
      emitidas++;
      base15 += f.isv15 != 0 ? f.subtotal : 0;
      base18 += f.isv18 != 0 ? f.subtotal : 0;
      isv15 += f.isv15;
      isv18 += f.isv18;
      totalVentas += f.total;
    }

    // Ventas POS también tributan ISV
    final ventasPos =
        await (_db.select(_db.posVentas)..where(
              (v) =>
                  v.empresaId.equals(empresaId) &
                  v.estado.equals('completada') &
                  v.createdAt.isBiggerOrEqualValue(inicio) &
                  v.createdAt.isSmallerOrEqualValue(fin),
            ))
            .get();

    for (final v in ventasPos) {
      isv15 += v.isv15;
      isv18 += v.isv18;
      totalVentas += v.total;
    }

    return {
      'periodo': '${fmtFecha(inicio)} al ${fmtFecha(fin)}',
      'total_ventas': _redondear(totalVentas),
      'base_15': _redondear(base15),
      'base_18': _redondear(base18),
      'base_exenta': _redondear(baseExenta),
      'isv_15': _redondear(isv15),
      'isv_18': _redondear(isv18),
      'total_isv': _redondear(isv15 + isv18),
      'facturas_emitidas': emitidas,
      'facturas_anuladas': anuladas,
      'ventas_pos': ventasPos.length,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // MONTO A LETRAS (Lempiras)
  // ═══════════════════════════════════════════════════════════════

  /// Convierte un monto a letras: "MIL QUINIENTOS TREINTA Y DOS CON 45/100".
  static String numeroALetras(double monto) {
    final entero = monto.truncate();
    final centavos = (monto * 100).round() % 100;

    final letras = _gruposALetras(entero.abs());
    final signo = monto < 0 ? 'MENOS ' : '';
    return '$signo$letras CON ${centavos.toString().padLeft(2, '0')}/100';
  }

  static String _gruposALetras(int n) {
    if (n == 0) return 'CERO';

    final millones = n ~/ 1000000;
    final miles = (n % 1000000) ~/ 1000;
    final resto = n % 1000;

    final partes = <String>[];
    if (millones > 0) {
      if (millones == 1) {
        partes.add('UN MILLON');
      } else {
        partes.add('${_grupoHasta999(millones)} MILLONES');
      }
    }
    if (miles > 0) {
      if (miles == 1) {
        partes.add('MIL');
      } else {
        partes.add('${_grupoHasta999(miles)} MIL');
      }
    }
    if (resto > 0) {
      partes.add(_grupoHasta999(resto));
    }
    return partes.join(' ');
  }

  static String _grupoHasta999(int n) {
    if (n < 0 || n > 999) return '';
    if (n < 20) return _unidades[n];
    if (n < 100) {
      final d = n ~/ 10;
      final u = n % 10;
      if (d == 2) return u == 0 ? 'VEINTE' : 'VEINTI${_unidades[u]}';
      if (u == 0) return _decenas[d];
      return '${_decenas[d]} Y ${_unidades[u]}';
    }
    final c = n ~/ 100;
    final r = n % 100;
    if (c == 1) {
      return r == 0 ? 'CIEN' : 'CIENTO ${_grupoHasta999(r)}';
    }
    final centena = _centenas[c];
    if (r == 0) return centena;
    return '$centena ${_grupoHasta999(r)}';
  }

  static const List<String> _unidades = [
    '',
    'UNO',
    'DOS',
    'TRES',
    'CUATRO',
    'CINCO',
    'SEIS',
    'SIETE',
    'OCHO',
    'NUEVE',
    'DIEZ',
    'ONCE',
    'DOCE',
    'TRECE',
    'CATORCE',
    'QUINCE',
    'DIECISEIS',
    'DIECISIETE',
    'DIECIOCHO',
    'DIECINUEVE',
  ];

  static const List<String> _decenas = [
    '',
    '',
    'VEINTE',
    'TREINTA',
    'CUARENTA',
    'CINCUENTA',
    'SESENTA',
    'SETENTA',
    'OCHENTA',
    'NOVENTA',
  ];

  static const List<String> _centenas = [
    '',
    'CIENTO',
    'DOSCIENTOS',
    'TRESCIENTOS',
    'CUATROCIENTOS',
    'QUINIENTOS',
    'SEISCIENTOS',
    'SETECIENTOS',
    'OCHOCIENTOS',
    'NOVECIENTOS',
  ];

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════

  static double _redondear(double v) => (v * 100).roundToDouble() / 100;

  static String fmtFecha(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  static String formatearMonto(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
