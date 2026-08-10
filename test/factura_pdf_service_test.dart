// Smoke test de generación del PDF legal SAR Honduras.
// Verifica que la generación no lance y emita bytes PDF válidos tanto en
// modo normal como en contingencia.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/factura_pdf_service.dart';

Map<String, dynamic> _factura({bool contingencia = false}) => {
  'correlativo': '0101-00000123',
  'tipo_documento': 'Factura',
  'fecha': '2026-01-15',
  'cliente_nombre': 'Juan Pérez',
  'cliente_rtn': '08011999011237',
  'cliente_direccion': 'Tegucigalpa, Francisco Morazán',
  'condicion_pago': 'Contado',
  'tipo_venta': 'Gravada',
  'cai': 'A1B2C3D4E5F6A7B8C9D0E1F2A',
  'rango_inicio': '00000100',
  'rango_fin': '00000200',
  'fecha_limite_emision': '2027-01-15',
  'resolucion': '080-2020-0000123',
  'contingencia': contingencia,
  'items': [
    {
      'descripcion': 'Laptop HP',
      'cantidad': 2,
      'precio': 12500.0,
      'isv': 15,
      'exento': false,
    },
  ],
  'subtotal': 25000.0,
  'isv_15': 3750.0,
  'isv_18': 0.0,
  'descuento': 0.0,
  'total': 28750.0,
};

SarConfiguracionData _config({bool contingencia = false}) =>
    SarConfiguracionData(
      id: 'cfg-1',
      empresaId: 'emp-1',
      rtn: '08011999011237',
      razonSocial: 'Comercial López S. de R.L.',
      nombreComercial: 'Comercial López',
      direccion: 'Tegucigalpa, Francisco Morazán',
      telefono: '+504 2233-4455',
      email: 'ventas@comercialopez.hn',
      representanteLegal: 'María López',
      actividadEconomica: 'Comercio al por mayor',
      establecimiento: '001',
      puntoEmision: '001',
      regimen: 'general',
      contingenciaActiva: contingencia,
      motivoContingencia: contingencia ? 'Fallo en plataforma de la SAR' : null,
      fechaInicioContingencia: contingencia ? DateTime(2026, 1, 10) : null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('FacturaPdfService.generarPdf', () {
    test('genera un PDF legal válido sin lanzar', () async {
      final bytes = await FacturaPdfService.instance.generarPdf(
        factura: _factura(),
        config: _config(),
      );

      expect(bytes, isNotNull);
      expect(
        bytes.length,
        greaterThan(1000),
        reason: 'PDF debe tener contenido',
      );
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    });

    test('genera un PDF válido en régimen de contingencia', () async {
      final bytes = await FacturaPdfService.instance.generarPdf(
        factura: _factura(contingencia: true),
        config: _config(contingencia: true),
      );

      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    });

    test('genera PDF sin CAI (consumidor final) sin lanzar', () async {
      final factura = _factura()..['cai'] = null;
      final bytes = await FacturaPdfService.instance.generarPdf(
        factura: factura,
        config: _config(),
      );

      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    });
  });
}
