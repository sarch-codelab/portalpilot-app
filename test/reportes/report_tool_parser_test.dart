// Tests de ReportToolParser: interpretación del intent de reporte desde la
// respuesta de la IA (bloque JSON controlado + fallback por palabras).

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/reportes/report_tool_parser.dart';
import 'package:portal_pilot_app/Shared/reportes/report_tools.dart';

void main() {
  group('ReportToolParser.interpretar (JSON controlado)', () {
    test('parsea tool gastos con mes/anio', () {
      final i = ReportToolParser.interpretar(
        'Claro, un momento...\n```json\n{"tool":"gastos","periodo":"mes","mes":9,"anio":2026}\n```\nSe está preparando.',
      );
      expect(i, isNotNull);
      expect(i!.tool, ReportToolType.gastos);
      expect(i.params.mes, 9);
      expect(i.params.anio, 2026);
    });

    test('parsea tool ventas con rango dd/MM/yyyy', () {
      final i = ReportToolParser.interpretar(
        '{"tool":"ventas","periodo":"rango","desde":"01/09/2026","hasta":"22/09/2026"}',
      );
      expect(i, isNotNull);
      expect(i!.tool, ReportToolType.ventas);
      expect(i.params.desde, DateTime(2026, 9, 1));
      expect(i.params.hasta, DateTime(2026, 9, 22));
    });

    test('parsea tool stock sin periodo', () {
      final i = ReportToolParser.interpretar('{"tool":"stock"}');
      expect(i, isNotNull);
      expect(i!.tool, ReportToolType.stock);
    });

    test('rechaza tool desconocido', () {
      expect(
        ReportToolParser.interpretar('{"tool":"borrar_todo"}'),
        isNull,
      );
    });

    test('devuelve null si no hay bloque JSON y no se pasa mensaje', () {
      expect(ReportToolParser.interpretar('Respuesta normal de la IA'), isNull);
    });
  });

  group('ReportToolParser.interpretar (fallback conservador)', () {
    test('detecta "Generame un reporte de gastos"', () {
      final i = ReportToolParser.interpretar('X', mensajeUsuario: 'Generame un reporte de gastos de este mes');
      expect(i, isNotNull);
      expect(i!.tool, ReportToolType.gastos);
    });

    test('detecta rango de fechas en el mensaje', () {
      final i = ReportToolParser.interpretar(
        'X',
        mensajeUsuario: 'quiero un reporte de ventas del 01/09/2026 al 15/09/2026',
      );
      expect(i, isNotNull);
      expect(i!.tool, ReportToolType.ventas);
      expect(i.params.desde, DateTime(2026, 9, 1));
      expect(i.params.hasta, DateTime(2026, 9, 15));
    });

    test('asigna cada tool nueva a su sinónimo en castellano', () {
      final casos = <String, ReportToolType>{
        'generame un reporte de compras': ReportToolType.compras,
        'quiero el listado de clientes': ReportToolType.clientes,
        'estructura el detalle de la facturacion': ReportToolType.facturacion,
        'reporte de cuentas por cobrar': ReportToolType.cuentasPorCobrar,
        'generame los arqueos de caja': ReportToolType.caja,
        'resumen financiero del mes': ReportToolType.resumenFinanciero,
        'enliste los empleados': ReportToolType.empleados,
      };
      for (final entry in casos.entries) {
        final i = ReportToolParser.interpretar('X', mensajeUsuario: entry.key);
        expect(i, isNotNull, reason: 'debería detectar: ${entry.key}');
        expect(i!.tool, entry.value, reason: 'para: ${entry.key}');
      }
    });

    test('no dispara sin verbo de reporte', () {
      expect(ReportToolParser.interpretar('X', mensajeUsuario: 'hola que tal'), isNull);
      expect(ReportToolParser.interpretar('X', mensajeUsuario: 'gastos'), isNull);
    });

    test('no dispara con JSON malformed', () {
      expect(ReportToolParser.interpretar('{"tool": "'), isNull);
    });
  });
}