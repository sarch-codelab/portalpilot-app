// Ataque de overflow — Nómina, CRM y Punto de Venta.
// Reproduce los "RenderFlex overflowed by N pixels" que el usuario ve con
// `flutter run` en pantallas angostas (320-375px). Sin red: http se mockea
// para que las pantallas usen solo SharedPreferences local.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portal_pilot_app/Modules/POS/pos_home.dart';
import 'package:portal_pilot_app/Modules/CRM/crm_home.dart';
import 'package:portal_pilot_app/Modules/RRHH/rrhh_home.dart';
import 'package:portal_pilot_app/Modules/RRHH/nomina/nomina_home.dart';
import 'package:portal_pilot_app/Modules/Inventario/inventario_home.dart';
import 'package:portal_pilot_app/Modules/Comercial/comercial_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Sin fuentes remotas (fallback a Ahem).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // Todas las pantallas leen datos de SharedPreferences al iniciar.
  Future<void> seedPrefs() async {
    SharedPreferences.setMockInitialValues({
      'empleados': '''
      [
        {"id":"1","nombre":"Maria","apellido":"Castellanos","cargo":"Cajera Jefe de Piso","salario":18500.0,"activo":true},
        {"id":"2","nombre":"Roberto Antonio","apellido":"Mejia","cargo":"Auxiliar de Bodega y Mantenimiento","salario":14200.5,"activo":true}
      ]''',
      'recibos_nomina': '[]',
      'ventas_crm': '''
      [
        {"monto":12500.0,"estado":"pendiente","fecha":"2026-09-12T10:00:00.000Z"},
        {"monto":8300.0,"estado":"en_proceso","fecha":"2026-09-20T10:00:00.000Z"}
      ]''',
      'clientes': '[]',
      'productos': '''
      [
        {"id":"1","nombre":"Coca-Cola 600ml","codigo":"CC600","categoria":"Bebidas","stock_actual":25,"stock_minimo":5,"precio_venta":15.0},
        {"id":"2","nombre":"Pan Bimbo Grande","codigo":"BIM01","categoria":"Panaderia","stock_actual":3,"stock_minimo":6,"precio_venta":55.0}
      ]''',
    });
  }

  /// Pumpea [widget] a todo el cuerpo y captura cada excepción de layout
  /// (RenderFlex overflowed, etc.) reportada a FlutterError.
  /// El http de ApiService se redirige a un MockClient (500) para que las
  /// pantallas funcionen 100% offline con SharedPreferences.
  Future<List<String>> pumpAndCollect(
    WidgetTester tester,
    Widget widget,
    Size size,
  ) async {
    // API moderna: physicalSize + dpr=1 => MediaQuery = size exacto.
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
    await http.runWithClient(
      () async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
        await tester.pump(const Duration(milliseconds: 200));
      },
      () => http_testing.MockClient(
        (request) async => http.Response('{"error":"offline-test"}', 500),
      ),
    );
    FlutterError.onError = prev;
    return captured;
  }

  for (final entry in <String, Size Function()>{
    '320x640 (móvil chico)': () => const Size(320, 640),
    '360x740 (móvil común)': () => const Size(360, 740),
    '375x667 (iPhone SE/8)': () => const Size(375, 667),
    '414x896 (móvil grande)': () => const Size(414, 896),
    '800x600 (ventana desktop chica)': () => const Size(800, 600),
    '1280x800 (escritorio con sidebar)': () => const Size(1280, 800),
  }.entries) {
    final size = entry.value();
    final tag = entry.key;

    testWidgets('NominaHome @ $tag: sin overflow', (tester) async {
      await seedPrefs();
      final errors = await pumpAndCollect(tester, const NominaHome(), size);
      expect(errors, isEmpty, reason: 'Nómina@$tag desborda:\n${errors.join('\n---\n')}');
    });

    testWidgets('RrhhHome @ $tag: sin overflow', (tester) async {
      await seedPrefs();
      final errors = await pumpAndCollect(tester, const RrhhHome(), size);
      expect(errors, isEmpty, reason: 'RRHH@$tag desborda:\n${errors.join('\n---\n')}');
    });

    testWidgets('CrmHome @ $tag: sin overflow', (tester) async {
      await seedPrefs();
      final errors = await pumpAndCollect(tester, const CrmHome(), size);
      expect(errors, isEmpty, reason: 'CRM@$tag desborda:\n${errors.join('\n---\n')}');
    });

    testWidgets('PosHome @ $tag: sin overflow', (tester) async {
      await seedPrefs();
      final errors = await pumpAndCollect(tester, const PosHome(), size);
      expect(errors, isEmpty, reason: 'POS@$tag desborda:\n${errors.join('\n---\n')}');
    });

    testWidgets('InventarioHome @ $tag: sin overflow', (tester) async {
      await seedPrefs();
      final errors = await pumpAndCollect(tester, const InventarioHome(), size);
      expect(errors, isEmpty, reason: 'Inventario@$tag desborda:\n${errors.join('\n---\n')}');
    });

    testWidgets('ComercialHome @ $tag: sin overflow', (tester) async {
      await seedPrefs();
      final errors = await pumpAndCollect(tester, const ComercialHome(), size);
      expect(errors, isEmpty, reason: 'Comercial@$tag desborda:\n${errors.join('\n---\n')}');
    });
  }

  testWidgets('Nómina: recibos generados con montos grandes no desbordan a 320px',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'empleados':
          '[{"id":"1","nombre":"Maria","apellido":"Castellanos","cargo":"Cajera","salario":15600.0,"activo":true}]',
      'recibos_nomina': '''
      [
        {"id":"1_2026_9","empleado_id":"1","empleado_nombre":"Maria Castellanos","cargo":"Cajera",
         "mes":9,"anio":2026,"salario_bruto":15600.0,"ihss_empleado":390.0,"rap_empleado":234.0,
         "total_deducciones":624.0,"salario_neto":14976.0,"fecha_generacion":"2026-09-28T10:00:00.000Z"}
      ]''',
    });
    final errors = await pumpAndCollect(
      tester,
      const NominaHome(),
      const Size(320, 640),
    );
    expect(errors, isEmpty, reason: 'Nómina con recibos@320 desborda:\n${errors.join('\n---\n')}');
  });
}
