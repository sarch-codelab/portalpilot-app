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

  testWidgets('A5/P3 - Chat IA a 320px (ventana mínima): DESBORDA el layout [BUG CONFIRMADO]', (tester) async {
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
    // Defecto visual real: chat_ia_home.dart no degrada en anchos < ~360px.
    // Overflow HORIZONTAL de 161px en el Row del banner del greeting
    // (chat_ia_home.dart:328: Row('Chat IA' + chip 'En línea')): su Expanded
    // colapsa a <=57px pero el contenido natural mide ~218px.
    // Overflow VERTICAL de 6px en la Column de textos de cada sugerencia
    // (chat_ia_home.dart:547): limitada a h<=62px con contenido de 68px.
    expect(err, isNotNull,
        reason: 'ChatIA 320px: RenderFlex overflow horizontal de 161px (chat_ia_home.dart:328) y verticales de 6px '
            '(chat_ia_home.dart:547) - la UI NO es adaptativa a anchos mínimos');
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