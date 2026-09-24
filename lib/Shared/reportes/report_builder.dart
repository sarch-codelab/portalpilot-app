// lib/Shared/reportes/report_builder.dart
// Construcción y formato de los datos de un reporte universal.
//
// ReportBuilder es la ÚNICA capa autorizada para convertir datos reales
// (consultados por ReportTools) al esquema ReportData de reporte.html.
// No consulta datos ni los inventa: solo formatea y ensambla.

import 'package:intl/intl.dart';
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';

/// Moneda oficial de las plantillas de Portal Pilot.
const String kHnlCurrency = 'HNL — Lempira';

class ReportBuilder {
  ReportBuilder._();

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  // ── Formato de montos HNL ──────────────────────────────────────────
  static String money(num value) {
    final v = value.toDouble();
    final signo = v < 0 ? '-L' : 'L';
    final abs = v.abs();
    final formatted =
        NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2)
            .format(abs);
    return '$signo $formatted';
  }

  static String cantidad(num value) {
    final v = value.toDouble();
    return v == v.roundToDouble()
        ? v.toInt().toString()
        : NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2)
            .format(v);
  }

  // ── Formato de fechas (es-HN) ─────────────────────────────────────
  static String fecha(DateTime d) =>
      '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  static String fechaHora(DateTime d) =>
      '${fecha(d)} ${_pad(d.hour)}:${_pad(d.minute)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String periodo(DateTime? desde, DateTime? hasta) {
    if (desde == null && hasta == null) return '';
    if (desde != null && hasta != null && sameDay(desde, hasta)) return fecha(desde);
    final f = desde != null ? fecha(desde) : '...';
    final t = hasta != null ? fecha(hasta) : '...';
    return '$f — $t';
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "septiembre de 2026" o "del 01/09/2026 al 22/09/2026" para descripción.
  static String periodoLargo(DateTime? desde, DateTime? hasta) {
    if (desde != null && hasta != null && sameDay(desde, hasta)) {
      return 'el ${fecha(desde)}';
    }
    if (desde != null && hasta != null &&
        desde.year == hasta.year && desde.month == hasta.month) {
      return '${_meses[desde.month - 1]} de ${desde.year}';
    }
    final f = desde != null ? fecha(desde) : '';
    final t = hasta != null ? fecha(hasta) : '';
    if (f.isNotEmpty && t.isNotEmpty) return 'del $f al $t';
    if (f.isNotEmpty) return 'desde el $f';
    if (t.isNotEmpty) return 'hasta el $t';
    return '';
  }

  static String mesAnioRef(int? mes, int? anio) {
    final m = mes ?? DateTime.now().month;
    final a = anio ?? DateTime.now().year;
    if (m < 1 || m > 12) return '$a';
    return '${_meses[m - 1]} de $a';
  }

  // ── Ensamblado general ────────────────────────────────────────────
  /// Arma el [ReportData] inyectándose los metadatos: número, tipo, título,
  /// descripción (con periodo en lenguaje natural), rango y sello de tiempo.
  static ReportData assemble({
    required String number,
    required String tipo,
    required String titulo,
    String descripcion = '',
    required DateTime? desde,
    DateTime? hasta,
    required String companyName,
    String companyTagline = 'Business Management Platform',
    String currency = kHnlCurrency,
    List<ReportKpi> kpis = const [],
    String kpiCaption = '',
    List<ReportSummaryItem> summary = const [],
    List<ReportColumn> columns = const [],
    List<Map<String, dynamic>> rows = const [],
    String tableTitle = 'Detalle',
    String tableCaption = '',
    String totalLabel = 'Total',
    String? totalValue,
    String note = '',
    bool noData = false,
    DateTime? generaEn,
  }) {
    final ahora = generaEn ?? DateTime.now();
    final periodoText =
        ReportBuilder.periodo(desde, hasta);
    final parteP = ReportBuilder.periodoLargo(desde, hasta);
    final desc = descripcion.isNotEmpty
        ? descripcion
        : (parteP.isNotEmpty ? 'Información registrada $parteP.' : '');

    return ReportData(
      company: ReportCompany(
        name: companyName.isEmpty ? 'Portal Pilot' : companyName,
        tagline: companyTagline,
      ),
      report: ReportMeta(
        number: number,
        type: tipo,
        title: titulo,
        description: desc,
        period: periodoText,
        generatedAt: ReportBuilder.fechaHora(ahora),
        currency: currency,
      ),
      kpis: kpis,
      kpiCaption: kpiCaption,
      summary: summary,
      table: tableTitle.isEmpty && columns.isEmpty
          ? const ReportTable()
          : ReportTable(
              title: tableTitle,
              caption: tableCaption,
              columns: columns,
              rows: rows,
              totalLabel: totalLabel,
              totalValue: totalValue ?? '',
            ),
      note: note,
      noData: noData,
    );
  }

  /// Convierte una fila de datos cruda a la fila JSON que espera la tabla.
  static Map<String, dynamic> fila(List<ReportColumn> columns,
      Map<String, dynamic> valores) {
    final out = <String, dynamic>{};
    for (final c in columns) {
      out[c.key] = valores[c.key]?.toString() ?? '';
    }
    return out;
  }
}