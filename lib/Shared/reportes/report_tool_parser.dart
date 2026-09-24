// lib/Shared/reportes/report_tool_parser.dart
// Interpreta la respuesta de la IA (markdown) para detectar si el usuario
// pidió un reporte y qué herramienta ejecutar.
//
// Estrategia en dos niveles:
// 1. Bloque JSON controlado (preferido): la IA devuelve dentro del reply algo
//    como  {"tool":"gastos","periodo":"mes","mes":9,"anio":2026,...}
//    Se extrae con regex, se decodifica con JsonGuard y se mapea 1:1 a
//    ReportToolType + ReportToolParams. Es la ÚNICA vía por la que la IA
//    elige filtros.
// 2. Fallback por palabras (conservador): si no hay JSON pero el mensaje del
//    usuario contiene un verbo de reporte + una categoría conocida, se infiere
//    la herramienta SIN datos inventados. Requiere ambos grupos para disparar;
//    si es ambiguo se devuelve null (el chat responde como texto normal).

import 'package:portal_pilot_app/Shared/reportes/report_tools.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';

class ReportToolIntent {
  final ReportToolType tool;
  final ReportToolParams params;

  const ReportToolIntent(this.tool, this.params);
}

class ReportToolParser {
  ReportToolParser._();

  static final RegExp _jsonBlock = RegExp(
    r'\{[^{}]*(?:"tool"|\x27tool\x27)[^{}]*\}',
  );

  static final List<String> _verbosReporte = [
    'reporte', 'reportes', 'resumen', 'resumeme', 'enliste',
    'listado', 'detalle de', 'registros de', 'generame', 'genera',
    'como van', 'cómo van',
  ];

  static const Map<String, ReportToolType> _categorias = {
    'gastos': ReportToolType.gastos,
    'gasto': ReportToolType.gastos,
    'egresos': ReportToolType.gastos,
    'ventas': ReportToolType.ventas,
    'venta': ReportToolType.ventas,
    'ingresos': ReportToolType.ventas,
    'inventario': ReportToolType.inventarioMovimientos,
    'stock': ReportToolType.stock,
    'existencias': ReportToolType.stock,
    'compras': ReportToolType.compras,
    'compra': ReportToolType.compras,
    'adquisiciones': ReportToolType.compras,
    'clientes': ReportToolType.clientes,
    'cliente': ReportToolType.clientes,
    'directorio': ReportToolType.clientes,
    'facturacion': ReportToolType.facturacion,
    'facturación': ReportToolType.facturacion,
    'facturas': ReportToolType.facturacion,
    'cuentas por cobrar': ReportToolType.cuentasPorCobrar,
    'cuentas_por_cobrar': ReportToolType.cuentasPorCobrar,
    'fiado': ReportToolType.cuentasPorCobrar,
    'creditos': ReportToolType.cuentasPorCobrar,
    'créditos': ReportToolType.cuentasPorCobrar,
    'caja': ReportToolType.caja,
    'arqueo': ReportToolType.caja,
    'arqueos': ReportToolType.caja,
    'movimientos de caja': ReportToolType.caja,
    'resumen financiero': ReportToolType.resumenFinanciero,
    'resumen_financiero': ReportToolType.resumenFinanciero,
    'financiero': ReportToolType.resumenFinanciero,
    'utilidad': ReportToolType.resumenFinanciero,
    'empleados': ReportToolType.empleados,
    'empleado': ReportToolType.empleados,
    'nomina': ReportToolType.empleados,
    'nómina': ReportToolType.empleados,
    'planilla': ReportToolType.empleados,
  };

  /// Interpreta la respuesta de la IA. Devuelve null si no hay reporte.
  static ReportToolIntent? interpretar(String reply, {String? mensajeUsuario}) {
    final intent = _porJson(reply);
    if (intent != null) return intent;
    if (mensajeUsuario != null) return _porPalabras(mensajeUsuario);
    return null;
  }

  static ReportToolIntent? _porJson(String reply) {
    final m = _jsonBlock.firstMatch(reply);
    if (m == null) return null;

    final mapa = JsonGuard.tryDecodeMap(m.group(0));
    if (mapa == null || mapa.isEmpty) return null;

    final tool = ReportToolType.fromName(mapa['tool']?.toString());
    if (tool == null) return null;

    return ReportToolIntent(tool, _paramsDesdeMapa(mapa));
  }

  static ReportToolParams _paramsDesdeMapa(Map<String, dynamic> mapa) {
    DateTime? desde;
    DateTime? hasta;
    final periodo = mapa['periodo']?.toString().toLowerCase();

    final mes = mapa['mes'];
    final anio = mapa['anio'];
    int? m = mes is int ? mes : int.tryParse(mes?.toString() ?? '');
    int? a = anio is int ? anio : int.tryParse(anio?.toString() ?? '');

    if (periodo == 'hoy' || periodo == 'hoy mismo') {
      final now = DateTime.now();
      desde = DateTime(now.year, now.month, now.day);
      hasta = desde;
    } else if (periodo == 'semana' || periodo == 'esta semana') {
      final now = DateTime.now();
      final dias = now.weekday - DateTime.monday;
      desde = DateTime(now.year, now.month, now.day - dias);
      hasta = now;
    } else if (periodo == 'rango' || periodo == 'entre' || periodo == 'custom') {
      desde = _fechaDesdeTexto(mapa['desde']?.toString());
      hasta = _fechaDesdeTexto(mapa['hasta']?.toString());
    } else if (periodo == 'mes' || periodo == 'mensual') {
      if (m == null) {
        final now = DateTime.now();
        m = now.month;
      }
      a ??= DateTime.now().year;
      desde = _fechaDesdeTexto(mapa['desde']?.toString());
    }

    return ReportToolParams(
      desde: desde,
      hasta: hasta,
      mes: m,
      anio: a,
      categoria: mapa['categoria']?.toString(),
    );
  }

  static DateTime? _fechaDesdeTexto(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final t = raw.trim();
    // dd/MM/yyyy o dd-MM-yyyy
    final dmy = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$').firstMatch(t);
    if (dmy != null) {
      final d = int.parse(dmy.group(1)!);
      final mo = int.parse(dmy.group(2)!);
      final y = int.parse(dmy.group(3)!);
      return DateTime(y, mo, d);
    }
    // yyyy-MM-dd
    final ymd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
    if (ymd != null) {
      return DateTime(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
      );
    }
    return DateTime.tryParse(t);
  }

  /// Fallback conservador: requiere verbo de reporte Y categoría conocida.
  static ReportToolIntent? _porPalabras(String mensaje) {
    final low = mensaje.toLowerCase();
    final tieneVerbo = _verbosReporte.any(low.contains);

    String? categoria;
    for (final entry in _categorias.entries) {
      if (low.contains(entry.key)) {
        categoria = entry.key;
        break;
      }
    }
    if (!tieneVerbo || categoria == null) return null;

    ReportToolParams? params;
    // Detecta "del 01/09/2026 al 22/09/2026" o "entre dd/MM/yyyy y dd/MM/yyyy".
    final fechas = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})')
        .allMatches(mensaje)
        .map((mm) {
      return DateTime(
        int.parse(mm.group(3)!),
        int.parse(mm.group(2)!),
        int.parse(mm.group(1)!),
      );
    }).toList();
    if (low.contains('hoy')) {
      final now = DateTime.now();
      params = ReportToolParams(
          desde: DateTime(now.year, now.month, now.day),
          hasta: DateTime(now.year, now.month, now.day));
    } else if (low.contains('mes') || low.contains('mensual')) {
      params = const ReportToolParams(mes: null, anio: null);
    } else if (fechas.length >= 2) {
      params = ReportToolParams(desde: fechas[0], hasta: fechas[1]);
    }

    return ReportToolIntent(_categorias[categoria]!, params ?? const ReportToolParams());
  }

  /// Etiqueta corta usada por el chat mientras ejecuta la herramienta.
  static String sugerencia(ReportToolIntent intent) {
    return 'Generando ${intent.tool.label.toLowerCase()}...';
  }
}