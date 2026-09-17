// ignore_for_file: avoid_print
// ATAQUE 1 — Race Condition Nuclear (Estado).
// 50 actualizaciones simultáneas de tema + desmontar/montar widgets con estado
// mientras el estado cambia, + carcajada de tema durante un formulario activo.
// NOTA: esta app no tiene i18n (no hay locale/supportedLocales en main.dart),
// así que la segunda mitad del ataque (idioma) no aplica; se sustituye por la
// raza real que sí existe: AppThemeNotifier + AuthController + widgets vivos.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/Modules/Facturacion/clientes/cliente_form.dart';
import 'package:portal_pilot_app/Modules/CRM/clientes/cliente_list.dart';
import 'package:portal_pilot_app/Modules/ChatIA/chat_ia_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('50 toggles de tema lanzados sin await entre sí: no crash y persistencia coherente', () async {
    SharedPreferences.setMockInitialValues({});
    await appThemeNotifier.setMode(ThemeMode.dark);
    final futures = <Future<void>>[];
    for (var i = 0; i < 50; i++) {
      futures.add(appThemeNotifier.toggle()); // disparo en rafaga (< 100ms)
    }
    await Future.wait(futures);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    print('[A1/P1] valor final=${appThemeNotifier.value.name} persistido=$stored');
    expect(appThemeNotifier.value, anyOf(ThemeMode.dark, ThemeMode.light));
    expect(stored, appThemeNotifier.value.name,
        reason: 'El último persist async debe coincidir con el estado final');
  });

  test('mezcla toggle()+setMode()+notifyListeners() 200 veces rafagado', () async {
    SharedPreferences.setMockInitialValues({});
    await appThemeNotifier.setMode(ThemeMode.light);
    for (var i = 0; i < 200; i++) {
      final f1 = appThemeNotifier.toggle();
      final f2 = appThemeNotifier.setMode(
          i.isEven ? ThemeMode.dark : ThemeMode.light);
      final f3 = appThemeNotifier.setMode(ThemeMode.system);
      await Future.wait([f1, f2, f3]);
    }
    print('[A1/P2] sobrevivió 200 ráfagas; valor=${appThemeNotifier.value.name}');
    expect(true, isTrue);
  });

  testWidgets('A1/P3 - tema cambiado 10x mientras se edita el formulario de cliente', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'clientes_facturacion': '[]'});
    await appThemeNotifier.setMode(ThemeMode.dark);
    await tester.pumpWidget(const MaterialApp(home: ClienteForm()));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Empresa Hostil \u{1F600}');
    for (var i = 0; i < 10; i++) {
      final f = appThemeNotifier.toggle();
      await tester.pump();
      await f;
    }
    await tester.pump();
    final err = tester.takeException();
    print('[A1/P3] error tras switch de tema sobre formulario vivo: ${err?.toString() ?? 'NINGUNO'}');
    expect(err, isNull, reason: 'Cambiar tema no debe romper un form en uso');
    expect(find.text('Empresa Hostil \u{1F600}'), findsWidgets);
  });

  testWidgets('A1/P4 - desmontar ClienteList mientras _cargar() está en vuelo (evidencia runtime)', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'clientes': '[]'});
    await tester.pumpWidget(const MaterialApp(home: ClienteList()));
    // Destruyo la pantalla en el instante en que `_cargar()` espera por la red.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    final err = tester.takeException();
    print('[A1/P4-runtime] setState-después-de-dispose observado: ${err?.toString() ?? 'NO REPRODUCIDO (el mock HTTP responde al instante)'}');
    expect(err, isNull);
  });

  test('A1/P4b - check de código: cargas asíncronas con guardia `mounted` (REMEDIADO)', () {
    // cliente_list.dart:_cargar (fallback a prefs) -> `if (!mounted) return;`
    // antes del setState.
    final srcList = File('lib/Modules/CRM/clientes/cliente_list.dart').readAsStringSync();
    final listFallback = srcList.split('\n').sublist(43, 55).join('\n');
    expect(listFallback.contains('if (!mounted) return;'), isTrue,
        reason: 'cliente_list.dart:_cargar debe guardar mounted antes del setState');

    // cliente_form.dart (Facturación):_cargarClientes -> `if (mounted)` en el
    // decode local Y en la fusión remota (sin setState tras dispose).
    final srcForm = File('lib/Modules/Facturacion/clientes/cliente_form.dart').readAsStringSync();
    final carga = srcForm.split('\n').sublist(29, 42).join('\n');
    expect(carga.contains('if (mounted)'), isTrue,
        reason: 'cliente_form.dart:_cargarClientes debe guardar mounted antes del setState');
    print('[A1/P4b] cliente_list.dart y cliente_form.dart: setState tras await con guardia mounted [REMEDIADO]');
  });

  testWidgets('A1/P5 - ChatIA (con Timer/repeat) construido y destruido mientras el tema oscila', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await appThemeNotifier.setMode(ThemeMode.dark);
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(const MaterialApp(home: ChatIAHome()));
      await tester.pump(const Duration(milliseconds: 30));
      final f = appThemeNotifier.toggle();
      await tester.pumpWidget(const SizedBox());
      await f;
      await tester.pump(const Duration(milliseconds: 16));
    }
    final err = tester.takeException();
    print('[A1/P5] chat + tema 20 ciclos: ${err?.toString() ?? 'OK'}');
    expect(err, isNull);
  });
}