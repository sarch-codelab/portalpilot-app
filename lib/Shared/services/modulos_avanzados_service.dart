/* ═══════════════════════════════════════════════════════════════
   SERVICIO DE MÓDULOS AVANZADOS
   contabilidad · rrhh · fiscal_advanced · crm_advanced · multi_empresa

   POR QUÉ
   Estas pantallas leían SharedPreferences del dispositivo o listas
   hardcoded en memoria. Eso rompía el aislamiento por empresa: dos
   usuarios del mismo negocio en teléfonos distintos no compartían
   nada, y los datos se perdían al desinstalar. Ahora leen y escriben
   contra la API, donde el tenant sale del JWT y nunca del body.

   REGLA DE ORO (no negociable)
   El empresa_codigo NUNCA se envía ni se lee del body/query. Lo
   resuelve el servidor desde el token. Por eso este servicio no
   tiene ningún parámetro de tenant: si lo tuviera, alguien terminaría
   pasándolo desde el cliente y rompería el aislamiento.

   Manejo de plan insuficiente: los endpoints responden 403 con
   code PLAN_LIMIT. Acá se traduce a un mensaje que la UI puede
   mostrar, sin tragarse el error.
   ═══════════════════════════════════════════════════════════════ */
import 'package:flutter/foundation.dart';
import 'package:portal_pilot_app/Shared/services/api_service.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';

/// Resultado de una llamada: datos o un error ya interpretable por la UI.
class ModuloResultado<T> {
  final T? datos;
  final String? error;
  final bool planLimitado;
  final bool sinConexion;

  const ModuloResultado.ok(this.datos)
      : error = null,
        planLimitado = false,
        sinConexion = false;

  const ModuloResultado.fallido(this.error, {this.planLimitado = false, this.sinConexion = false})
      : datos = null;

  bool get ok => error == null;

  /// El módulo no está en el plan del tenant (o el plan venció).
  bool get requierePlanSuperior => planLimitado;
}

class ModulosAvanzadosService {
  ModulosAvanzadosService._();
  static final ModulosAvanzadosService instance = ModulosAvanzadosService._();

  ApiService get _api => ApiService.instance;

  // ── Interpretación de respuestas ────────────────────────────
  Map<String, dynamic> _map(dynamic raw, String origen) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) return JsonGuard.tryDecodeMap(raw) ?? const <String, dynamic>{};
    return const {};
  }

  List<Map<String, dynamic>> _lista(dynamic raw, String origen) {
    if (raw is List) return JsonGuard.toListOfMaps(raw);
    if (raw is String) return JsonGuard.safeListOfMaps(raw, source: origen);
    return const [];
  }

  /// Traduce el sobre {error, code} del backend a ModuloResultado.
  ModuloResultado<List<Map<String, dynamic>>> _leerLista(
    Map<String, dynamic> res,
    String clave,
    String origen,
  ) {
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(_lista(res[clave], origen));
  }

  ModuloResultado<T> _fallo<T>(Map<String, dynamic> res) {
    final code = res['code']?.toString() ?? '';
    final msg = res['error']?.toString() ?? 'Error desconocido';
    final sinRed = res['networkError'] == true || res['timeoutError'] == true || res['httpError'] == true;
    return ModuloResultado.fallido(
      msg,
      planLimitado: code == 'PLAN_LIMIT' || code == 'TRIAL_EXPIRED',
      sinConexion: sinRed,
    );
  }

  String mensajeError(ModuloResultado r) {
    if (r.error == null) return '';
    if (r.planLimitado) {
      return 'Este módulo no está incluido en tu plan actual. '
          'Pídeselo a tu administrador o mejora tu plan para activarlo.';
    }
    if (r.sinConexion) {
      return '${r.error} Tus datos siguen guardados; no perderás nada al reintentar.';
    }
    return r.error!;
  }

  // ═══════════════════════════════════════════════════════════
  // CONTABILIDAD — feature operacion_completa
  // ═══════════════════════════════════════════════════════════

  Future<ModuloResultado<List<Map<String, dynamic>>>> cuentas() async {
    final res = _map(await _api.get('/api/contabilidad/cuentas'), 'contabilidad/cuentas');
    return _leerLista(res, 'cuentas', 'contabilidad/cuentas');
  }

  Future<ModuloResultado<bool>> sembrarPlanCuentas() async {
    final res = _map(await _api.post('/api/contabilidad/plan-cuentas/sembrar'), 'contabilidad/sembrar');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> crearCuenta(Map<String, dynamic> cuenta) async {
    final res = _map(await _api.post('/api/contabilidad/cuentas', body: {'cuenta': cuenta}), 'contabilidad/crearCuenta');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarCuenta(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/contabilidad/cuentas/$id', body: cambios), 'contabilidad/actualizarCuenta');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarCuenta(String id) async {
    final res = _map(await _api.delete('/api/contabilidad/cuentas/$id'), 'contabilidad/eliminarCuenta');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  /// Estado de resultados derivado de las transacciones REALES.
  Future<ModuloResultado<Map<String, dynamic>>> estadoResultados({String? periodo}) async {
    final res = _map(
      await _api.get('/api/contabilidad/estado-resultados', queryParams: {if (periodo != null) 'periodo': periodo}),
      'contabilidad/estadoResultados',
    );
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> asientos({String? periodo}) async {
    final res = _map(
      await _api.get('/api/contabilidad/asientos', queryParams: {if (periodo != null) 'periodo': periodo}),
      'contabilidad/asientos',
    );
    return _leerLista(res, 'asientos', 'contabilidad/asientos');
  }

  /// El backend rechaza el asiento si debe != haber.
  Future<ModuloResultado<bool>> crearAsiento(Map<String, dynamic> asiento) async {
    final res = _map(await _api.post('/api/contabilidad/asientos', body: {'asiento': asiento}), 'contabilidad/crearAsiento');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarAsiento(String id) async {
    final res = _map(await _api.delete('/api/contabilidad/asientos/$id'), 'contabilidad/eliminarAsiento');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> cierres({String? periodo}) async {
    final res = _map(
      await _api.get('/api/contabilidad/cierres', queryParams: {if (periodo != null) 'periodo': periodo}),
      'contabilidad/cierres',
    );
    return _leerLista(res, 'cierres', 'contabilidad/cierres');
  }

  Future<ModuloResultado<bool>> guardarCierre(Map<String, dynamic> cierre) async {
    final res = _map(await _api.post('/api/contabilidad/cierres', body: {'cierre': cierre}), 'contabilidad/guardarCierre');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> cerrarPeriodo(String periodo, {String? notas}) async {
    final res = _map(
      await _api.post('/api/contabilidad/cierres', body: {
        'cierre': {'periodo': periodo, 'estado': 'cerrado', 'notas': notas}
      }),
      'contabilidad/cerrarPeriodo',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> conciliaciones({String? periodo}) async {
    final res = _map(
      await _api.get('/api/contabilidad/conciliaciones', queryParams: {if (periodo != null) 'periodo': periodo}),
      'contabilidad/conciliaciones',
    );
    return _leerLista(res, 'conciliaciones', 'contabilidad/conciliaciones');
  }

  Future<ModuloResultado<bool>> guardarConciliacion(Map<String, dynamic> c) async {
    final res = _map(
      await _api.post('/api/contabilidad/conciliaciones', body: {'conciliacion': c}),
      'contabilidad/guardarConciliacion',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> marcarConciliada(String id, {String? por}) async {
    final res = _map(
      await _api.put('/api/contabilidad/conciliaciones/$id', body: {'estado': 'conciliada', 'conciliado_por': por}),
      'contabilidad/marcarConciliada',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  /// Configuración de impuestos (reemplaza el prefs 'impuestos_config').
  Future<ModuloResultado<Map<String, dynamic>>> configImpuestos() async {
    final res = _map(await _api.get('/api/contabilidad/config-impuestos'), 'contabilidad/configImpuestos');
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(_map(res['config'], 'contabilidad/configImpuestos.config'));
  }

  Future<ModuloResultado<bool>> guardarConfigImpuestos(Map<String, dynamic> config) async {
    final res = _map(
      await _api.put('/api/contabilidad/config-impuestos', body: {'config': config}),
      'contabilidad/guardarConfigImpuestos',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  // ═══════════════════════════════════════════════════════════
  // RRHH — feature rrhh_planillas
  // ═══════════════════════════════════════════════════════════

  Future<ModuloResultado<List<Map<String, dynamic>>>> empleados() async {
    final res = _map(await _api.get('/api/rrhh/empleados'), 'rrhh/empleados');
    return _leerLista(res, 'empleados', 'rrhh/empleados');
  }

  Future<ModuloResultado<bool>> guardarEmpleado(Map<String, dynamic> e) async {
    final res = _map(await _api.post('/api/rrhh/empleados', body: {'empleado': e}), 'rrhh/guardarEmpleado');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarEmpleado(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/rrhh/empleados/$id', body: cambios), 'rrhh/actualizarEmpleado');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarEmpleado(String id) async {
    final res = _map(await _api.delete('/api/rrhh/empleados/$id'), 'rrhh/eliminarEmpleado');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<Map<String, dynamic>>> nomina({required int anio, required int mes}) async {
    final res = _map(
      await _api.get('/api/rrhh/nomina', queryParams: {'anio': '$anio', 'mes': '$mes'}),
      'rrhh/nomina',
    );
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  /// Calcula y PERSISTE la nómina del periodo en el servidor.
  Future<ModuloResultado<Map<String, dynamic>>> calcularNomina({required int anio, required int mes}) async {
    final res = _map(
      await _api.post('/api/rrhh/nomina/calcular', body: {'anio': anio, 'mes': mes}),
      'rrhh/calcularNomina',
    );
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  Future<ModuloResultado<bool>> pagarRecibo(String id) async {
    final res = _map(await _api.put('/api/rrhh/nomina/$id/pagar'), 'rrhh/pagarRecibo');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<Map<String, dynamic>>> recibo(String empleadoId, {required int anio, required int mes}) async {
    final res = _map(
      await _api.get('/api/rrhh/recibo/$empleadoId', queryParams: {'anio': '$anio', 'mes': '$mes'}),
      'rrhh/recibo',
    );
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(_map(res['recibo'], 'rrhh/recibo.data'));
  }

  // ═══════════════════════════════════════════════════════════
  // FISCAL_ADVANCED — feature fiscal_avanzado
  // ═══════════════════════════════════════════════════════════

  Future<ModuloResultado<List<Map<String, dynamic>>>> retenciones({String? periodo, String? tipo}) async {
    final res = _map(
      await _api.get('/api/fiscal/retenciones', queryParams: {
        if (periodo != null) 'periodo_fiscal': periodo,
        if (tipo != null) 'tipo': tipo,
      }),
      'fiscal/retenciones',
    );
    return _leerLista(res, 'retenciones', 'fiscal/retenciones');
  }

  Future<ModuloResultado<bool>> guardarRetencion(Map<String, dynamic> r) async {
    final res = _map(await _api.post('/api/fiscal/retenciones', body: {'retencion': r}), 'fiscal/guardarRetencion');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarRetencion(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/fiscal/retenciones/$id', body: cambios), 'fiscal/actualizarRetencion');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarRetencion(String id) async {
    final res = _map(await _api.delete('/api/fiscal/retenciones/$id'), 'fiscal/eliminarRetencion');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<Map<String, dynamic>>> resumenRetenciones() async {
    final res = _map(await _api.get('/api/fiscal/retenciones-resumen'), 'fiscal/resumenRetenciones');
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> libros({String? periodo}) async {
    final res = _map(
      await _api.get('/api/fiscal/libros', queryParams: {if (periodo != null) 'periodo': periodo}),
      'fiscal/libros',
    );
    return _leerLista(res, 'libros', 'fiscal/libros');
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> documentosSar({String? estado}) async {
    final res = _map(
      await _api.get('/api/fiscal/documentos-sar', queryParams: {if (estado != null) 'estado_sar': estado}),
      'fiscal/documentosSar',
    );
    return _leerLista(res, 'documentos', 'fiscal/documentosSar');
  }

  Future<ModuloResultado<bool>> guardarDocumentoSar(Map<String, dynamic> d) async {
    final res = _map(
      await _api.post('/api/fiscal/documentos-sar', body: {'documento': d}),
      'fiscal/guardarDocumentoSar',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> marcarDocumentoSar(String id, String estado, {String? respuesta}) async {
    final res = _map(
      await _api.put('/api/fiscal/documentos-sar/$id', body: {'estado_sar': estado, 'respuesta_sar': respuesta}),
      'fiscal/marcarDocumentoSar',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  // ═══════════════════════════════════════════════════════════
  // CRM_ADVANCED — feature crm_avanzado
  // ═══════════════════════════════════════════════════════════

  Future<ModuloResultado<List<Map<String, dynamic>>>> leads({String? etapa}) async {
    final res = _map(
      await _api.get('/api/crm-avanzado/leads', queryParams: {if (etapa != null) 'etapa': etapa}),
      'crm/leads',
    );
    return _leerLista(res, 'leads', 'crm/leads');
  }

  Future<ModuloResultado<bool>> guardarLead(Map<String, dynamic> l) async {
    final res = _map(await _api.post('/api/crm-avanzado/leads', body: {'lead': l}), 'crm/guardarLead');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarLead(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/crm-avanzado/leads/$id', body: cambios), 'crm/actualizarLead');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarLead(String id) async {
    final res = _map(await _api.delete('/api/crm-avanzado/leads/$id'), 'crm/eliminarLead');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<Map<String, dynamic>>> pipeline() async {
    final res = _map(await _api.get('/api/crm-avanzado/pipeline'), 'crm/pipeline');
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> campanas({String? estado}) async {
    final res = _map(
      await _api.get('/api/crm-avanzado/campanas', queryParams: {if (estado != null) 'estado': estado}),
      'crm/campanas',
    );
    return _leerLista(res, 'campanas', 'crm/campanas');
  }

  Future<ModuloResultado<bool>> guardarCampana(Map<String, dynamic> c) async {
    final res = _map(await _api.post('/api/crm-avanzado/campanas', body: {'campana': c}), 'crm/guardarCampana');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarCampana(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/crm-avanzado/campanas/$id', body: cambios), 'crm/actualizarCampana');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarCampana(String id) async {
    final res = _map(await _api.delete('/api/crm-avanzado/campanas/$id'), 'crm/eliminarCampana');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> segmentos() async {
    final res = _map(await _api.get('/api/crm-avanzado/segmentos'), 'crm/segmentos');
    return _leerLista(res, 'segmentos', 'crm/segmentos');
  }

  Future<ModuloResultado<bool>> guardarSegmento(Map<String, dynamic> s) async {
    final res = _map(await _api.post('/api/crm-avanzado/segmentos', body: {'segmento': s}), 'crm/guardarSegmento');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarSegmento(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/crm-avanzado/segmentos/$id', body: cambios), 'crm/actualizarSegmento');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarSegmento(String id) async {
    final res = _map(await _api.delete('/api/crm-avanzado/segmentos/$id'), 'crm/eliminarSegmento');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  /// Cuenta clientes REALES del segmento (antes era un número inventado).
  Future<ModuloResultado<Map<String, dynamic>>> calcularSegmento(String id) async {
    final res = _map(await _api.post('/api/crm-avanzado/segmentos/$id/calcular'), 'crm/calcularSegmento');
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> programas() async {
    final res = _map(await _api.get('/api/crm-avanzado/fidelizacion'), 'crm/programas');
    return _leerLista(res, 'programas', 'crm/programas');
  }

  Future<ModuloResultado<bool>> guardarPrograma(Map<String, dynamic> p) async {
    final res = _map(await _api.post('/api/crm-avanzado/fidelizacion', body: {'programa': p}), 'crm/guardarPrograma');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarPrograma(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/crm-avanzado/fidelizacion/$id', body: cambios), 'crm/actualizarPrograma');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarPrograma(String id) async {
    final res = _map(await _api.delete('/api/crm-avanzado/fidelizacion/$id'), 'crm/eliminarPrograma');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  // ═══════════════════════════════════════════════════════════
  // MULTI_EMPRESA — feature multiempresa
  // ═══════════════════════════════════════════════════════════

  Future<ModuloResultado<List<Map<String, dynamic>>>> filiales() async {
    final res = _map(await _api.get('/api/multi-empresa/filiales'), 'multi/filiales');
    return _leerLista(res, 'filiales', 'multi/filiales');
  }

  Future<ModuloResultado<bool>> guardarFilial(Map<String, dynamic> f) async {
    final res = _map(await _api.post('/api/multi-empresa/filiales', body: {'filial': f}), 'multi/guardarFilial');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> actualizarFilial(String id, Map<String, dynamic> cambios) async {
    final res = _map(await _api.put('/api/multi-empresa/filiales/$id', body: cambios), 'multi/actualizarFilial');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarFilial(String id) async {
    final res = _map(await _api.delete('/api/multi-empresa/filiales/$id'), 'multi/eliminarFilial');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> tiposCambio({String? moneda}) async {
    final res = _map(
      await _api.get('/api/multi-empresa/tipos-cambio', queryParams: {if (moneda != null) 'moneda': moneda}),
      'multi/tiposCambio',
    );
    return _leerLista(res, 'tipos_cambio', 'multi/tiposCambio');
  }

  Future<ModuloResultado<bool>> guardarTipoCambio(Map<String, dynamic> t) async {
    final res = _map(
      await _api.post('/api/multi-empresa/tipos-cambio', body: {'tipo_cambio': t}),
      'multi/guardarTipoCambio',
    );
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<bool>> eliminarTipoCambio(String id) async {
    final res = _map(await _api.delete('/api/multi-empresa/tipos-cambio/$id'), 'multi/eliminarTipoCambio');
    if (res['error'] != null) return _fallo(res);
    return const ModuloResultado.ok(true);
  }

  Future<ModuloResultado<List<Map<String, dynamic>>>> consolidados({String? periodo}) async {
    final res = _map(
      await _api.get('/api/multi-empresa/consolidado', queryParams: {if (periodo != null) 'periodo': periodo}),
      'multi/consolidados',
    );
    return _leerLista(res, 'consolidados', 'multi/consolidados');
  }

  /// Suma las transacciones reales de cada filial, ponderadas por participación.
  Future<ModuloResultado<Map<String, dynamic>>> calcularConsolidado({String? periodo}) async {
    final res = _map(
      await _api.post('/api/multi-empresa/consolidado/calcular', body: {if (periodo != null) 'periodo': periodo}),
      'multi/calcularConsolidado',
    );
    if (res['error'] != null) return _fallo(res);
    return ModuloResultado.ok(res);
  }

  /// Diagnóstico: qué features tiene el tenant activo según el servidor.
  /// Útil para mostrar el aviso de plan sin adivinar desde el cliente.
  Future<Map<String, dynamic>> diagnosticoPlan() async {
    debugPrint('[ModulosAvanzados] consultando entitlements del tenant activo');
    return _map(await _api.get('/api/tenant/me'), 'modulos/plan');
  }
}