// lib/Shared/reportes/report_models.dart
// Modelos de datos del sistema universal de reportes de Portal Pilot.
//
// Estas clases son el ESQUEMA oficial que se alimenta a `reporte.html`
// (plantilla universal). Cada campo mapea 1:1 con el contrato JSON que lee
// la plantilla vía `window.PORTAL_PILOT_REPORT` (ver reporte.html).
//
// REGLAS (impuestas por la plantilla y por seguridad):
// - Los bloques son OPCIONALES: si un bloque viene vacío o ausente, la
//   plantilla no lo muestra.
// - La app/IA JAMÁS inventa registros, totales o datos: solo se llenan con
//   datos reales consultados a la base local del tenant autenticado.
// - La IA no genera HTML ni SQL: solo produce parámetros de herramienta
//   (ReportToolType + filtros) y los datos los arma ReportBuilder con la
//   capa de acceso (ReportDataProvider).

/// Empresa emisora (cabecera / marca del reporte).
class ReportCompany {
  final String name;
  final String logo;
  final String tagline;

  const ReportCompany({
    this.name = 'Portal Pilot',
    this.logo = '',
    this.tagline = 'Business Management Platform',
  });

  ReportCompany copyWith({String? name, String? logo, String? tagline}) =>
      ReportCompany(
        name: name ?? this.name,
        logo: logo ?? this.logo,
        tagline: tagline ?? this.tagline,
      );

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        if (logo.isNotEmpty) 'logo': logo,
        if (tagline.isNotEmpty) 'tagline': tagline,
      };

  factory ReportCompany.fromJson(Map<String, dynamic> json) => ReportCompany(
        name: json['name']?.toString() ?? 'Portal Pilot',
        logo: json['logo']?.toString() ?? '',
        tagline: json['tagline']?.toString() ?? 'Business Management Platform',
      );
}

/// Metadatos del documento (bloque "report" de reporte.html).
class ReportMeta {
  final String number;
  final String type;
  final String title;
  final String description;
  final String period;
  final String generatedAt;
  final String currency;

  const ReportMeta({
    this.number = 'REP-000001',
    this.type = 'Reporte empresarial',
    this.title = 'Reporte empresarial',
    this.description = '',
    this.period = '',
    this.generatedAt = '',
    this.currency = 'HNL — Lempira',
  });

  ReportMeta copyWith({
    String? number,
    String? type,
    String? title,
    String? description,
    String? period,
    String? generatedAt,
    String? currency,
  }) =>
      ReportMeta(
        number: number ?? this.number,
        type: type ?? this.type,
        title: title ?? this.title,
        description: description ?? this.description,
        period: period ?? this.period,
        generatedAt: generatedAt ?? this.generatedAt,
        currency: currency ?? this.currency,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'type': type,
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (period.isNotEmpty) 'period': period,
        'generatedAt': generatedAt,
        'currency': currency,
      };

  factory ReportMeta.fromJson(Map<String, dynamic> json) => ReportMeta(
        number: json['number']?.toString() ?? 'REP-000001',
        type: json['type']?.toString() ?? 'Reporte empresarial',
        title: json['title']?.toString() ?? 'Reporte empresarial',
        description: json['description']?.toString() ?? '',
        period: json['period']?.toString() ?? '',
        generatedAt: json['generatedAt']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'HNL — Lempira',
      );
}

/// Tarjeta KPI del bloque "kpis".
class ReportKpi {
  final String label;
  final String value;
  final String detail;

  const ReportKpi({required this.label, required this.value, this.detail = ''});

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        if (detail.isNotEmpty) 'detail': detail,
      };

  factory ReportKpi.fromJson(Map<String, dynamic> json) => ReportKpi(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
      );
}

/// Elemento del bloque "summary" (información general).
class ReportSummaryItem {
  final String label;
  final String value;

  const ReportSummaryItem({required this.label, required this.value});

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  factory ReportSummaryItem.fromJson(Map<String, dynamic> json) =>
      ReportSummaryItem(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
}

/// Columna del bloque "table.columns".
class ReportColumn {
  final String key;
  final String label;
  final String align; // 'left' | 'right' | 'center'

  const ReportColumn({required this.key, required this.label, this.align = 'left'});

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (align != 'left') 'align': align,
      };

  factory ReportColumn.fromJson(Map<String, dynamic> json) => ReportColumn(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? json['key']?.toString() ?? '',
        align: json['align']?.toString() ?? 'left',
      );
}

/// Bloque "table" de reporte.html.
class ReportTable {
  final String title;
  final String caption;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final String totalLabel;
  final String totalValue;

  const ReportTable({
    this.title = 'Detalle',
    this.caption = '',
    this.columns = const [],
    this.rows = const [],
    this.totalLabel = 'Total',
    this.totalValue = '',
  });

  bool get isEmpty => rows.isEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        if (caption.isNotEmpty) 'caption': caption,
        'columns': columns.map((c) => c.toJson()).toList(),
        'rows': rows,
        if (totalValue.isNotEmpty)
          'total': {'label': totalLabel, 'value': totalValue},
      };

  factory ReportTable.fromJson(Map<String, dynamic> json) => ReportTable(
        title: json['title']?.toString() ?? 'Detalle',
        caption: json['caption']?.toString() ?? '',
        columns: (json['columns'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => ReportColumn.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
        totalLabel: (json['total'] is Map)
            ? ((json['total'] as Map)['label']?.toString() ?? 'Total')
            : 'Total',
        totalValue: (json['total'] is Map)
            ? ((json['total'] as Map)['value']?.toString() ?? '')
            : '',
      );
}

/// Documento de reporte completo: lo que se inyecta a reporte.html y lo que
/// consume el ReportViewer y el generador de PDF.
class ReportData {
  final ReportCompany company;
  final ReportMeta report;
  final List<ReportKpi> kpis;
  final String kpiCaption;
  final List<ReportSummaryItem> summary;
  final ReportTable table;
  final String note;

  /// true cuando la consulta devolvió cero registros reales: la UI no debe
  /// presentar un documento (marker para "No se encontraron datos...").
  final bool noData;

  const ReportData({
    this.company = const ReportCompany(),
    this.report = const ReportMeta(),
    this.kpis = const [],
    this.kpiCaption = '',
    this.summary = const [],
    this.table = const ReportTable(),
    this.note = '',
    this.noData = false,
  });

  Map<String, dynamic> toJson() => {
        'company': company.toJson(),
        'report': report.toJson(),
        if (kpis.isNotEmpty) 'kpis': kpis.map((k) => k.toJson()).toList(),
        if (kpiCaption.isNotEmpty) 'kpiCaption': kpiCaption,
        if (summary.isNotEmpty)
          'summary': summary.map((s) => s.toJson()).toList(),
        if (table.columns.isNotEmpty || table.rows.isNotEmpty)
          'table': table.toJson(),
        if (note.isNotEmpty) 'note': note,
      };

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
        company: json['company'] is Map
            ? ReportCompany.fromJson(Map<String, dynamic>.from(json['company']))
            : const ReportCompany(),
        report: json['report'] is Map
            ? ReportMeta.fromJson(Map<String, dynamic>.from(json['report']))
            : const ReportMeta(),
        kpis: (json['kpis'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => ReportKpi.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        kpiCaption: json['kpiCaption']?.toString() ?? '',
        summary: (json['summary'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => ReportSummaryItem.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        table: json['table'] is Map
            ? ReportTable.fromJson(Map<String, dynamic>.from(json['table']))
            : const ReportTable(),
        note: json['note']?.toString() ?? '',
        noData: json['noData'] == true,
      );
}