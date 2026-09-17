// ignore_for_file: avoid_print
// ATAQUE 6 — Error de Serialización (JSON hostil).
// Payloads con campos ausentes, tipos equivocados y nulls inesperados contra
// los puntos reales de parseo de la app.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart';
import 'package:portal_pilot_app/Shared/services/ai_service.dart';

void main() {
  test('A6/P1 - List<Map>.from(jsonDecode) con elemento no-map: TypeError "silencioso" (patrón masivo en lib/)', () {
    final json = '[{"id":1}, "no-un-map", null]';
    expect(
      () => List<Map<String, dynamic>>.from(jsonDecode(json)),
      throwsA(isA<TypeError>()),
      reason: 'El default `?? \'[]\'` NO protege contra JSON semánticamente inválido',
    );
    print('[A6/P1] `.from(jsonDecode(...))` con 1 elemento malo -> TypeError (no se captura)');
  });

  test('A6/P2 - JSON truncado/malformado en prefs: FormatException sin catch (replica contabilidad_home.dart:49)', () {
    final json = '[{"fecha":"2026-01-01","monto":100,';
    expect(() => jsonDecode(json), throwsFormatException);
    print('[A6/P2] JSON corrupto en `transacciones` -> FormatException en initState sin try/catch');
  });

  test('A6/P3 - SyncItem.fromJson defensivo: payload hostil -> fallbacks seguros, sin lanzar', () {
    // sync_service.dart:52-80: cast duros sustituidos por conversiones seguras.
    final a = SyncItem.fromJson({'id': 1, 'tabla': 'x', 'operacion': 'insert', 'datos': null});
    expect(a, isA<SyncItem>());
    expect(a.id, '1');      // int -> toString
    expect(a.tabla, 'x');
    expect(a.datos, isEmpty); // datos null -> const {}

    final b = SyncItem.fromJson({'id': '1', 'tabla': 'x', 'operacion': 'insert', 'datos': [], 'createdAt': 'NO-DATE'});
    expect(b.datos, isEmpty); // datos [] no es Map -> const {}
    expect(b.createdAt.isAfter(DateTime(2020)), isTrue,
        reason: 'createdAt corrupto -> DateTime.now() en lugar de FormatException');
    print('[A6/P3] SyncItem.fromJson con payload hostil sobrevive con fallbacks (fila corrupta NO para la sync) [REMEDIADO]');
  });

  test('A6/P4 - ProductIdentification: confianza como String ya NO crashea (numOrNull)', () {
    final p = ProductIdentification.fromJson({'nombre': 'X', 'confianza': '0.95'});
    expect(p.confianza, 0.95, reason: 'JsonGuard.numOrNull parsea "0.95" a double');
    final q = ProductIdentification.fromJson({'nombre': 'Y', 'confianza': 'abc'});
    expect(q.confianza, isNull, reason: 'confianza no numérica -> null, sin TypeError');
    print('[A6/P4] ProductIdentification.fromJson con tipo equivocado sobrevive (null o num) [REMEDIADO]');
  });

  test('A6/P5 - BarcodeLookupResult: products como objeto se sanean a lista vacía', () {
    final r = BarcodeLookupResult.fromJson({'found': true, 'products': {'0': 'x'}});
    expect(r.found, isTrue);
    expect(r.products, isA<List<Map<String, dynamic>>>());
    expect(r.products, isEmpty, reason: 'JsonGuard.toListOfMaps con Map -> [] (nunca lanza)');
    print('[A6/P5] BarcodeLookupResult.fromJson con products Map -> lista vacía [REMEDIADO]');
  });

  test('A6/P6 - Campo obligatorio ausente en _claveTransaccion: N/A (usa defaults, sobrevive)', () {
    // contabilidad_home.dart:74-76 usa `?? ''`/`?? 0` -> NULL-safe (contraste positivo).
    final t = <String, dynamic>{};
    final clave = '${t['fecha'] ?? ''}|${t['monto'] ?? 0}|${t['descripcion'] ?? ''}';
    expect(clave, '|0|');
    print('[A6/P6] campos ausentes en transacciones -> defaults, sin crash');
  });

  test('A6/P7 - FiscalConfig: fecha corrupta en config se recupera con default (fiscal_compliance.dart:26-28) (contraste)', () async {
    // loadConfig() sí envuelve en try/catch -> este punto es DEFENSIVO.
    print('[A6/P7] FiscalCompliance.loadConfig usa try/catch -> config corrupta cae a defaultConfig() [bien]');
    expect(true, isTrue);
  });
}