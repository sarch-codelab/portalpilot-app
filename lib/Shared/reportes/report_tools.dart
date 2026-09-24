// lib/Shared/reportes/report_tools.dart
// Herramientas CONTROLADAS que la IA puede invocar para generar reportes.
//
// Principios de seguridad (no negociables):
// 1. La IA NUNCA produce SQL ni HTML: solo selecciona una herramienta y
//    filtros (ReportToolParams) con valores acotados.
// 2. El tenant (empresaId) SIEMPRE se toma de la sesión autenticada
//    (AuthController / AIManager), NUNCA del texto de la IA.
// 3. Permisos: solo roles con 'reportes' (NaviRules.puedeAccederA).
// 4. Los datos provienen de la base local vía ReportDataProvider (siempre
//    filtrado por empresaId). Si no hay datos reales se marca `noData`; la
//    app NUNCA inventa registros ni totales.

import 'package:portal_pilot_app/Shared/reportes/report_builder.dart';
import 'package:portal_pilot_app/Shared/reportes/report_data_provider.dart';
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/navi_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipos de herramientas de reporte disponibles para la IA (lista cerrada).
enum ReportToolType {
  gastos,
  ventas,
  inventarioMovimientos,
  stock,
  compras,
  clientes,
  facturacion,
  cuentasPorCobrar,
  caja,
  resumenFinanciero,
  empleados;

  static ReportToolType? fromName(String? name) {
    if (name == null) return null;
    final n = name.toLowerCase().trim();
    if (['gastos', 'gasto', 'egresos', 'egreso'].contains(n)) return gastos;
    if (['ventas', 'venta', 'ingresos', 'ingreso'].contains(n)) {
      return ventas;
    }
    if (['movimientos', 'entradas_salidas', 'entradas y salidas',
            'inventario_movimientos', 'inventario']
        .contains(n)) {
      return inventarioMovimientos;
    }
    if (['stock', 'inventario_actual', 'existencias'].contains(n)) return stock;
    if (['compras', 'compra', 'adquisiciones', 'compras_realizadas']
        .contains(n)) {
      return compras;
    }
    if (['clientes', 'cliente', 'directorio', 'lista_clientes'].contains(n)) {
      return clientes;
    }
    if (['facturacion', 'facturación', 'facturas', 'facturas_emitidas',
            'facturacion_sar', 'ventas_facturadas']
        .contains(n)) {
      return facturacion;
    }
    if (['cuentas_por_cobrar', 'cuentas por cobrar', 'cxc', 'fiado',
            'creditos', 'créditos', 'pendientes_de_cobro']
        .contains(n)) {
      return cuentasPorCobrar;
    }
    if (['caja', 'arqueo', 'arqueos', 'movimientos_caja', 'cuadre_caja',
            'arqueos_caja']
        .contains(n)) {
      return caja;
    }
    if (['resumen_financiero', 'resumen financiero', 'financiero',
            'estado_financiero', 'utilidad', 'estado de resultados',
            'balance']
        .contains(n)) {
      return resumenFinanciero;
    }
    if (['empleados', 'empleado', 'personal', 'nomina', 'nómina',
            'planilla']
        .contains(n)) {
      return empleados;
    }
    return null;
  }

  String get label {
    switch (this) {
      case gastos:
        return 'Reporte de gastos';
      case ventas:
        return 'Reporte de ventas';
      case inventarioMovimientos:
        return 'Entradas y salidas de inventario';
      case stock:
        return 'Inventario actual (stock)';
      case compras:
        return 'Reporte de compras';
      case clientes:
        return 'Reporte de clientes';
      case facturacion:
        return 'Reporte de facturación';
      case cuentasPorCobrar:
        return 'Cuentas por cobrar (fiado)';
      case caja:
        return 'Movimientos de caja';
      case resumenFinanciero:
        return 'Resumen financiero';
      case empleados:
        return 'Reporte de empleados';
    }
  }

  /// Nombre corto seguro para nombres de archivo (ver ReportService).
  String get labelArchivo {
    switch (this) {
      case gastos:
        return 'Gastos';
      case ventas:
        return 'Ventas';
      case inventarioMovimientos:
        return 'Entradas_Salidas_Inventario';
      case stock:
        return 'Inventario';
      case compras:
        return 'Compras';
      case clientes:
        return 'Clientes';
      case facturacion:
        return 'Facturacion';
      case cuentasPorCobrar:
        return 'Cuentas_Por_Cobrar';
      case caja:
        return 'Movimientos_Caja';
      case resumenFinanciero:
        return 'Resumen_Financiero';
      case empleados:
        return 'Empleados';
    }
  }
}

/// Parámetros acotados que recibe una herramienta de reporte.
/// La IA puede enviar `periodo` ("mes", "hoy", "semana", "rango"), mes/año,
/// un rango `desde`/`hasta` en dd/MM/yyyy y una categoría opcional.
class ReportToolParams {
  final DateTime? desde;
  final DateTime? hasta;
  final int? mes;
  final int? anio;
  final String? categoria;

  const ReportToolParams({
    this.desde,
    this.hasta,
    this.mes,
    this.anio,
    this.categoria,
  });

  /// Rango efectivo: usa desde/hasta si vienen; si no, mes/año; si no, el mes
  /// en curso (default de la IA).
  (DateTime, DateTime) rangoEfectivo() {
    final now = DateTime.now();
    if (desde != null && hasta != null) {
      return (
        DateTime(desde!.year, desde!.month, desde!.day),
        DateTime(hasta!.year, hasta!.month, hasta!.day, 23, 59, 59),
      );
    }
    if (desde != null) {
      final h = now;
      return (
        DateTime(desde!.year, desde!.month, desde!.day),
        DateTime(h.year, h.month, h.day, 23, 59, 59),
      );
    }
    final m = mes ?? now.month;
    final a = anio ?? now.year;
    return (DateTime(a, m, 1), DateTime(a, m + 1, 0, 23, 59, 59));
  }
}

/// Resultado de ejecutar una herramienta de reporte.
class ReportToolResult {
  final ReportToolType tool;
  final ReportToolParams params;
  final ReportData data;
  final int registros;

  const ReportToolResult({
    required this.tool,
    required this.params,
    required this.data,
    required this.registros,
  });

  bool get noData => data.noData;

  /// Resumen textual para mostrar en el chat.
  String get mensaje {
    if (noData) {
      return 'No se encontraron datos para el periodo solicitado. '
          'Verifica que existan movimientos registrados en la plataforma.';
    }
    final total = data.table.totalValue;
    return '${tool.label} listo: $registros registro(s).'
        '${total.isNotEmpty ? ' Total: $total.' : ''} '
        'Abre el visor para verlo, imprimirlo o guardarlo.';
  }
}

class ReportPermissionException implements Exception {
  final String message;
  const ReportPermissionException(this.message);
}

class ReportToolException implements Exception {
  final String message;
  const ReportToolException(this.message);
}

/// Fuente de contexto de sesión (permite tests herméticos).
class AuthContextSource {
  final String empresaId;
  final String rol;
  final String empresaNombre;

  const AuthContextSource({
    required this.empresaId,
    required this.rol,
    this.empresaNombre = '',
  });
}

/// Clave del contador de correlativos de reportes (SharedPreferences).
const String kCorrelativoKey = 'reportes_correlativo';

/// Despachador de herramientas de reporte.
class ReportToolDispatcher {
  final ReportDataProvider provider;

  /// Si es nulo, la sesión se lee de AuthController / AIManager.
  final AuthContextSource? authSource;

  /// Fuente del correlativo del reporte (REP-000001…). Se puede inyectar en
  /// tests; por defecto usa un contador persistido en SharedPreferences.
  final Future<String> Function() correlativoProvider;

  ReportToolDispatcher({
    required this.provider,
    this.authSource,
    Future<String> Function()? correlativoProvider,
  }) : correlativoProvider = correlativoProvider ?? _correlativoPrefs;

  factory ReportToolDispatcher.local() =>
      ReportToolDispatcher(provider: ReportDataProviderDrift());

  static final ReportToolDispatcher instance = ReportToolDispatcher.local();

  /// Detecta automáticamente según la sesión (misma lógica que EventBusRoot).
  static Future<String> _correlativoPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getInt(kCorrelativoKey) ?? 0;
    final next = n + 1;
    await prefs.setInt(kCorrelativoKey, next);
    return 'REP-${next.toString().padLeft(6, '0')}';
  }

  // ── Contexto de sesión ──────────────────────────────────────────
  String _empresaId() {
    if (authSource != null) return authSource!.empresaId;
    final code = AuthController.instance.empresaCodigo.trim();
    if (code.isNotEmpty && AuthController.instance.isLoggedIn) return code;
    return AIManager.instance.empresaCodigo;
  }

  String _rol() {
    if (authSource != null) return authSource!.rol;
    // La cuenta staff/root de Portal Pilot siempre puede generar reportes,
    // sin importar cómo esté etiquetado su rol en la base de datos.
    if (AuthController.instance.esRoot) return 'admin';
    final rol = AuthController.instance.rol.trim();
    if (rol.isNotEmpty && AuthController.instance.isLoggedIn) return rol;
    return AIManager.instance.rolUsuario;
  }

  Future<String> _nombreEmpresa(String codigo) async {
    if (authSource != null && authSource!.empresaNombre.isNotEmpty) {
      return authSource!.empresaNombre;
    }
    if (AuthController.instance.empresaNombre.trim().isNotEmpty) return AuthController.instance.empresaNombre;
    final e = await provider.empresa(codigo);
    if (e != null && e.nombre.trim().isNotEmpty) return e.nombre;
    return 'Portal Pilot';
  }

  // ── Ejecución ───────────────────────────────────────────────────
  Future<ReportToolResult> execute(
    ReportToolType tool, [
    ReportToolParams params = const ReportToolParams(),
  ]) async {
    if (!NaviRules.puedeAccederA(_rol(), 'reportes')) {
      throw const ReportPermissionException(
        'Tu rol no tiene permisos para generar reportes.',
      );
    }
    final empresaId = _empresaId();
    if (empresaId.isEmpty) {
      throw const ReportToolException(
        'No hay una empresa activa en la sesión. Inicia sesión de nuevo.',
      );
    }

    switch (tool) {
      case ReportToolType.gastos:
        return _gastos(empresaId, params);
      case ReportToolType.ventas:
        return _ventas(empresaId, params);
      case ReportToolType.inventarioMovimientos:
        return _inventarioMovimientos(empresaId, params);
      case ReportToolType.stock:
        return _stock(empresaId, params);
      case ReportToolType.compras:
        return _compras(empresaId, params);
      case ReportToolType.clientes:
        return _clientes(empresaId, params);
      case ReportToolType.facturacion:
        return _facturacion(empresaId, params);
      case ReportToolType.cuentasPorCobrar:
        return _cuentasPorCobrar(empresaId, params);
      case ReportToolType.caja:
        return _caja(empresaId, params);
      case ReportToolType.resumenFinanciero:
        return _resumenFinanciero(empresaId, params);
      case ReportToolType.empleados:
        return _empleados(empresaId, params);
    }
  }

  ReportData _noData({
    required String number,
    required String toolLabel,
    required DateTime? desde,
    required DateTime? hasta,
    required String empresaNombre,
  }) {
    return ReportBuilder.assemble(
      number: number,
      tipo: toolLabel,
      titulo: toolLabel,
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      noData: true,
    );
  }

  // ── GASTOS ───────────────────────────────────────────────────────
  static const List<String> _tiposIngreso = [
    'ingreso', 'ingresos', 'venta', 'ventas',
    'entrada', 'entradas', 'abono', 'abonos',
    'credito', 'crédito', 'membresia', 'membresías',
  ];

  static bool _esGasto(String tipo) {
    final t = tipo.toLowerCase().trim();
    if (t.isEmpty) return false;
    return !_tiposIngreso.contains(t);
  }

  static bool _enRango(DateTime f, DateTime inicio, DateTime fin) {
    final d = DateTime(f.year, f.month, f.day);
    return !d.isBefore(inicio) && !d.isAfter(fin);
  }

  Future<ReportToolResult> _gastos(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();
    final tx = await provider.transacciones(empresaId);
    final gastos = tx
        .where((t) => _esGasto(t.tipo) && _enRango(t.fecha, desde, hasta))
        .toList();
    final number = await correlativoProvider();

    if (gastos.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.gastos,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.gastos.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    gastos.sort((a, b) => b.fecha.compareTo(a.fecha));
    final total = gastos.fold<double>(0, (s, t) => s + t.monto);
    final n = gastos.length;
    final promedio = total / n;
    final mayor = gastos.reduce((a, b) => a.monto >= b.monto ? a : b);

    final porCategoria = <String, double>{};
    final porMetodo = <String, double>{};
    for (final t in gastos) {
      final cat = t.categoria?.trim().isNotEmpty == true
          ? t.categoria!.trim()
          : 'General';
      final met = t.metodoPago?.trim().isNotEmpty == true
          ? t.metodoPago!.trim()
          : 'No especificado';
      porCategoria[cat] = (porCategoria[cat] ?? 0) + t.monto;
      porMetodo[met] = (porMetodo[met] ?? 0) + t.monto;
    }
    final catPrincipal = _mayorClave(porCategoria);
    final metodoPrincipal = _mayorClave(porMetodo);

    const columns = [
      ReportColumn(key: 'fecha', label: 'Fecha'),
      ReportColumn(key: 'concepto', label: 'Concepto'),
      ReportColumn(key: 'categoria', label: 'Categoría'),
      ReportColumn(key: 'metodo', label: 'Método'),
      ReportColumn(key: 'monto', label: 'Monto', align: 'right'),
    ];
    final rows = gastos.map((t) {
      return ReportBuilder.fila(columns, {
        'fecha': ReportBuilder.fecha(t.fecha),
        'concepto': t.descripcion?.trim().isNotEmpty == true
            ? t.descripcion!
            : 'Sin descripción',
        'categoria': t.categoria?.trim().isNotEmpty == true
            ? t.categoria!.trim()
            : 'General',
        'metodo': t.metodoPago?.trim().isNotEmpty == true
            ? t.metodoPago!.trim()
            : 'No especificado',
        'monto': ReportBuilder.money(t.monto),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.gastos.label,
      titulo: ReportToolType.gastos.label,
      descripcion:
          'Gastos registrados ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Total gastos',
            value: ReportBuilder.money(total),
            detail: '$n registros'),
        ReportKpi(
            label: 'Promedio',
            value: ReportBuilder.money(promedio),
            detail: 'por operación'),
        ReportKpi(
            label: 'Mayor gasto',
            value: ReportBuilder.money(mayor.monto),
            detail: mayor.descripcion ?? ''),
        ReportKpi(
            label: 'Método principal',
            value: metodoPrincipal.$1,
            detail: ReportBuilder.money(metodoPrincipal.$2)),
      ],
      kpiCaption: '$n registros',
      summary: [
        ReportSummaryItem(
            label: 'Categoría principal',
            value: catPrincipal.$1.isNotEmpty
                ? '${catPrincipal.$1} — ${ReportBuilder.money(catPrincipal.$2)}'
                : 'Sin datos'),
        ReportSummaryItem(
            label: 'Total del periodo', value: ReportBuilder.money(total)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Detalle de gastos',
      tableCaption: '$n registros',
      totalLabel: 'Total',
      totalValue: ReportBuilder.money(total),
      note: 'Gastos registrados manualmente o por el módulo de contabilidad. '
          'Solo se incluyen movimientos respaldados por la base de datos.',
    );

    return ReportToolResult(
        tool: ReportToolType.gastos, params: params, data: data, registros: n);
  }

  // ── VENTAS ───────────────────────────────────────────────────────
  Future<ReportToolResult> _ventas(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();

    final facturas = await provider.facturas(empresaId);
    final pos = await provider.posVentas(empresaId);

    // Filas crudas (con monto numérico) para ordenar y agregar sin errores.
    final crudas = <_VentaRaw>[];
    double iva = 0;

    for (final f in facturas) {
      if (_enRango(f.createdAt, desde, hasta)) {
        if (f.estado.toLowerCase() == 'anulada') continue;
        iva += (f.isv15 + f.isv18);
        crudas.add(_VentaRaw(
          fecha: f.createdAt,
          documento: f.correlativo.isEmpty ? 'FACT-' : f.correlativo,
          cliente: f.clienteNombre?.trim().isNotEmpty == true
              ? f.clienteNombre!
              : 'Cliente General',
          canal: 'Facturación',
          monto: f.total,
        ));
      }
    }
    for (final v in pos) {
      if (_enRango(v.createdAt, desde, hasta)) {
        if (v.estado.toLowerCase() == 'cancelada') continue;
        iva += (v.isv15 + v.isv18);
        crudas.add(_VentaRaw(
          fecha: v.createdAt,
          documento: v.correlativo?.trim().isNotEmpty == true
              ? v.correlativo!
              : 'POS',
          cliente: v.clienteNombre?.trim().isNotEmpty == true
              ? v.clienteNombre!
              : 'Consumidor Final',
          canal: 'POS',
          monto: v.total,
        ));
      }
    }
    crudas.sort((a, b) => b.fecha.compareTo(a.fecha));
    final total = crudas.fold<double>(0, (s, r) => s + r.monto);
    final n = crudas.length;
    final number = await correlativoProvider();

    if (n == 0) {
      return ReportToolResult(
        tool: ReportToolType.ventas,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.ventas.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    final promedio = total / n;
    final porCliente = <String, double>{};
    for (final r in crudas) {
      porCliente[r.cliente] = (porCliente[r.cliente] ?? 0) + r.monto;
    }
    final topCliente = _mayorClave(porCliente);

    const columns = [
      ReportColumn(key: 'fecha', label: 'Fecha'),
      ReportColumn(key: 'documento', label: 'Documento'),
      ReportColumn(key: 'cliente', label: 'Cliente'),
      ReportColumn(key: 'canal', label: 'Canal'),
      ReportColumn(key: 'monto', label: 'Monto', align: 'right'),
    ];
    final filas = crudas.map((r) {
      return ReportBuilder.fila(columns, {
        'fecha': ReportBuilder.fecha(r.fecha),
        'documento': r.documento,
        'cliente': r.cliente,
        'canal': r.canal,
        'monto': ReportBuilder.money(r.monto),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.ventas.label,
      titulo: ReportToolType.ventas.label,
      descripcion:
          'Ventas registradas ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Total ventas',
            value: ReportBuilder.money(total),
            detail: '$n documentos'),
        ReportKpi(
            label: 'Ticket promedio',
            value: ReportBuilder.money(promedio),
            detail: 'por documento'),
        ReportKpi(
            label: 'IVA generado',
            value: ReportBuilder.money(iva),
            detail: 'ISV 15% + 18%'),
        ReportKpi(
            label: 'Cliente principal',
            value: topCliente.$1.isNotEmpty ? topCliente.$1 : 'Sin datos',
            detail: topCliente.$2 > 0 ? ReportBuilder.money(topCliente.$2) : ''),
      ],
      kpiCaption: '$n documentos',
      summary: [
        ReportSummaryItem(label: 'Documentos', value: '$n'),
        ReportSummaryItem(label: 'Total del periodo', value: ReportBuilder.money(total)),
      ],
      columns: columns,
      rows: filas,
      tableTitle: 'Detalle de ventas',
      tableCaption: '$n documentos',
      totalLabel: 'Total',
      totalValue: ReportBuilder.money(total),
      note: 'Incluye facturas y ventas del POS no anuladas del periodo '
          'solicitado. Solo se usan datos reales de la empresa.',
    );

    return ReportToolResult(
        tool: ReportToolType.ventas, params: params, data: data, registros: n);
  }

  // ── INVENTARIO: entradas y salidas ───────────────────────────────
  Future<ReportToolResult> _inventarioMovimientos(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();

    final compras = await provider.compras(empresaId);
    final comprasValidas = compras
        .where((c) => !c.estado.toLowerCase().startsWith('cancel'))
        .where((c) => _enRango(c.fecha, desde, hasta))
        .toList();
    final compraIds = comprasValidas.map((c) => c.id).toList();
    final cItems = await provider.compraItems(compraIds);
    final fechaDeCompra = {for (final c in comprasValidas) c.id: c.fecha};

    final pos = await provider.posVentas(empresaId);
    final posValidas = pos
        .where((v) => !v.estado.toLowerCase().startsWith('cancel'))
        .where((v) => _enRango(v.createdAt, desde, hasta))
        .toList();
    final posIds = posValidas.map((v) => v.id).toList();
    final fechaDeVenta = {for (final v in posValidas) v.id: v.createdAt};
    final itemsSalida = await provider.posVentaItems(posIds);

    double entradas = 0;
    double salidas = 0;
    final filas = <Map<String, dynamic>>[];

    for (final i in cItems) {
      entradas += i.cantidad.toDouble();
      filas.add({
        'fecha': fechaDeCompra[i.compraId],
        'tipo': 'Entrada',
        'producto': i.productoNombre,
        'codigo': i.productoCodigo ?? '',
        'cantidad': ReportBuilder.cantidad(i.cantidad.toDouble()),
        'valor': ReportBuilder.money(i.subtotal),
      });
    }
    for (final i in itemsSalida) {
      salidas += i.cantidad.toDouble();
      filas.add({
        'fecha': fechaDeVenta[i.ventaId],
        'tipo': 'Salida',
        'producto': i.productoNombre,
        'codigo': i.productoCodigo ?? '',
        'cantidad': ReportBuilder.cantidad(i.cantidad.toDouble()),
        'valor': ReportBuilder.money(i.subtotal),
      });
    }
    filas.sort((a, b) {
      final fa = a['fecha'] as DateTime?;
      final fb = b['fecha'] as DateTime?;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fb.compareTo(fa);
    });
    for (final f in filas) {
      f['fecha'] = ReportBuilder.fecha(f['fecha'] as DateTime? ?? DateTime.now());
    }

    final n = filas.length;
    final number = await correlativoProvider();

    if (n == 0) {
      return ReportToolResult(
        tool: ReportToolType.inventarioMovimientos,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.inventarioMovimientos.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    final neto = entradas - salidas;
    const columns = [
      ReportColumn(key: 'fecha', label: 'Fecha'),
      ReportColumn(key: 'tipo', label: 'Tipo'),
      ReportColumn(key: 'producto', label: 'Producto'),
      ReportColumn(key: 'codigo', label: 'Código'),
      ReportColumn(key: 'cantidad', label: 'Cantidad', align: 'right'),
      ReportColumn(key: 'valor', label: 'Valor', align: 'right'),
    ];

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.inventarioMovimientos.label,
      titulo: ReportToolType.inventarioMovimientos.label,
      descripcion:
          'Movimientos de inventario ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Entradas',
            value: ReportBuilder.cantidad(entradas),
            detail: 'unidades'),
        ReportKpi(
            label: 'Salidas',
            value: ReportBuilder.cantidad(salidas),
            detail: 'unidades'),
        ReportKpi(
            label: 'Saldo neto',
            value: ReportBuilder.cantidad(neto),
            detail: 'unidades'),
        ReportKpi(
            label: 'Movimientos',
            value: '$n',
            detail: 'del periodo'),
      ],
      kpiCaption: '$n movimientos',
      summary: [
        ReportSummaryItem(
            label: 'Entradas', value: ReportBuilder.cantidad(entradas)),
        ReportSummaryItem(
            label: 'Salidas', value: ReportBuilder.cantidad(salidas)),
      ],
      columns: columns,
      rows: filas,
      tableTitle: 'Movimientos de inventario',
      tableCaption: '$n movimientos',
      totalLabel: 'Saldo neto',
      totalValue: ReportBuilder.cantidad(neto),
      note: 'Entradas = compras recibidas; Salidas = ventas del POS. '
          'No se inventan movimientos: solo se reportan los registrados.',
    );

    return ReportToolResult(
      tool: ReportToolType.inventarioMovimientos,
      params: params,
      data: data,
      registros: n,
    );
  }

  // ── STOCK ACTUAL ─────────────────────────────────────────────────
  Future<ReportToolResult> _stock(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final products = await provider.productos(empresaId);
    final number = await correlativoProvider();

    final activos = products.where((p) => p.activo).toList();
    if (activos.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.stock,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.stock.label,
          desde: null,
          hasta: null,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    activos.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    double unidades = 0;
    double valor = 0;
    int bajos = 0;
    for (final p in activos) {
      unidades += p.stockActual;
      valor += p.stockActual * p.precioVenta;
      if (p.stockActual <= p.stockMinimo) bajos++;
    }

    final porCategoria = <String, int>{};
    for (final p in activos) {
      final cat = p.categoria?.trim().isNotEmpty == true
          ? p.categoria!.trim()
          : 'General';
      porCategoria[cat] = (porCategoria[cat] ?? 0) + 1;
    }
    final catPrincipal = _mayorClaveInt(porCategoria);

    const columns = [
      ReportColumn(key: 'codigo', label: 'Código'),
      ReportColumn(key: 'producto', label: 'Producto'),
      ReportColumn(key: 'categoria', label: 'Categoría'),
      ReportColumn(key: 'stock', label: 'Stock', align: 'right'),
      ReportColumn(key: 'minimo', label: 'Mínimo', align: 'right'),
      ReportColumn(key: 'precio', label: 'Precio', align: 'right'),
      ReportColumn(key: 'valor', label: 'Valor', align: 'right'),
    ];
    final filas = activos.map((p) {
      return ReportBuilder.fila(columns, {
        'codigo': (p.codigo ?? '').isEmpty ? '—' : p.codigo,
        'producto': p.nombre,
        'categoria': p.categoria?.trim().isNotEmpty == true
            ? p.categoria!.trim()
            : 'General',
        'stock': ReportBuilder.cantidad(p.stockActual),
        'minimo': ReportBuilder.cantidad(p.stockMinimo),
        'precio': ReportBuilder.money(p.precioVenta),
        'valor': ReportBuilder.money(p.stockActual * p.precioVenta),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.stock.label,
      titulo: ReportToolType.stock.label,
      descripcion: 'Estado actual del inventario de la empresa.',
      desde: null,
      hasta: null,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Productos activos',
            value: '${activos.length}',
            detail: 'en catálogo'),
        ReportKpi(
            label: 'Unidades totales',
            value: ReportBuilder.cantidad(unidades),
            detail: 'en stock'),
        ReportKpi(
            label: 'Valor del inventario',
            value: ReportBuilder.money(valor),
            detail: 'a precio de venta'),
        ReportKpi(
            label: 'Productos bajo mínimo',
            value: '$bajos',
            detail: 'requieren reorden'),
      ],
      kpiCaption: '${activos.length} productos',
      summary: [
        ReportSummaryItem(
            label: 'Categoría principal',
            value: catPrincipal.$1.isNotEmpty ? catPrincipal.$1 : 'Sin datos'),
        ReportSummaryItem(
            label: 'Valor del inventario', value: ReportBuilder.money(valor)),
      ],
      columns: columns,
      rows: filas,
      tableTitle: 'Inventario actual',
      tableCaption: '${activos.length} productos',
      note: 'Stock al día de hoy a precio de venta. Los movimientos de '
          'entrada/salida se pueden consultar con el reporte correspondiente.',
    );

    return ReportToolResult(
        tool: ReportToolType.stock, params: params, data: data, registros: activos.length);
  }

  // ── COMPRAS ───────────────────────────────────────────────────────
  Future<ReportToolResult> _compras(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();
    final compras = await provider.compras(empresaId);
    final validas = compras
        .where((c) =>
            !c.estado.toLowerCase().startsWith('anul') &&
            _enRango(c.fecha, desde, hasta))
        .toList();
    final number = await correlativoProvider();

    if (validas.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.compras,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.compras.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    validas.sort((a, b) => b.fecha.compareTo(a.fecha));
    final total = validas.fold<double>(0, (s, c) => s + c.total);
    final isvTotal = validas.fold<double>(0, (s, c) => s + c.isv15 + c.isv18);
    final porProveedor = <String, double>{};
    for (final c in validas) {
      final nom = c.proveedorNombre.trim().isNotEmpty
          ? c.proveedorNombre.trim()
          : 'Proveedor general';
      porProveedor[nom] = (porProveedor[nom] ?? 0) + c.total;
    }
    final top = _mayorClave(porProveedor);

    const columns = [
      ReportColumn(key: 'fecha', label: 'Fecha'),
      ReportColumn(key: 'numero', label: 'N°'),
      ReportColumn(key: 'proveedor', label: 'Proveedor'),
      ReportColumn(key: 'factura', label: 'Factura prov.'),
      ReportColumn(key: 'estado', label: 'Estado'),
      ReportColumn(key: 'total', label: 'Total', align: 'right'),
    ];
    final rows = validas.map((c) {
      return ReportBuilder.fila(columns, {
        'fecha': ReportBuilder.fecha(c.fecha),
        'numero': (c.correlativo ?? '').isEmpty ? '—' : c.correlativo!,
        'proveedor': c.proveedorNombre.trim().isNotEmpty
            ? c.proveedorNombre.trim()
            : 'Proveedor general',
        'factura': (c.numeroFactura ?? '').isEmpty ? '—' : c.numeroFactura!,
        'estado': c.estado.trim().isEmpty ? 'registrada' : c.estado.trim(),
        'total': ReportBuilder.money(c.total),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.compras.label,
      titulo: ReportToolType.compras.label,
      descripcion:
          'Compras registradas ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Total compras',
            value: ReportBuilder.money(total),
            detail: '${validas.length} documentos'),
        ReportKpi(
            label: 'ISV en compras',
            value: ReportBuilder.money(isvTotal),
            detail: '15% + 18%'),
        ReportKpi(
            label: 'Proveedor principal',
            value: top.$1.isNotEmpty ? top.$1 : 'Sin datos',
            detail: top.$2 > 0 ? ReportBuilder.money(top.$2) : ''),
        ReportKpi(
            label: 'Documentos',
            value: '${validas.length}',
            detail: 'del periodo'),
      ],
      kpiCaption: '${validas.length} compras',
      summary: [
        ReportSummaryItem(label: 'Documentos', value: '${validas.length}'),
        ReportSummaryItem(
            label: 'Total del periodo', value: ReportBuilder.money(total)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Detalle de compras',
      tableCaption: '${validas.length} compras',
      totalLabel: 'Total',
      totalValue: ReportBuilder.money(total),
      note: 'Compras recibidas no anuladas del periodo solicitado. '
          'No se inventan montos: usan los totales reales de la base.',
    );

    return ReportToolResult(
        tool: ReportToolType.compras,
        params: params,
        data: data,
        registros: validas.length);
  }

  // ── CLIENTES ──────────────────────────────────────────────────────
  Future<ReportToolResult> _clientes(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final clientes = await provider.clientes(empresaId);
    final creditos = await provider.posClienteCredito(empresaId);
    final number = await correlativoProvider();

    if (clientes.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.clientes,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.clientes.label,
          desde: null,
          hasta: null,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    final activos = clientes.where((c) => c.activo).length;
    final saldoPorCliente = <String, double>{};
    for (final cr in creditos) {
      saldoPorCliente[cr.clienteId] = cr.saldoActual;
    }
    final cuentasFiado = creditos.where((c) => c.saldoActual > 0).length;
    final saldoTotal =
        creditos.fold<double>(0, (s, c) => s + (c.saldoActual > 0 ? c.saldoActual : 0));

    clientes.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    const columns = [
      ReportColumn(key: 'nombre', label: 'Cliente'),
      ReportColumn(key: 'rtn', label: 'RTN'),
      ReportColumn(key: 'telefono', label: 'Teléfono'),
      ReportColumn(key: 'estado', label: 'Estado'),
      ReportColumn(key: 'fiado', label: 'Saldo fiado', align: 'right'),
    ];
    final rows = clientes.map((c) {
      final saldo = saldoPorCliente[c.id] ?? 0;
      return ReportBuilder.fila(columns, {
        'nombre': c.nombre,
        'rtn': (c.rtn ?? '').isEmpty ? '—' : c.rtn!,
        'telefono': (c.telefono ?? '').isEmpty ? '—' : c.telefono!,
        'estado': c.activo ? 'Activo' : 'Inactivo',
        'fiado': saldo > 0 ? ReportBuilder.money(saldo) : '—',
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.clientes.label,
      titulo: ReportToolType.clientes.label,
      descripcion: 'Directorio de clientes de la empresa.',
      desde: null,
      hasta: null,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Total clientes',
            value: '${clientes.length}',
            detail: 'en el directorio'),
        ReportKpi(
            label: 'Activos',
            value: '$activos',
            detail: 'clientes'),
        ReportKpi(
            label: 'Con saldo fiado',
            value: '$cuentasFiado',
            detail: 'cuentas con saldo'),
        ReportKpi(
            label: 'Saldo fiado total',
            value: ReportBuilder.money(saldoTotal),
            detail: 'pendiente de cobro'),
      ],
      kpiCaption: '${clientes.length} clientes',
      summary: [
        ReportSummaryItem(label: 'Clientes activos', value: '$activos'),
        ReportSummaryItem(
            label: 'Saldo de fiado', value: ReportBuilder.money(saldoTotal)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Directorio de clientes',
      tableCaption: '${clientes.length} clientes',
      totalLabel: 'Clientes',
      totalValue: '${clientes.length}',
      note: 'Directorio de clientes con saldo de fiado cuando aplica. '
          'El saldo proviene del módulo de crédito del POS.',
    );

    return ReportToolResult(
        tool: ReportToolType.clientes,
        params: params,
        data: data,
        registros: clientes.length);
  }

  // ── FACTURACIÓN ───────────────────────────────────────────────────
  Future<ReportToolResult> _facturacion(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();
    final facturas = await provider.facturas(empresaId);
    final validas = facturas
        .where((f) =>
            f.estado.toLowerCase() != 'anulada' &&
            _enRango(f.createdAt, desde, hasta))
        .toList();
    final number = await correlativoProvider();

    if (validas.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.facturacion,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.facturacion.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    validas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = validas.fold<double>(0, (s, f) => s + f.total);
    final iva = validas.fold<double>(0, (s, f) => s + f.isv15 + f.isv18);
    final porCondicion = <String, double>{};
    for (final f in validas) {
      final cond = f.condicionPago.trim().isNotEmpty
          ? f.condicionPago.trim()
          : 'Contado';
      porCondicion[cond] = (porCondicion[cond] ?? 0) + f.total;
    }
    final condPrincipal = _mayorClave(porCondicion);

    const columns = [
      ReportColumn(key: 'fecha', label: 'Fecha'),
      ReportColumn(key: 'correlativo', label: 'Correlativo'),
      ReportColumn(key: 'cliente', label: 'Cliente'),
      ReportColumn(key: 'condicion', label: 'Condición'),
      ReportColumn(key: 'total', label: 'Total', align: 'right'),
    ];
    final rows = validas.map((f) {
      return ReportBuilder.fila(columns, {
        'fecha': ReportBuilder.fecha(f.createdAt),
        'correlativo': f.correlativo.isEmpty ? '—' : f.correlativo,
        'cliente': f.clienteNombre?.trim().isNotEmpty == true
            ? f.clienteNombre!
            : 'Cliente General',
        'condicion': f.condicionPago.trim().isNotEmpty
            ? f.condicionPago.trim()
            : 'Contado',
        'total': ReportBuilder.money(f.total),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.facturacion.label,
      titulo: ReportToolType.facturacion.label,
      descripcion:
          'Facturas emitidas ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Total facturado',
            value: ReportBuilder.money(total),
            detail: '${validas.length} facturas'),
        ReportKpi(
            label: 'ISV facturado',
            value: ReportBuilder.money(iva),
            detail: '15% + 18%'),
        ReportKpi(
            label: 'Condición principal',
            value: condPrincipal.$1.isNotEmpty ? condPrincipal.$1 : 'Contado',
            detail: ReportBuilder.money(condPrincipal.$2)),
        ReportKpi(
            label: 'Documentos',
            value: '${validas.length}',
            detail: 'emitidos'),
      ],
      kpiCaption: '${validas.length} facturas',
      summary: [
        ReportSummaryItem(label: 'Facturas', value: '${validas.length}'),
        ReportSummaryItem(
            label: 'Total del periodo', value: ReportBuilder.money(total)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Detalle de facturación',
      tableCaption: '${validas.length} facturas',
      totalLabel: 'Total',
      totalValue: ReportBuilder.money(total),
      note: 'Facturas emitidas no anuladas del periodo. '
          'No se incluyen ventas del POS.',
    );

    return ReportToolResult(
        tool: ReportToolType.facturacion,
        params: params,
        data: data,
        registros: validas.length);
  }

  // ── CUENTAS POR COBRAR (FIADO) ────────────────────────────────────
  Future<ReportToolResult> _cuentasPorCobrar(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();
    final creditos = await provider.posClienteCredito(empresaId);
    final abonos = await provider.fiadoAbonos(empresaId);
    final number = await correlativoProvider();

    final conSaldo = creditos.where((c) => c.saldoActual > 0).toList();
    if (conSaldo.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.cuentasPorCobrar,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.cuentasPorCobrar.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    final saldoTotal =
        conSaldo.fold<double>(0, (s, c) => s + c.saldoActual);
    final limiteTotal =
        creditos.fold<double>(0, (s, c) => s + c.limiteCredito);
    final abonosPeriodo = abonos
        .where((a) => _enRango(a.fecha, desde, hasta))
        .toList();
    final totalAbonos =
        abonosPeriodo.fold<double>(0, (s, a) => s + a.monto);
    final porClienteAbonos = <String, double>{};
    for (final a in abonosPeriodo) {
      final nom = a.clienteNombre?.trim().isNotEmpty == true
          ? a.clienteNombre!.trim()
          : a.clienteId;
      porClienteAbonos[nom] = (porClienteAbonos[nom] ?? 0) + a.monto;
    }
    final topAbono = _mayorClave(porClienteAbonos);

    conSaldo.sort((a, b) => b.saldoActual.compareTo(a.saldoActual));

    const columns = [
      ReportColumn(key: 'cliente', label: 'Cliente'),
      ReportColumn(key: 'saldo', label: 'Saldo', align: 'right'),
      ReportColumn(key: 'limite', label: 'Límite', align: 'right'),
      ReportColumn(key: 'dias', label: 'Días', align: 'right'),
      ReportColumn(key: 'estado', label: 'Estado'),
    ];
    final rows = conSaldo.map((c) {
      return ReportBuilder.fila(columns, {
        'cliente': c.clienteNombre?.trim().isNotEmpty == true
            ? c.clienteNombre!.trim()
            : c.clienteId,
        'saldo': ReportBuilder.money(c.saldoActual),
        'limite': ReportBuilder.money(c.limiteCredito),
        'dias': '${c.diasVencimiento}',
        'estado': c.estado.trim().isEmpty ? 'activo' : c.estado.trim(),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.cuentasPorCobrar.label,
      titulo: ReportToolType.cuentasPorCobrar.label,
      descripcion:
          'Cuentas por cobrar (fiado) ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Cartera total',
            value: ReportBuilder.money(saldoTotal),
            detail: '${conSaldo.length} cuentas'),
        ReportKpi(
            label: 'Límite total',
            value: ReportBuilder.money(limiteTotal),
            detail: 'crédito otorgado'),
        ReportKpi(
            label: 'Abonos del periodo',
            value: ReportBuilder.money(totalAbonos),
            detail: '${abonosPeriodo.length} abonos'),
        ReportKpi(
            label: 'Cliente que más abonó',
            value: topAbono.$1.isNotEmpty ? topAbono.$1 : 'Sin abonos',
            detail: topAbono.$2 > 0 ? ReportBuilder.money(topAbono.$2) : ''),
      ],
      kpiCaption: '${conSaldo.length} cuentas con saldo',
      summary: [
        ReportSummaryItem(
            label: 'Saldo total pendiente',
            value: ReportBuilder.money(saldoTotal)),
        ReportSummaryItem(
            label: 'Abonos del periodo',
            value: ReportBuilder.money(totalAbonos)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Cuentas por cobrar',
      tableCaption: '${conSaldo.length} cuentas con saldo',
      totalLabel: 'Saldo total',
      totalValue: ReportBuilder.money(saldoTotal),
      note: 'Saldos de fiado del POS (PosClienteCredito). Los abonos que '
          'cubren el saldo se consultan al historial de Canal Tradicional.',
    );

    return ReportToolResult(
        tool: ReportToolType.cuentasPorCobrar,
        params: params,
        data: data,
        registros: conSaldo.length);
  }

  // ── MOVIMIENTOS DE CAJA (ARQUEOS) ────────────────────────────────
  Future<ReportToolResult> _caja(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();
    final arqueos = await provider.arqueosCaja(empresaId);
    final number = await correlativoProvider();

    final cerrados = arqueos
        .where((a) =>
            a.fechaCierre != null &&
            _enRango(a.fechaCierre!, desde, hasta))
        .toList();
    if (cerrados.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.caja,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.caja.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    cerrados.sort((a, b) => b.fechaCierre!.compareTo(a.fechaCierre!));
    double efectivo = 0, tarjeta = 0, transferencia = 0, mixto = 0;
    double gastos = 0, diferencia = 0;
    for (final a in cerrados) {
      efectivo += a.totalVentasEfectivo;
      tarjeta += a.totalVentasTarjeta;
      transferencia += a.totalVentasTransferencia;
      mixto += a.totalVentasMixto;
      gastos += a.totalGastos;
      diferencia += a.diferencia ?? 0;
    }
    final ventasCaja = efectivo + tarjeta + transferencia + mixto;

    const columns = [
      ReportColumn(key: 'fecha', label: 'Fecha'),
      ReportColumn(key: 'efectivo', label: 'Efectivo', align: 'right'),
      ReportColumn(key: 'tarjeta', label: 'Tarjeta', align: 'right'),
      ReportColumn(key: 'transferencia', label: 'Transferencia', align: 'right'),
      ReportColumn(key: 'sistema', label: 'Sistema', align: 'right'),
      ReportColumn(key: 'diferencia', label: 'Diferencia', align: 'right'),
    ];
    final rows = cerrados.map((a) {
      final dif = a.diferencia ?? 0;
      return ReportBuilder.fila(columns, {
        'fecha': ReportBuilder.fecha(a.fechaCierre!),
        'efectivo': ReportBuilder.money(a.totalVentasEfectivo),
        'tarjeta': ReportBuilder.money(a.totalVentasTarjeta),
        'transferencia': ReportBuilder.money(a.totalVentasTransferencia),
        'sistema': ReportBuilder.money(a.sistemaTotal),
        'diferencia': ReportBuilder.money(dif),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.caja.label,
      titulo: ReportToolType.caja.label,
      descripcion:
          'Arqueos de caja cerrados ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Arqueos cerrados',
            value: '${cerrados.length}',
            detail: 'del periodo'),
        ReportKpi(
            label: 'Ventas en caja',
            value: ReportBuilder.money(ventasCaja),
            detail: 'todos los métodos'),
        ReportKpi(
            label: 'Gastos de caja',
            value: ReportBuilder.money(gastos),
            detail: 'retiros registrados'),
        ReportKpi(
            label: 'Diferencia',
            value: ReportBuilder.money(diferencia),
            detail: 'suma de sobrantes/faltantes'),
      ],
      kpiCaption: '${cerrados.length} arqueos',
      summary: [
        ReportSummaryItem(
            label: 'Efectivo', value: ReportBuilder.money(efectivo)),
        ReportSummaryItem(
            label: 'Tarjeta', value: ReportBuilder.money(tarjeta)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Arqueos de caja',
      tableCaption: '${cerrados.length} arqueos',
      totalLabel: 'Diferencia acumulada',
      totalValue: ReportBuilder.money(diferencia),
      note: 'Arqueos cerrados del módulo POS del periodo. La diferencia '
          'indica sobrantes (+) o faltantes (-) frente al sistema.',
    );

    return ReportToolResult(
        tool: ReportToolType.caja,
        params: params,
        data: data,
        registros: cerrados.length);
  }

  // ── RESUMEN FINANCIERO ────────────────────────────────────────────
  Future<ReportToolResult> _resumenFinanciero(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final (desde, hasta) = params.rangoEfectivo();

    final facturas = await provider.facturas(empresaId);
    final pos = await provider.posVentas(empresaId);
    final tx = await provider.transacciones(empresaId);

    double ventasFacturadas = 0;
    for (final f in facturas) {
      if (_enRango(f.createdAt, desde, hasta) &&
          f.estado.toLowerCase() != 'anulada') {
        ventasFacturadas += f.total;
      }
    }
    double ventasPos = 0;
    for (final v in pos) {
      if (_enRango(v.createdAt, desde, hasta) &&
          v.estado.toLowerCase() != 'cancelada') {
        ventasPos += v.total;
      }
    }
    double otrosIngresos = 0;
    for (final t in tx) {
      if (_enRango(t.fecha, desde, hasta) && !_esGasto(t.tipo)) {
        otrosIngresos += t.monto;
      }
    }
    double gastos = 0;
    for (final t in tx) {
      if (_enRango(t.fecha, desde, hasta) && _esGasto(t.tipo)) {
        gastos += t.monto;
      }
    }

    final ingresos = ventasFacturadas + ventasPos;
    final totalIngresos = ingresos + otrosIngresos;
    final utilidad = totalIngresos - gastos;
    final margen = totalIngresos > 0 ? (utilidad / totalIngresos) * 100 : 0.0;
    final number = await correlativoProvider();

    if (totalIngresos == 0 && gastos == 0) {
      return ReportToolResult(
        tool: ReportToolType.resumenFinanciero,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.resumenFinanciero.label,
          desde: desde,
          hasta: hasta,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    const columns = [
      ReportColumn(key: 'concepto', label: 'Concepto'),
      ReportColumn(key: 'monto', label: 'Monto', align: 'right'),
    ];
    final rows = [
      ReportBuilder.fila(columns, {
        'concepto': 'Ventas facturadas',
        'monto': ReportBuilder.money(ventasFacturadas),
      }),
      ReportBuilder.fila(columns, {
        'concepto': 'Ventas POS',
        'monto': ReportBuilder.money(ventasPos),
      }),
      ReportBuilder.fila(columns, {
        'concepto': 'Otros ingresos',
        'monto': ReportBuilder.money(otrosIngresos),
      }),
      ReportBuilder.fila(columns, {
        'concepto': 'Total ingresos',
        'monto': ReportBuilder.money(totalIngresos),
      }),
      ReportBuilder.fila(columns, {
        'concepto': 'Gastos del periodo',
        'monto': ReportBuilder.money(gastos),
      }),
      ReportBuilder.fila(columns, {
        'concepto': 'Utilidad neta',
        'monto': ReportBuilder.money(utilidad),
      }),
    ];

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.resumenFinanciero.label,
      titulo: ReportToolType.resumenFinanciero.label,
      descripcion:
          'Resumen financiero ${ReportBuilder.periodoLargo(desde, hasta)}.',
      desde: desde,
      hasta: hasta,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Ingresos',
            value: ReportBuilder.money(totalIngresos),
            detail: '$ingresos en ventas + $otrosIngresos otros'),
        ReportKpi(
            label: 'Gastos',
            value: ReportBuilder.money(gastos),
            detail: 'del periodo'),
        ReportKpi(
            label: 'Utilidad neta',
            value: ReportBuilder.money(utilidad),
            detail: 'ingresos - gastos'),
        ReportKpi(
            label: 'Margen',
            value: '${margen.toStringAsFixed(1)}%',
            detail: 'sobre ingresos'),
      ],
      kpiCaption: 'Periodo del resumen',
      summary: [
        ReportSummaryItem(
            label: 'Ventas facturadas', value: ReportBuilder.money(ventasFacturadas)),
        ReportSummaryItem(
            label: 'Ventas POS', value: ReportBuilder.money(ventasPos)),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Resumen financiero',
      tableCaption: 'Conceptos del periodo',
      totalLabel: 'Utilidad neta',
      totalValue: ReportBuilder.money(utilidad),
      note: 'Ingresos = facturas + POS + otros ingresos registrados. '
          'Gastos = transacciones de gasto del periodo. Datos 100% reales.',
    );

    return ReportToolResult(
        tool: ReportToolType.resumenFinanciero,
        params: params,
        data: data,
        registros: _contarRegistros(ventasFacturadas, ventasPos, otrosIngresos, gastos));
  }

  int _contarRegistros(
      double vf, double vp, double oi, double g) {
    var n = 0;
    if (vf > 0) n++;
    if (vp > 0) n++;
    if (oi > 0) n++;
    if (g > 0) n++;
    return n;
  }

  // ── EMPLEADOS ─────────────────────────────────────────────────────
  Future<ReportToolResult> _empleados(
      String empresaId, ReportToolParams params) async {
    final empresaNombre = await _nombreEmpresa(empresaId);
    final empleados = await provider.empleados(empresaId);
    final (desde, hasta) = params.rangoEfectivo();
    final number = await correlativoProvider();

    if (empleados.isEmpty) {
      return ReportToolResult(
        tool: ReportToolType.empleados,
        params: params,
        data: _noData(
          number: number,
          toolLabel: ReportToolType.empleados.label,
          desde: null,
          hasta: null,
          empresaNombre: empresaNombre,
        ),
        registros: 0,
      );
    }

    final activos = empleados.where((e) => e.estado == 'activo').toList();
    final nomina = await provider.nomina(empresaId);
    final nominaPeriodo = nomina
        .where((n) =>
            n.anio == hasta.year && n.mes == hasta.month && n.pagado)
        .toList();
    final planillaPagada =
        nominaPeriodo.fold<double>(0, (s, n) => s + n.neta);
    final costoSalarial =
        empleados.fold<double>(0, (s, e) => s + e.salarioBase);
    final porDepartamento = <String, int>{};
    for (final e in activos) {
      final dep = e.departamento?.trim().isNotEmpty == true
          ? e.departamento!.trim()
          : 'Sin departamento';
      porDepartamento[dep] = (porDepartamento[dep] ?? 0) + 1;
    }
    final depPrincipal = _mayorClaveInt(porDepartamento);

    activos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    const columns = [
      ReportColumn(key: 'nombre', label: 'Empleado'),
      ReportColumn(key: 'puesto', label: 'Puesto'),
      ReportColumn(key: 'departamento', label: 'Departamento'),
      ReportColumn(key: 'salario', label: 'Salario base', align: 'right'),
      ReportColumn(key: 'estado', label: 'Estado'),
    ];
    final rows = activos.map((e) {
      return ReportBuilder.fila(columns, {
        'nombre': e.nombre,
        'puesto': (e.puesto ?? '').isEmpty ? '—' : e.puesto!,
        'departamento': e.departamento?.trim().isNotEmpty == true
            ? e.departamento!.trim()
            : 'Sin departamento',
        'salario': ReportBuilder.money(e.salarioBase),
        'estado': e.estado.trim().isEmpty ? 'activo' : e.estado.trim(),
      });
    }).toList();

    final data = ReportBuilder.assemble(
      number: number,
      tipo: ReportToolType.empleados.label,
      titulo: ReportToolType.empleados.label,
      descripcion: 'Nómina de empleados de la empresa.',
      desde: null,
      hasta: null,
      companyName: empresaNombre,
      kpis: [
        ReportKpi(
            label: 'Empleados',
            value: '${empleados.length}',
            detail: 'en planilla'),
        ReportKpi(
            label: 'Activos',
            value: '${activos.length}',
            detail: 'empleados'),
        ReportKpi(
            label: 'Costo salarial',
            value: ReportBuilder.money(costoSalarial),
            detail: 'salarios base mensual'),
        ReportKpi(
            label: 'Planilla pagada',
            value: ReportBuilder.money(planillaPagada),
            detail: 'nómina del mes'),
      ],
      kpiCaption: '${activos.length} empleados activos',
      summary: [
        ReportSummaryItem(
            label: 'Departamento principal',
            value: depPrincipal.$1.isNotEmpty ? depPrincipal.$1 : 'Sin datos'),
        ReportSummaryItem(label: 'Activos', value: '${activos.length}'),
      ],
      columns: columns,
      rows: rows,
      tableTitle: 'Nómina de empleados',
      tableCaption: '${activos.length} empleados activos',
      totalLabel: 'Costo salarial',
      totalValue: ReportBuilder.money(costoSalarial),
      note: 'Nómina con salario base y planilla pagada del mes en curso '
          'cuando existan registros de nómina.',
    );

    return ReportToolResult(
        tool: ReportToolType.empleados,
        params: params,
        data: data,
        registros: activos.length);
  }

  // ── Helpers ──────────────────────────────────────────────────────
  static (String, double) _mayorClave(Map<String, double> map) {
    String key = '';
    double val = 0;
    map.forEach((k, v) {
      if (v > val) {
        val = v;
        key = k;
      }
    });
    return (key, val);
  }

  static (String, int) _mayorClaveInt(Map<String, int> map) {
    String key = '';
    int val = 0;
    map.forEach((k, v) {
      if (v > val) {
        val = v;
        key = k;
      }
    });
    return (key, val);
  }
}

class _VentaRaw {
  final DateTime fecha;
  final String documento;
  final String cliente;
  final String canal;
  final double monto;

  const _VentaRaw({
    required this.fecha,
    required this.documento,
    required this.cliente,
    required this.canal,
    required this.monto,
  });
}