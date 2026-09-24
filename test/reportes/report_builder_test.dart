// Tests de ReportBuilder: formateo HNL/es-HN y ensamblado del esquema.
// Estas funciones son PURAS: no tocan base de datos ni assets.

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/reportes/report_builder.dart';
import 'package:portal_pilot_app/Shared/reportes/report_models.dart';

void main() {
  group('ReportBuilder.money', () {
    test('formatea montos HNL con miles y 2 decimales', () {
      expect(ReportBuilder.money(25500), 'L 25,500.00');
      expect(ReportBuilder.money(0), 'L 0.00');
      expect(ReportBuilder.money(1234.5), 'L 1,234.50');
    });

    test('formatea negativos con signo antes de la moneda', () {
      expect(ReportBuilder.money(-500), '-L 500.00');
    });
  });

  group('ReportBuilder.cantidad', () {
    test('entero sin decimales', () {
      expect(ReportBuilder.cantidad(3.0), '3');
      expect(ReportBuilder.cantidad(0), '0');
    });

    test('fracción con 2 decimales', () {
      expect(ReportBuilder.cantidad(2.5), '2.50');
    });
  });

  group('ReportBuilder.fecha / periodoLargo', () {
    test('formato dd/MM/yyyy', () {
      expect(ReportBuilder.fecha(DateTime(2026, 9, 22)), '22/09/2026');
      expect(ReportBuilder.fecha(DateTime(2026, 1, 5)), '05/01/2026');
    });

    test('fechaHora incluye hora y minuto', () {
      final h = ReportBuilder.fechaHora(DateTime(2026, 9, 22, 9, 5));
      expect(RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2}$').hasMatch(h), isTrue);
    });

    test('periodoLargo de un mes completo (es-HN)', () {
      final s = ReportBuilder.periodoLargo(DateTime(2026, 9, 1), DateTime(2026, 9, 30, 23, 59));
      expect(s, 'septiembre de 2026');
    });

    test('periodoLargo de un solo día', () {
      expect(
        ReportBuilder.periodoLargo(DateTime(2026, 9, 22), DateTime(2026, 9, 22)),
        'el 22/09/2026',
      );
    });

    test('periodoLargo de un rango entre meses', () {
      final s = ReportBuilder.periodoLargo(DateTime(2026, 9, 1), DateTime(2026, 10, 15));
      expect(s, 'del 01/09/2026 al 15/10/2026');
    });
  });

  group('ReportBuilder.assemble', () {
    final fixed = DateTime(2026, 9, 22, 14, 30);

    test('inyecta metadatos y periodo en lenguaje natural', () {
      final d = ReportBuilder.assemble(
        number: 'REP-000001',
        tipo: 'Reporte de gastos',
        titulo: 'Reporte de gastos',
        desde: DateTime(2026, 9, 1),
        hasta: DateTime(2026, 9, 30),
        companyName: 'Tienda Doña Ana',
        generaEn: fixed,
      );
      expect(d.company.name, 'Tienda Doña Ana');
      expect(d.report.number, 'REP-000001');
      expect(d.report.period, '01/09/2026 — 30/09/2026');
      expect(d.report.generatedAt, '22/09/2026 14:30');
      expect(d.report.currency, kHnlCurrency);
      expect(d.noData, isFalse);
    });

    test('marca noData y oculta descripción por defecto al no haber rango', () {
      final d = ReportBuilder.assemble(
        number: 'REP-1',
        tipo: 'Stock',
        titulo: 'Stock',
        desde: null,
        companyName: 'Demo',
        noData: true,
        generaEn: fixed,
      );
      expect(d.noData, isTrue);
      expect(d.table.rows, isEmpty);
    });

    test('fila convierte a texto y respeta solo las columnas', () {
      const cols = [
        ReportColumn(key: 'a', label: 'A'),
        ReportColumn(key: 'b', label: 'B'),
      ];
      final f = ReportBuilder.fila(cols, {'a': 1.5, 'b': 'x', 'z': 'ignorado'});
      expect(f, {'a': '1.5', 'b': 'x'});
    });
  });
}