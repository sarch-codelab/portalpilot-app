// Ataque de overflow — Documento fiscal (FacturaDetalle).
// Reproduce el "RIGHT OVERFLOWED BY 27 PX" del recibo fiscal en ventanas
// angostas: la fila del título 'DOCUMENTO FISCAL' + badge de estado era una
// Row fija sin Expanded/Flexible, y las filas de totales tampoco cedían.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:portal_pilot_app/Modules/Facturacion/factura_detalle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Sin fuentes remotas (fallback a Ahem).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Map<String, dynamic> facturaEjemplo() => {
        'correlativo': 'POS-202608-000002',
        'tipo_documento': 'Factura',
        'estado': 'aplicada',
        'fecha': '2026-08-19T23:48:00.000Z',
        'empresa_nombre': 'Distribuidora Abarrotista S de RL',
        'empresa_rtn': '08011999123456',
        'cai': 'POS-DIRECTO',
        'cliente_nombre': 'Consumidor Final',
        'cliente_rtn': 'CF',
        'cliente_direccion': 'Barrio La Esperanza, frente al parque central',
        'condicion_pago': 'Contado',
        'items': [
          {
            'descripcion': 'Mayonesa 1L marca larga para probar textos',
            'cantidad': 1,
            'precio': 20.00,
            'isv': 15,
          },
          {
            'descripcion': 'Refresco 2.5L',
            'cantidad': 3,
            'precio': 47.99,
            'isv': 15,
          },
        ],
        'subtotal': 163.97,
        'isv_15': 24.6,
        'isv_18': 0.0,
        'descuento': 0.0,
        'total': 188.57,
      };

  Future<List<String>> pumpDetalle(WidgetTester tester, Size size) async {
    // MediaQuery exacto: physicalSize + dpr=1.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final captured = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      captured.add(
        msg.split('\n').where((l) => l.trim().isNotEmpty).take(6).join(' | '),
      );
      prev?.call(details);
    };
    await tester.pumpWidget(
      MaterialApp(home: FacturaDetalle(factura: facturaEjemplo())),
    );
    await tester.pump(const Duration(milliseconds: 200));
    FlutterError.onError = prev;
    return captured;
  }

  testWidgets('Recibo fiscal @320x640: sin overflow', (tester) async {
    final errors = await pumpDetalle(tester, const Size(320, 640));
    expect(errors, isEmpty, reason: 'Recibo@320 desborda:\n${errors.join('\n---\n')}');
  });

  testWidgets('Recibo fiscal @360x740: sin overflow', (tester) async {
    final errors = await pumpDetalle(tester, const Size(360, 740));
    expect(errors, isEmpty, reason: 'Recibo@360 desborda:\n${errors.join('\n---\n')}');
  });

  testWidgets('Recibo fiscal @800x600 (desktop): sin overflow', (tester) async {
    final errors = await pumpDetalle(tester, const Size(800, 600));
    expect(errors, isEmpty, reason: 'Recibo@800 desborda:\n${errors.join('\n---\n')}');
  });
}
