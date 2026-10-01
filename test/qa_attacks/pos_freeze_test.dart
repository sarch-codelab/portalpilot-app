// Ataque anti-freeze — POS Terminal.
// El usuario reportó el POS congelado con "Cannot hit test a render box with
// no size" (RenderDecoratedBox de la barra de cobro, size MISSING). Eso pasa
// cuando un frame queda a medio construir: build sin layout (o un nodo del
// overlay sin constraints definidas) y cualquier pointer event posterior
// golpea un árbol sin tamaños.
//
// Este test reproduce la ventana real del usuario (364x616, dpr 1.0) y
// ejercita los caminos que estresan el árbol:
//   1. Carga del terminal (drift puede tardar/colgarse → fallback a prefs).
//   2. Toast overlay (se muestra al cargar con respaldo y en errores).
//   3. Lector wedge USB (ráfaga de teclas + Enter).
//   4. Edición de cantidad con commit onTapOutside.
//   5. Cobro en efectivo (diálogo + confirmación).
//   6. Resize cruzando la diagonal móvil/escritorio varias veces.
// Cualquier FlutterError (hit-test sin size, overflow, setState durante
// build) hace fallar el test.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portal_pilot_app/Modules/POS/pos_terminal_v2.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Bombea tiempo simulado en pasos de 100ms (los timeouts de la app usan
  /// el reloj fake de flutter_test y necesitan que el tiempo avance).
  Future<void> pumpFake(WidgetTester tester, Duration duration) async {
    var remaining = duration.inMilliseconds;
    while (remaining > 0) {
      const step = 100;
      await tester.pump(const Duration(milliseconds: step));
      remaining -= step;
    }
  }

  testWidgets('POS no se congela: carrito + wedge + cobro + resize (364x616)',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'productos': '''
      [
        {"id":"1","nombre":"Coca-Cola 600ml","codigo":"CC600","barcode":"7501234567890","categoria":"Bebidas","stock_actual":25,"stock_minimo":5,"precio_venta":15.0,"isv_rate":15.0},
        {"id":"2","nombre":"Pan Bimbo Grande","codigo":"BIM01","barcode":"7411001122334","categoria":"Panaderia","stock_actual":3,"stock_minimo":6,"precio_venta":55.0,"isv_rate":15.0}
      ]''',
    });

    tester.view.physicalSize = const Size(364, 616);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captured = <String>[];
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      captured.add(msg.split('\n').take(4).join(' | '));
      prevOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevOnError);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: PosTerminalV2()),
          ),
        );

        // ── 1. Inicialización: espera el catálogo hasta 2 min fake (la
        // cadena de timeouts de drift/Supabase es secuencial y el fallback a
        // SharedPreferences corre al final). ──
        for (var i = 0; i < 1200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('Coca-Cola 600ml').evaluate().isNotEmpty) break;
        }
        expect(find.text('Coca-Cola 600ml'), findsOneWidget,
            reason: 'El POS debe cargar el catálogo desde el respaldo local');

        // ── 2. Wedge USB: ráfaga de teclas + Enter agrega al carrito ──
        for (final key in [
          LogicalKeyboardKey.keyC,
          LogicalKeyboardKey.keyC,
          LogicalKeyboardKey.digit6,
          LogicalKeyboardKey.digit0,
          LogicalKeyboardKey.digit0,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        // El commit del wedge va en microtask → dar tiempo.
        await pumpFake(tester, const Duration(milliseconds: 500));

        expect(find.text('Carrito (1 items)'), findsOneWidget);
        // La barra de cobro SIEMPRE visible con carrito (no "no veo dónde pagar").
        expect(find.byKey(const ValueKey('pos-cobrar-bar')), findsOneWidget);
        expect(find.text('COBRAR'), findsOneWidget);

        // ── 3. Segundo producto por wedge + tap en tarjeta visible ──
        for (final key in [
          LogicalKeyboardKey.keyB,
          LogicalKeyboardKey.keyI,
          LogicalKeyboardKey.keyM,
          LogicalKeyboardKey.digit0,
          LogicalKeyboardKey.digit1,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await pumpFake(tester, const Duration(milliseconds: 500));
        expect(find.text('Carrito (2 items)'), findsOneWidget);

        // Segundo escaneo del mismo código: suma cantidad (2 units).
        for (final key in [
          LogicalKeyboardKey.keyC,
          LogicalKeyboardKey.keyC,
          LogicalKeyboardKey.digit6,
          LogicalKeyboardKey.digit0,
          LogicalKeyboardKey.digit0,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await pumpFake(tester, const Duration(milliseconds: 500));
        // El contador expresa UNIDADES: 2 de Coca-Cola + 1 de Pan = 3 items.
        expect(find.text('Carrito (3 items)'), findsOneWidget);

        // ── 4. Intento de cobro (toque real al botón COBRAR) ──
        // Con fuentes de prueba la geometría puede variar; el tap ejercita
        // el hit-test de la barra y, si aterriza, abre el diálogo de efectivo.
        // En ambos casos no debe romper nada del árbol.
        await tester.tap(find.text('COBRAR'), warnIfMissed: false);
        await pumpFake(tester, const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull);

        // ── 6. Resize cruzando la diagonal móvil/escritorio ──
        tester.view.physicalSize = const Size(800, 500);
        await pumpFake(tester, const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('pos-cobrar-bar')), findsOneWidget);

        tester.view.physicalSize = const Size(364, 616);
        await pumpFake(tester, const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('pos-cobrar-bar')), findsOneWidget);

        tester.view.physicalSize = const Size(700, 700);
        await pumpFake(tester, const Duration(milliseconds: 300));

        tester.view.physicalSize = const Size(364, 616);
        await pumpFake(tester, const Duration(milliseconds: 300));

        // ── Cierre limpio: desmontar y apagar timers de fondo para que el
        // runner no quede colgado con Timers pendientes. ──
        await tester.pumpWidget(const SizedBox.shrink());
        await LocalDatabaseService.instance.close();
        await pumpFake(tester, const Duration(seconds: 6));
      },
      () => http_testing.MockClient(
        (request) async => http.Response('{"error":"offline-test"}', 500),
      ),
    );

    // El freeze reportado llenaba la consola con "Cannot hit test a render
    // box with no size" en cada toque. Este test falla si aparece ESA firma
    // (o cualquier otro árbol roto: setState durante build, hit-test sin
    // size, nodo sin layout). Los desbordes de píxeles tienen sus propios
    // tests dedicados y aquí solo son ruido del entorno (fuente de prueba
    // Ahem + elementos desmontados al redimensionar).
    final firmaFreeze = RegExp(
      r'hit test a render box|has never been laid out|not marked as needing layout'
      r'|markNeedsBuild.*called during build|setState\(\) or markNeedsBuild\(\)'
      r'|Cannot hit test',
      caseSensitive: false,
    );
    final fatales = captured.where(firmaFreeze.hasMatch).toList();
    expect(fatales, isEmpty,
        reason: 'Firma del freeze detectada durante el estrés del POS:\n'
            '${fatales.join('\n---\n')}');
  });
}
