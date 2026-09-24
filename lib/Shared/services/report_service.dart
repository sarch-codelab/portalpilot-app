// lib/Shared/services/report_service.dart
// Servicio universal de reportes de Portal Pilot.
//
// Genera el PDF A4 replicando el diseño de reporte.html (página con cabecera,
// KPIs, resumen, tabla con encabezado repetido y total), el HTML autocontenido
// (misma plantilla con window.PORTAL_PILOT_REPORT inyectado), y gestiona
// guardar / abrir / compartir / historial local.
//
// UX obligatoria: el invocador muestra "Generando reporte...", "Preparando
// PDF...", "Guardando archivo..." y "Reporte guardado correctamente." Nunca
// se muestra "Exception".

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Claves de historial (SharedPreferences).
const String kHistorialKey = 'reportes_historial';

/// Un reporte guardado en el historial (solo meta-datos, nunca PDFs).
class ReportHistorialItem {
  final String id;
  final String tipo;
  final String titulo;
  final String fecha;
  final String rutaLocal;
  final String empresaId;
  final String usuarioId;

  const ReportHistorialItem({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.fecha,
    required this.rutaLocal,
    this.empresaId = '',
    this.usuarioId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'titulo': titulo,
        'fecha': fecha,
        'ruta_local': rutaLocal,
        'empresa_id': empresaId,
        'usuario_id': usuarioId,
      };

  static ReportHistorialItem? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return ReportHistorialItem(
      id: id,
      tipo: j['tipo']?.toString() ?? '',
      titulo: j['titulo']?.toString() ?? '',
      fecha: j['fecha']?.toString() ?? '',
      rutaLocal: j['ruta_local']?.toString() ?? '',
      empresaId: j['empresa_id']?.toString() ?? '',
      usuarioId: j['usuario_id']?.toString() ?? '',
    );
  }
}

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  static const PdfColor verde = PdfColor.fromInt(0xFF10B981);
  static const PdfColor azul = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor oscuro = PdfColor.fromInt(0xFF0A0A0A);
  static const PdfColor gris = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor borde = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor fondo = PdfColor.fromInt(0xFFF9FAFB);

  // ── PDF ──────────────────────────────────────────────────────────
  static pw.MultiPage _paginas(ReportData data) {
    final meta = data.report;
    final cols = data.table.columns;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => cols.isEmpty
          ? pw.SizedBox.shrink()
          : _encabezadoTabla(cols),
      footer: (ctx) => pw.Column(
        children: [
          pw.Divider(color: borde, thickness: 0.6),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Portal Pilot — Generado por aplicación',
                  style: const pw.TextStyle(fontSize: 7, color: gris)),
              pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: gris)),
            ],
          ),
        ],
      ),
      build: (ctx) => [
        _cabecera(data),
        pw.SizedBox(height: 8),
        _meta(meta),
        pw.SizedBox(height: 10),
        if (data.kpis.isNotEmpty) ..._tarjetasKpi(data.kpis),
        if (data.kpiCaption.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(data.kpiCaption,
                style: const pw.TextStyle(fontSize: 8, color: gris)),
          ),
        if (data.summary.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _resumen(data.summary),
        ],
        if (data.noData) ...[
          pw.SizedBox(height: 14),
          _sinDatos(),
        ] else ...[
          pw.SizedBox(height: 12),
          _tabla(data),
        ],
      ],
    );
  }

  static pw.Widget _encabezadoTabla(List<ReportColumn> cols) {
    if (cols.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: azul,
          child: pw.Row(children: [
            for (final c in cols)
              pw.Expanded(
                child: pw.Text(
                  c.label,
                  textAlign: _textAlign(c.align),
                  style: const pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                ),
              ),
          ]),
        ),
        pw.SizedBox(height: 2),
      ],
    );
  }

  static pw.Widget _tabla(ReportData data) {
    final cols = data.table.columns;
    final rows = data.table.rows;
    if (cols.isEmpty) return pw.SizedBox.shrink();
    if (rows.isEmpty) return _sinDatos();

    final body = <pw.TableRow>[];
    for (final (i, fila) in rows.indexed) {
      body.add(pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? fondo : PdfColors.white,
          border: pw.Border(
              bottom: pw.BorderSide(color: borde, width: 0.4)),
        ),
        children: [
          for (final c in cols)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              alignment: _align(c.align),
              child: pw.Text(
                fila[c.key]?.toString() ?? '',
                style: pw.TextStyle(
                    fontSize: 7.5, color: oscuro),
                textAlign: _textAlign(c.align),
              ),
            ),
        ],
      ));
    }

    return pw.Column(
      children: [
        if (data.table.title.isNotEmpty)
          pw.Text(data.table.title,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (data.table.caption.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(data.table.caption,
              style: const pw.TextStyle(fontSize: 8, color: gris)),
        ],
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: borde, width: 0.4),
            bottom: pw.BorderSide(color: azul, width: 1),
          ),
          columnWidths: {
            for (final (i, _) in cols.indexed) i: pw.FlexColumnWidth(1),
          },
          children: body,
        ),
        if (data.table.totalValue.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: pw.BoxDecoration(
                color: fondo, border: pw.Border.all(color: azul, width: 0.6)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(data.table.totalLabel,
                    style: const pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(data.table.totalValue,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold, color: azul)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _cabecera(ReportData data) {
    final company = data.company;
    final meta = data.report;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company.name.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: oscuro)),
              pw.SizedBox(height: 2),
              pw.Text(company.tagline,
                  style: const pw.TextStyle(fontSize: 8, color: gris)),
              pw.SizedBox(height: 6),
              pw.Text(meta.title,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
              if (meta.description.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(meta.description,
                      style: const pw.TextStyle(fontSize: 8, color: gris, height: 1.4)),
                ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: meta.number.startsWith('REP-') ? verde : azul,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(children: [
            pw.Text('REPORTE',
                style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text(meta.type.toUpperCase(),
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.white)),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _meta(ReportMeta meta) {
    pw.Widget item(String label, String value) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: gris)),
              pw.SizedBox(height: 1),
              pw.Text(value,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: oscuro)),
            ],
          ),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borde, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(children: [
        item('No. Reporte', meta.number),
        pw.SizedBox(width: 8),
        item('Período', meta.period.isEmpty ? '—' : meta.period),
        pw.SizedBox(width: 8),
        item('Generado', meta.generatedAt),
        pw.SizedBox(width: 8),
        item('Moneda', meta.currency),
      ]),
    );
  }

  static pw.Widget _tarjetaKpi(ReportKpi kpi) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 4),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: fondo,
          border: pw.Border.all(color: borde, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(kpi.label.toUpperCase(),
                style: const pw.TextStyle(fontSize: 6.5, color: gris)),
            pw.SizedBox(height: 2),
            pw.Text(kpi.value,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold, color: azul)),
            if (kpi.detail.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Text(kpi.detail,
                  style: const pw.TextStyle(fontSize: 6.5, color: gris, height: 1.2)),
            ],
          ],
        ),
      ),
    );
  }

  static List<pw.Widget> _tarjetasKpi(List<ReportKpi> kpis) {
    final filas = <pw.Widget>[];
    for (var i = 0; i < kpis.length; i += 4) {
      final chunk = kpis.sublist(i, i + 4 > kpis.length ? kpis.length : i + 4);
      final falta = 4 - chunk.length;
      filas.add(pw.Row(children: [
        for (final k in chunk) _tarjetaKpi(k),
        for (var s = 0; s < falta; s++)
          pw.Expanded(child: pw.SizedBox(width: 4)),
      ]));
      filas.add(pw.SizedBox(height: 4));
    }
    return filas;
  }

  static pw.Widget _resumen(List<ReportSummaryItem> items) {
    return pw.Row(children: [
      for (final (i, s) in items.indexed) ...[
        pw.Expanded(
          child: pw.Row(children: [
            pw.Text('${s.label}: ',
                style: const pw.TextStyle(fontSize: 8, color: gris)),
            pw.Expanded(
              child: pw.Text(s.value,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: oscuro)),
            ),
          ]),
        ),
        if (i < items.length - 1) pw.SizedBox(width: 12),
      ],
    ]);
  }

  static pw.Widget _sinDatos() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: fondo,
        border: pw.Border.all(color: borde, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Text('No hay registros para mostrar.',
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: gris)),
        ],
      ),
    );
  }

  static pw.Alignment _align(String? raw) =>
      raw == 'right' ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

  static pw.TextAlign _textAlign(String? raw) =>
      raw == 'right' ? pw.TextAlign.right : pw.TextAlign.left;

  /// Genera el PDF del reporte (bytes). Funciona en tests (sin plataforma).
  static Future<Uint8List> generarPdf(ReportData data) async {
    final doc = pw.Document(
      title: '${data.report.title} — ${data.report.number}',
      author: data.company.name,
    );
    doc.addPage(_paginas(data));
    return doc.save();
  }

  // ── HTML autocontenido ──────────────────────────────────────────
  /// Inyecta window.PORTAL_PILOT_REPORT en la plantilla reporte.html.
  /// Función PURA (testeable): recibe el template como parámetro.
  static String reporteHtmlDesdeTemplate(String template, ReportData data) {
    final json = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final script = '<script type="application/json" id="portal-pilot-report-data">$json</script><script>window.PORTAL_PILOT_REPORT = JSON.parse(document.getElementById("portal-pilot-report-data").textContent || "{}");</script>';
    if (template.contains('</head>')) {
      return template.replaceFirst('</head>', '$script\n</head>');
    }
    return '<!DOCTYPE html><html><head><meta charset="utf-8"><title>${data.report.title}</title></head><body><h1>${data.report.title}</h1><p>La plantilla reporte.html no se encontró en los assets.</p>$script</body></html>';
  }

  /// Carga la plantilla de assets y devuelve el HTML autocontenido.
  static Future<String> reporteHtml(ReportData data) async {
    final template = await rootBundle.loadString('reporte.html');
    return reporteHtmlDesdeTemplate(template, data);
  }

  // ── Guardar / abrir / compartir ─────────────────────────────────
  /// Nombre base de archivo: `PortalPilot_<Tipo>_<yyyy-MM-dd>[_[n]]`.
  static String nombreArchivo(ReportData data, {int? sufijo}) {
    final hoy = DateTime.now();
    final fecha = '${hoy.year}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';
    final s = sufijo != null && sufijo > 0
        ? '_${sufijo.toString().padLeft(2, '0')}'
        : '';
    var tipo = data.report.type
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (tipo.isEmpty) tipo = 'Reporte';
    return 'PortalPilot_${tipo}_$fecha$s';
  }

  /// Guarda el PDF (y el HTML autocontenido) en `Documentos/PortalPilot/Reportes`.
  /// En Windows usa Bibliotecas\Documentos; en Android, el documento de app.
  /// Retorna la ruta del PDF. `outputDirectory` permite tests sin path_provider.
  static Future<String> guardarLocal(
    ReportData data, {
    String? outputDirectory,
    String? usuarioId,
  }) async {
    final dir = (outputDirectory != null)
        ? Directory(outputDirectory)
        : await _directorioReportes();
    final base = nombreArchivo(data);
    final sep = Platform.pathSeparator;
    var pdf = File('${dir.path}$sep$base.pdf');
    var html = File('${dir.path}$sep$base.html');
    var sufijo = 1;
    while (pdf.existsSync()) {
      final s = sufijo.toString().padLeft(2, '0');
      pdf = File('${dir.path}$sep${base}_$s.pdf');
      html = File('${dir.path}$sep${base}_$s.html');
      sufijo++;
    }

    final pdfBytes = await generarPdf(data);
    final htmlBytes = await reporteHtml(data);
    await pdf.writeAsBytes(pdfBytes, flush: true);
    await html.writeAsString(htmlBytes, flush: true);

    await _agregarHistorial(ReportHistorialItem(
      id: data.report.number,
      tipo: data.report.type,
      titulo: data.report.title,
      fecha: data.report.generatedAt,
      rutaLocal: pdf.path,
      empresaId: AuthControllerAccess.empresaIdActual,
      usuarioId: usuarioId ?? '',
    ));

    return pdf.path;
  }

  static Future<Directory> _directorioReportes() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}PortalPilot'
        '${Platform.pathSeparator}Reportes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Abre el archivo con la aplicación predeterminada. En Android no existe
  /// abrir arbitrario sin FileProvider: se usa el diálogo de compartir.
  static Future<void> abrir(String path) async {
    final file = File(path);
    final ok = await file.exists();
    if (!ok) return;
    if (!kIsWeb && Platform.isAndroid) {
      final bytes = await file.readAsBytes();
      await Printing.sharePdf(bytes: bytes, filename: file.uri.pathSegments.last);
      return;
    }
    final uri = Uri.file(path);
    final opened = await launchUrl(uri);
    if (!opened) {
      await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
    }
  }

  /// Comparte el PDF (sistema operativo).
  static Future<void> compartir(ReportData data, {String? path}) async {
    if (path != null && await File(path).exists()) {
      final bytes = await File(path).readAsBytes();
      await Printing.sharePdf(
          bytes: bytes, filename: '${nombreArchivo(data)}.pdf');
      return;
    }
    final bytes = await generarPdf(data);
    await Printing.sharePdf(
        bytes: bytes, filename: '${nombreArchivo(data)}.pdf');
  }

  /// Imprime el PDF (diálogo del sistema).
  static Future<void> imprimir(ReportData data) async {
    final bytes = await generarPdf(data);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // ── Historial ───────────────────────────────────────────────────
  static Future<List<ReportHistorialItem>> obtenerHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kHistorialKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((m) => ReportHistorialItem.fromJson(Map<String, dynamic>.from(m)))
          .whereType<ReportHistorialItem>()
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _agregarHistorial(ReportHistorialItem item) async {
    final actuales = await obtenerHistorial();
    final sinDuplicado = actuales.where((e) => e.id != item.id).toList();
    sinDuplicado.insert(0, item);
    if (sinDuplicado.length > 50) {
      sinDuplicado.removeRange(50, sinDuplicado.length);
    }
    await guardarHistorial(sinDuplicado);
  }

  /// Escribe la lista completa de historial (meta-datos) en SharedPreferences.
  static Future<void> guardarHistorial(List<ReportHistorialItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kHistorialKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}

/// Barrera fina para leer el tenant actual dentro de ReportService sin
/// acoplarlo a la implementación concreta de AuthController.
class AuthControllerAccess {
  static String get empresaIdActual {
    try {
      return AuthController.instance.empresaCodigo;
    } catch (_) {
      return '';
    }
  }
}