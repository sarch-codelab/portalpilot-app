// lib/Modules/Facturacion/factura_service.dart
// Emisión de facturas legales (SAR) desde otros módulos, p. ej. el cobro del POS.
// Reutiliza el motor de correlativos/CAI de [SarService] y la persistencia
// offline-first de [LocalDatabaseService].

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/utils/fiscal_compliance.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

/// Error controlado al emitir una factura (config faltante, CAI vencido, etc.).
class FacturaException implements Exception {
  final String mensaje;
  final String codigo;

  FacturaException(this.mensaje, {this.codigo = 'error'});

  @override
  String toString() => mensaje;
}

/// Resultado de una factura emitida, con lo necesario para imprimir/compartir.
class FacturaCreada {
  final Map<String, dynamic> factura;
  final SarConfiguracionData config;
  final SarCorrelativoData? correlativo;

  const FacturaCreada({
    required this.factura,
    required this.config,
    this.correlativo,
  });
}

/// Servicio de emisión de facturas legales reutilizable por cualquier módulo.
class FacturaService {
  FacturaService._();
  static final FacturaService instance = FacturaService._();

  /// Crea y persiste una factura (tipo 01) a partir del detalle de una venta.
  ///
  /// [items] usa el formato del módulo de facturación:
  /// `{'descripcion': String, 'cantidad': num, 'precio': num, 'isv': num,
  ///   'exento': bool}`.
  Future<FacturaCreada> crearDesdeVenta({
    required List<Map<String, dynamic>> items,
    required String clienteNombre,
    String? clienteRtn,
    String? clienteDireccion,
    String condicionPago = 'Contado',
    String tipoVenta = 'Gravada',
    double descuentoGlobal = 0,
    double? tasaIsvEstandar,
    String? ventaId,
    String? notas,
  }) async {
    if (items.isEmpty) {
      throw FacturaException('No hay conceptos para facturar.', codigo: 'sin_items');
    }

    final empresaId = AuthController.instance.empresaCodigo;
    final usuarioId = AuthController.instance.email;

    SarService.instance.setContext(empresaId: empresaId, usuarioId: usuarioId);

    const tipoCodigo = SarTipoDocumento.factura;

    final validacion = await SarService.instance.validarEmision(tipoCodigo);
    if (!validacion.ok) {
      throw FacturaException(validacion.mensaje, codigo: validacion.codigo);
    }

    final config = await SarService.instance.getConfiguracion();
    if (config == null) {
      throw FacturaException(
        'Configurá los datos fiscales de tu empresa antes de facturar.',
        codigo: 'sin_config',
      );
    }

    final row = await SarService.instance.getCorrelativoPorTipo(tipoCodigo);
    final contingenciaActiva = await SarService.instance.esContingenciaActiva();

    final correlativo = contingenciaActiva
        ? await SarService.instance.siguienteCorrelativoContingencia(tipoCodigo)
        : await SarService.instance.siguienteCorrelativo(tipoCodigo);

    final tasaEstandar = tasaIsvEstandar ?? await _tasaEstandar();

    final totales = SarService.calcularTotales(
      items,
      descuentoGlobal: descuentoGlobal,
      tasaIsvEstandar: tasaEstandar,
    );

    final fiscalGeneral = FiscalCompliance();
    await fiscalGeneral.loadConfig();
    final cfgGeneral = fiscalGeneral.config;

    final regimenSimplificado = config.regimen == 'simplificado';
    final empresaNombre = (config.razonSocial ?? '').trim().isNotEmpty
        ? config.razonSocial!
        : ((config.nombreComercial ?? '').trim().isNotEmpty
            ? config.nombreComercial!
            : cfgGeneral.nombreEmpresa);
    final empresaRtn = (config.rtn ?? '').trim().isNotEmpty
        ? config.rtn!
        : cfgGeneral.rtnEmpresa;

    final factura = {
      'id': const Uuid().v4(),
      'correlativo': correlativo,
      'tipo_documento': SarTipoDocumento.etiqueta(tipoCodigo),
      'fecha': DateTime.now().toIso8601String(),
      'cai': regimenSimplificado ? '' : (row.cai ?? cfgGeneral.cai ?? ''),
      'resolucion': row.numeroResolucion ?? '',
      'rango_inicio': row.rangoInicio ?? '001-001-01-00000001',
      'rango_fin': row.rangoFin ?? '',
      'fecha_limite_emision': row.fechaLimiteEmision?.toIso8601String(),
      'empresa_nombre': empresaNombre,
      'empresa_rtn': empresaRtn,
      'regimen': regimenSimplificado ? 'simplificado' : 'general',
      'cliente_nombre': clienteNombre,
      'cliente_rtn': clienteRtn ?? '',
      'cliente_direccion': clienteDireccion ?? '',
      'condicion_pago': condicionPago,
      'tipo_venta': tipoVenta,
      'items': items,
      'subtotal': totales.subtotal,
      'isv_15': totales.isv15,
      'isv_18': totales.isv18,
      'descuento': totales.descuento,
      'total': totales.total,
      'tasa_isv_estandar': tasaEstandar,
      'estado': 'emitida',
      'contingencia': contingenciaActiva,
      'notas': contingenciaActiva ? 'Emitida en régimen de contingencia' : notas,
      'venta_id': ?ventaId,
    };

    // Espejo en preferencias: la pantalla de Facturación lee de aquí.
    final prefs = await SharedPreferences.getInstance();
    final facturas = JsonGuard.safeListOfMaps(
      prefs.getString('facturas') ?? '[]',
      source: 'FacturaService.crearDesdeVenta',
    );
    facturas.add(factura);
    try {
      await prefs.setString('facturas', jsonEncode(facturas));
    } catch (e) {
      debugPrint('⚠️ No se pudo espejar la factura en preferencias: $e');
    }

    try {
      await LocalDatabaseService.instance.insertFacturaLocal(
        id: factura['id'] as String,
        empresaId: empresaId,
        usuarioId: usuarioId,
        correlativo: correlativo,
        tipoDocumento: factura['tipo_documento'] as String,
        cai: (factura['cai'] as String?) ?? '',
        rangoInicio: factura['rango_inicio'] as String?,
        rangoFin: factura['rango_fin'] as String?,
        fechaLimiteEmision: row.fechaLimiteEmision,
        clienteNombre: clienteNombre,
        clienteRtn: clienteRtn ?? '',
        clienteDireccion: clienteDireccion ?? '',
        condicionPago: condicionPago,
        tipoVenta: tipoVenta,
        items: {'items': items},
        subtotal: totales.subtotal,
        isv15: totales.isv15,
        isv18: totales.isv18,
        descuento: totales.descuento,
        total: totales.total,
        estado: 'emitida',
        notas: factura['notas'] as String?,
        operacion: SyncOperation.insert,
        tasaIsvEstandar: tasaEstandar,
      );
    } catch (e) {
      throw FacturaException(
        'No se pudo guardar la factura localmente: $e',
        codigo: 'persistencia',
      );
    }

    if (contingenciaActiva) {
      try {
        await SarService.instance.registrarContingencia(
          tipoDocumento: tipoCodigo,
          correlativo: correlativo,
          monto: totales.total,
          motivo: 'Venta POS en contingencia',
          referencia: ventaId,
        );
      } catch (e) {
        debugPrint('⚠️ No se pudo registrar la contingencia: $e');
      }
    }

    Logger().audit(
      'crear',
      'factura',
      correlativo,
      userId: usuarioId,
      module: 'pos',
      changes: {
        'origen': 'pos',
        'venta_id': ventaId ?? '',
        'cliente': clienteNombre,
        'total': totales.total.toStringAsFixed(2),
      },
    );

    return FacturaCreada(factura: factura, config: config, correlativo: row);
  }

  Future<double> _tasaEstandar() async {
    try {
      final fiscal = FiscalCompliance();
      await fiscal.loadConfig();
      final tasa = fiscal.config.tasaISV;
      if (tasa > 0) return tasa / 100;
    } catch (_) {}
    return 0.15;
  }
}
