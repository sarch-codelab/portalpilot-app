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

/// La IA devolvió un bloque JSON con una herramienta que NO existe
/// (ej. {"tool":"users"}). No se ejecuta nada: el chat debe reintentar con
/// texto normal o avisar al usuario, nunca mostrar el JSON crudo.
class ReportToolDesconocida implements Exception {
  final String tool;
  const ReportToolDesconocida(this.tool);
}

class ReportToolParser {
  ReportToolParser._();

  static final RegExp _jsonBlock = RegExp(
    r'\{[^{}]*(?:"tool"|\x27tool\x27)[^{}]*\}',
  );

  static const List<String> _verbosReporte = [
    'reporte', 'reportes', 'informe', 'informes', 'resumen', 'resumeme',
    'enliste', 'listado', 'listar', 'detalle de', 'registros de',
    'generame', 'genera', 'generar', 'hazme', 'haz un', 'dame', 'damelo',
    'muestrame', 'muéstrame', 'consulta', 'consultar', 'consultame',
    'necesito', 'quiero', 'exportar', 'exporta', 'exportame',
    'descargar', 'descarga', 'documento', 'archivo', 'pdf', 'html',
    'como van', 'cómo van',
  ];

  static const Map<String, ReportToolType> _categorias = {
    'inventario_movimientos': ReportToolType.inventarioMovimientos,
    'movimientos de inventario': ReportToolType.inventarioMovimientos,
    'kardex': ReportToolType.inventarioMovimientos,
    'movimientos': ReportToolType.inventarioMovimientos,
    'entradas y salidas': ReportToolType.inventarioMovimientos,
    'gastos': ReportToolType.gastos,
    'gasto': ReportToolType.gastos,
    'egresos': ReportToolType.gastos,
    'ventas': ReportToolType.ventas,
    'venta': ReportToolType.ventas,
    'ingresos': ReportToolType.ventas,
    'existencias': ReportToolType.stock,
    'inventario': ReportToolType.stock,
    'stock': ReportToolType.stock,
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

  /// Infiere la herramienta SOLO del mensaje del usuario (fallback por
  /// palabras, sin JSON de por medio). Útil cuando la IA insiste en devolver
  /// herramientas inexistentes tras varios reintentos.
  static ReportToolIntent? interpretarSinJson(String mensajeUsuario) {
    return _porPalabras(mensajeUsuario);
  }

  static ReportToolIntent? _porJson(String reply) {
    final m = _jsonBlock.firstMatch(reply);
    if (m == null) return null;

    final mapa = JsonGuard.tryDecodeMap(m.group(0));
    if (mapa == null || mapa.isEmpty) return null;

    final toolNombre = mapa['tool']?.toString();
    final tool = ReportToolType.fromName(toolNombre);
    if (tool == null) {
      // Herramienta inventada (p.ej. "users"): señal clara para el dispatcher
      // y el chat de que el intent falló; no es "no pediste reporte".
      throw ReportToolDesconocida(toolNombre ?? 'desconocida');
    }

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
    // Gana la clave MÁS LARGA que coincida: así "movimientos de inventario" no
    // cae en "inventario" (que es `stock`), sin depender del orden del mapa.
    for (final entry in _categorias.entries) {
      if (!low.contains(entry.key)) continue;
      if (categoria == null || entry.key.length > categoria.length) {
        categoria = entry.key;
      }
    }
    if (!tieneVerbo) return null;

    // Petición VAGA de reporte ("un reporte de lo que sea", "un reporte general",
    // "un reporte" a secas): en vez de fallar, produce el resumen financiero
    // del mes — es el reporte más completo y útil por defecto.
    if (categoria == null) {
      final vago = RegExp(
        r'lo que sea|cualquiera|general|de todo|completo|resumen general',
      ).hasMatch(low);
      if (vago) {
        return const ReportToolIntent(
          ReportToolType.resumenFinanciero,
          ReportToolParams(mes: null, anio: null),
        );
      }
      return null;
    }

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