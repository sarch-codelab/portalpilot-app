// ignore_for_file: avoid_print
// ATAQUE 5 — Interfaz Gráfica Hostil (UI/UX stress).
// Orientación + redimensiones violentas a mitad de transiciones de ruta.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/Facturacion/clientes/cliente_form.dart';
import 'package:portal_pilot_app/Modules/ChatIA/chat_ia_home.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRouteAndResize(WidgetTester tester, Widget target, Size a, Size b) async {
    await tester.binding.setSurfaceSize(a);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => Scaffold(
        body: Center(child: ElevatedButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => target)),
          child: const Text('IR'),
        )),
      )),
    ));
    await tester.tap(find.text('IR'));
    await tester.pump();                       // arranca la transición de ruta
    await tester.binding.setSurfaceSize(b);    // resize VIOLENTO a mitad de animacion
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
  }

  testWidgets('A5/P1 - resize 800x600 -> 400x600 durante transición a ClienteForm', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'clientes_facturacion': '[]'});
    await pumpRouteAndResize(tester, const ClienteForm(), const Size(800, 600), const Size(400, 600));
    final err = tester.takeException();
    print('[A5/P1] resize en transición (ClienteForm): ${err?.toString() ?? 'sin overflow'}');
    expect(err, isNull, reason: 'Ninguna fila del form debe desbordar al colapsar la ventana');
  });

  testWidgets('A5/P2 - Portrait 400x800 -> Landscape 800x400 en plena transición a ClienteForm', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'clientes_facturacion': '[]'});
    // Fila teléfono+email y tarjetas de cliente en landscape estrecho.
    await pumpRouteAndResize(tester, const ClienteForm(), const Size(400, 800), const Size(800, 400));
    final err = tester.takeException();
    print('[A5/P2] giro portrait->landscape en transición: ${err?.toString() ?? 'sin overflow'}');
    expect(err, isNull);
  });

  testWidgets('A5/P3 - Chat IA a 320px (ventana mínima): NO desborda [REMEDIADO]', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 640));
    final captured = <String>[];
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      captured.add(details.exception.toString().split('\n').take(3).join(' | '));
      prevOnError?.call(details);
    };
    await tester.pumpWidget(const MaterialApp(home: ChatIAHome()));
    await tester.pump(const Duration(milliseconds: 150));
    FlutterError.onError = prevOnError;
    for (var i = 0; i < captured.length; i++) {
      print('[A5/P3-excepcion#$i] $captured[i]');
    }
    final err = tester.takeException();
    print('[A5/P3-detalle] ${err?.toString() ?? 'sin overflow'}');
    // El título del AppBar usa el modo stack (columna) cuando el ancho
    // disponible es < 150px, por lo que el chip "En línea" NO desborda a los
    // 320px mínimos. Antes desbordaba 48-161px (bug confirmado).
    expect(captured, isEmpty,
        reason: 'ChatIA 320px: no debe haber RenderFlex overflow (título en '
            'modo stack para anchos mínimos)');
    expect(err, isNull,
        reason: 'ChatIA 320px: no debe lanzar overflow tras el arreglo del AppBar');
  });

  testWidgets('A5/P4 - MarkdownBody con tabla gigante a 400px: overflow de tabla', (tester) async {
    final md = '|Col A|Col B|\n|---|---|\n|${'X' * 120}|${'Y' * 120}|';
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MarkdownBody(data: md))));
    await tester.pump();
    final err = tester.takeException();
    print('[A5/P4] tabla markdown 400px: ${err?.toString() ?? 'clipeada sin crash (RenderFlex overflow en Tabla? o textwrap flojo)'}');
  });
}