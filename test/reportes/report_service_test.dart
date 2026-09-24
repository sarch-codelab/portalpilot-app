// Tests de ReportService: partes puras y guardado local sin path_provider.
// `guardarLocal` usa `outputDirectory` para testear el flujo de archivos e
// historial sin tocar carpetas reales del sistema.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/reportes/report_builder.dart';
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';
import 'package:portal_pilot_app/Shared/services/report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _plantilla =
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Plantilla</title></head>'
    '<body><h1>Hola</h1></body></html>';

ReportData _data() => ReportBuilder.assemble(
      number: 'REP-000001',
      tipo: 'Reporte de gastos',
      titulo: 'Reporte de gastos',
      desde: DateTime(2026, 9, 1),
      hasta: DateTime(2026, 9, 22),
      companyName: 'Tienda Doña Ana',
      kpis: [ReportKpi(label: 'Total', value: 'L 25,500.00')],
      columns: const [
        ReportColumn(key: 'fecha', label: 'Fecha'),
        ReportColumn(key: 'monto', label: 'Monto', align: 'right'),
      ],
      rows: const [
        {'fecha': '01/09/2026', 'monto': 'L 500.00'},
      ],
      tableTitle: 'Detalle de gastos',
      totalLabel: 'Total',
      totalValue: 'L 500.00',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReportService.reporteHtmlDesdeTemplate (pura)', () {
    test('inyecta window.PORTAL_PILOT_REPORT antes de </head>', () {
      final html = ReportService.reporteHtmlDesdeTemplate(_plantilla, _data());
      expect(html.contains('window.PORTAL_PILOT_REPORT'), isTrue);
      expect(html.indexOf('</head>'), greaterThan(html.indexOf('PORTAL_PILOT_REPORT')));
      expect(html.contains('REP-000001'), isTrue);
    });

    test('genera documento de emergencia si no hay </head>', () {
      final html = ReportService.reporteHtmlDesdeTemplate('sin head', _data());
      expect(html.contains('plantilla reporte.html no se encontró'), isTrue);
      expect(html.contains('PORTAL_PILOT_REPORT'), isTrue);
    });
  });

  group('ReportService.nombreArchivo', () {
    test('usa slug del tipo y fecha de hoy', () {
      final n = ReportService.nombreArchivo(_data());
      final hoy = DateTime.now();
      final dia = hoy.day.toString().padLeft(2, '0');
      final mes = hoy.month.toString().padLeft(2, '0');
      expect(n, 'PortalPilot_Reporte_de_gastos_${hoy.year}-$mes-$dia');
    });

    test('agrega sufijo _01 cuando se indica', () {
      final n = ReportService.nombreArchivo(_data(), sufijo: 1);
      expect(n.endsWith('_01'), isTrue);
    });
  });

  group('ReportService.guardarLocal (sin path_provider)', () {
    test('escribe PDF válido + HTML y registra historial', () async {
      final dir = await Directory.systemTemp.createTemp('pp_reportes_test');
      addTearDown(() => dir.delete(recursive: true));

      final pdfPath =
          await ReportService.guardarLocal(_data(), outputDirectory: dir.path);
      expect(pdfPath, isNotNull);
      expect(pdfPath.endsWith('.pdf'), isTrue);

      final bytes = await File(pdfPath).readAsBytes();
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');

      final htmlPath = pdfPath.replaceAll('.pdf', '.html');
      expect(await File(htmlPath).exists(), isTrue);

      final hist = await ReportService.obtenerHistorial();
      expect(hist.length, 1);
      expect(hist.single.id, 'REP-000001');
      expect(hist.single.rutaLocal, pdfPath);
    });

    test('segunda guardada del mismo día no pisa: usa _01', () async {
      final dir = await Directory.systemTemp.createTemp('pp_reportes_test2');
      addTearDown(() => dir.delete(recursive: true));

      // Correlativos distintos: en producción los asigna el dispatcher.
      final d1 = _data();
      final d2 = ReportBuilder.assemble(
        number: 'REP-000002',
        tipo: 'Reporte de gastos',
        titulo: 'Reporte de gastos',
        desde: DateTime(2026, 9, 1),
        hasta: DateTime(2026, 9, 22),
        companyName: 'Tienda Doña Ana',
        columns: const [
          ReportColumn(key: 'fecha', label: 'Fecha'),
          ReportColumn(key: 'monto', label: 'Monto', align: 'right'),
        ],
        rows: const [
          {'fecha': '01/09/2026', 'monto': 'L 500.00'},
        ],
        tableTitle: 'Detalle de gastos',
        totalLabel: 'Total',
        totalValue: 'L 500.00',
      );

      final p1 =
          await ReportService.guardarLocal(d1, outputDirectory: dir.path);
      final p2 =
          await ReportService.guardarLocal(d2, outputDirectory: dir.path);
      expect(p1, isNot(p2));
      expect(p2.endsWith('_01.pdf'), isTrue);

      final hist = await ReportService.obtenerHistorial();
      expect(hist.length, 2);
      expect(hist.map((e) => e.rutaLocal).toSet().length, 2);
    });
  });

  group('ReportService.generarPdf', () {
    test('emite bytes PDF', () async {
      final bytes = await ReportService.generarPdf(_data());
      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    });
  });
}