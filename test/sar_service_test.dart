// Test unitarios del motor de Facturación SAR Honduras.
// Cubren: motor ISV, validación RTN/CAI, formato de correlativos
// (mapping de tipos), conversión de montos a letras.

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';

void main() {
  group('SarTipoDocumento.codigoPorNombre', () {
    test('mapea nombres de documento a códigos SAR', () {
      expect(
        SarTipoDocumento.codigoPorNombre('Factura'),
        SarTipoDocumento.factura,
      );
      expect(
        SarTipoDocumento.codigoPorNombre('Nota Crédito'),
        SarTipoDocumento.notaCredito,
      );
      expect(
        SarTipoDocumento.codigoPorNombre('Nota de Crédito'),
        SarTipoDocumento.notaCredito,
      );
      expect(
        SarTipoDocumento.codigoPorNombre('Nota Débito'),
        SarTipoDocumento.notaDebito,
      );
      expect(
        SarTipoDocumento.codigoPorNombre('Nota de Débito'),
        SarTipoDocumento.notaDebito,
      );
      expect(
        SarTipoDocumento.codigoPorNombre('Factura Exportación'),
        SarTipoDocumento.facturaExportacion,
      );
      expect(
        SarTipoDocumento.codigoPorNombre('Tiquete'),
        SarTipoDocumento.tiquete,
      );
    });

    test('usa Factura como tipo por defecto para nombres desconocidos', () {
      expect(
        SarTipoDocumento.codigoPorNombre('Recibo'),
        SarTipoDocumento.factura,
      );
    });

    test('etiqueta devuelve la descripción del código', () {
      expect(SarTipoDocumento.etiqueta(SarTipoDocumento.factura), 'Factura');
      expect(
        SarTipoDocumento.etiqueta(SarTipoDocumento.notaCredito),
        'Nota de Crédito',
      );
    });
  });

  group('SarService.calcularTotales (motor ISV)', () {
    test('lista vacía produce ceros', () {
      final t = SarService.calcularTotales([]);
      expect(t.subtotal, 0);
      expect(t.isv15, 0);
      expect(t.isv18, 0);
      expect(t.total, 0);
    });

    test('ISV 15% sobre bienes gravados', () {
      final t = SarService.calcularTotales([
        {'cantidad': 2, 'precio': 100, 'isv': 15},
        {'cantidad': 1, 'precio': 50, 'isv': 15},
      ]);
      expect(t.base15, 250);
      expect(t.isv15, 37.5);
      expect(t.total, 287.5);
    });

    test('ISV 18% sobre bebidas y tabaco', () {
      final t = SarService.calcularTotales([
        {'cantidad': 10, 'precio': 20, 'isv': 18},
      ]);
      expect(t.base18, 200);
      expect(t.isv18, 36);
      expect(t.total, 236);
    });

    test('exenta no genera ISV', () {
      final t = SarService.calcularTotales([
        {'cantidad': 3, 'precio': 100, 'exento': true},
      ]);
      expect(t.baseExenta, 300);
      expect(t.isv15, 0);
      expect(t.isv18, 0);
      expect(t.total, 300);
    });

    test('descuento global se prorratea entre bases', () {
      final t = SarService.calcularTotales([
        {'cantidad': 2, 'precio': 100, 'isv': 15},
        {'cantidad': 1, 'precio': 100, 'exento': true},
      ], descuentoGlobal: 30);
      expect(t.descuento, 30);
      expect(t.subtotal, 270);
      expect(t.base15, 180);
      expect(t.baseExenta, 90);
      expect(t.isv15, 27);
      expect(t.total, 297);
    });

    test('descuento mayor al subtotal se limita al subtotal', () {
      final t = SarService.calcularTotales([
        {'cantidad': 1, 'precio': 100, 'isv': 15},
      ], descuentoGlobal: 500);
      expect(t.descuento, 100);
      expect(t.subtotal, 0);
      expect(t.total, 0);
    });

    test('la tasa ISV por defecto es 15%', () {
      final t = SarService.calcularTotales([
        {'cantidad': 1, 'precio': 100},
      ]);
      expect(t.base15, 100);
      expect(t.isv15, 15);
    });
  });

  group('SarService.esRTNValido', () {
    // RTN de ejemplo válido calculado con el módulo 11: 0801199901123 -> 7.
    test('acepta un RTN de 14 dígitos con dígito verificador correcto', () {
      expect(SarService.esRTNValido('08011999011237'), isTrue);
    });

    test('acepta RTN con guiones y espacios', () {
      expect(SarService.esRTNValido('0801-199901-1237'), isTrue);
      expect(SarService.esRTNValido('0801 199901 1237'), isTrue);
    });

    test('rechaza RTN con dígito verificador incorrecto', () {
      expect(SarService.esRTNValido('08011999011238'), isFalse);
    });

    test('rechaza longitud inválida y caracteres no numéricos', () {
      expect(SarService.esRTNValido('123'), isFalse);
      expect(SarService.esRTNValido('0801199901123A'), isFalse);
      expect(SarService.esRTNValido(''), isFalse);
    });

    test('verificarDigito:false solo valida el formato', () {
      expect(
        SarService.esRTNValido('08011999011238', verificarDigito: false),
        isTrue,
      );
    });
  });

  group('SarService.formatearRTN', () {
    test('formatea 14 dígitos a 4-6-4', () {
      expect(SarService.formatearRTN('08011999011237'), '0801-199901-1237');
    });

    test('es idempotente con RTN ya formateado', () {
      expect(SarService.formatearRTN('0801-199901-1237'), '0801-199901-1237');
    });

    test('devuelve el valor original si no tiene 14 dígitos', () {
      expect(SarService.formatearRTN('123'), '123');
    });
  });

  group('SarService.esCAIValido / normalizarCAI', () {
    const cai25 = 'ABCDEFGHIJKLMNOPQRSTUVWXY'; // 25 caracteres

    test('acepta CAI de 25 caracteres alfanuméricos', () {
      expect(SarService.esCAIValido(cai25), isTrue);
      expect(SarService.esCAIValido('A1B2C3D4E5F6A7B8C9D0E1F2A'), isTrue);
    });

    test('rechaza longitud distinta de 25 y caracteres especiales', () {
      expect(SarService.esCAIValido('ABCDEFGHIJKLMNOPQRSTUVWX'), isFalse);
      expect(SarService.esCAIValido('A1B2C3D4E5F6A7B8C9D0E1F2@'), isFalse);
      expect(SarService.esCAIValido(''), isFalse);
    });

    test('normalizarCAI elimina guiones, espacios y pone mayúsculas', () {
      expect(SarService.normalizarCAI('abc-de f'), 'ABCDEF');
    });
  });

  group('SarService.numeroALetras', () {
    test('montos básicos', () {
      expect(SarService.numeroALetras(0), 'CERO CON 00/100');
      expect(SarService.numeroALetras(1), 'UNO CON 00/100');
      expect(SarService.numeroALetras(21), 'VEINTIUNO CON 00/100');
      expect(SarService.numeroALetras(22), 'VEINTIDOS CON 00/100');
      expect(SarService.numeroALetras(30), 'TREINTA CON 00/100');
      expect(SarService.numeroALetras(31), 'TREINTA Y UNO CON 00/100');
      expect(SarService.numeroALetras(100), 'CIEN CON 00/100');
      expect(SarService.numeroALetras(123), 'CIENTO VEINTITRES CON 00/100');
      expect(
        SarService.numeroALetras(999),
        'NOVECIENTOS NOVENTA Y NUEVE CON 00/100',
      );
    });

    test('millares y millones', () {
      expect(SarService.numeroALetras(1000), 'MIL CON 00/100');
      expect(SarService.numeroALetras(2000), 'DOS MIL CON 00/100');
      expect(SarService.numeroALetras(1000000), 'UN MILLON CON 00/100');
      expect(
        SarService.numeroALetras(2500000),
        'DOS MILLONES QUINIENTOS MIL CON 00/100',
      );
    });

    test('incluye centavos', () {
      expect(
        SarService.numeroALetras(1532.45),
        'MIL QUINIENTOS TREINTA Y DOS CON 45/100',
      );
      expect(SarService.numeroALetras(15.05), 'QUINCE CON 05/100');
    });

    test('montos negativos', () {
      expect(SarService.numeroALetras(-100), 'MENOS CIEN CON 00/100');
    });
  });
}
