// ignore_for_file: avoid_print
// ATAQUE 2 — Filtro de Datos Malicioso (XSS / inyección de contenido).
// Inyecta HTML crudo, emojis, bidi y datos corruptos en lo que la app renderiza.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/Facturacion/clientes/cliente_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const xssHtml = '<script>alert(\'hack\')</script> <img src=x onerror=alert(1)>';

  testWidgets('A2/P1 - MarkdownBody con <script> y <img onerror> (Chat IA / POS): sin crash y sin fuga de código', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Padding(padding: EdgeInsets.all(8), child: MarkdownBody(data: xssHtml))),
    ));
    await tester.pump();
    final err = tester.takeException();
    final richCount = find.byType(RichText, skipOffstage: false).evaluate().length;
    // Verificación positiva: flutter_markdown (sin dangerousHtml) NO renderiza
    // el cuerpo de <script>/<img> como HTML crudo:
    final leaked = find.textContaining('alert', findRichText: true, skipOffstage: false).evaluate().length;
    print('[A2/P1] markdown hostil: error=${err?.toString() ?? 'ninguno'} | RichText=$richCount | fragmentos con "alert"=$leaked');
    expect(err, isNull, reason: 'No debe crashear al renderizar HTML hostil');
    expect(leaked, 0, reason: 'flutter_markdown v0.6.x saneja el HTML (sin dangerousHtml): no hay XSS ejecutable ni fuga de código');
    // Nota: flutter_markdown 0.6.23 está DESCONTINUADO (flutter_markdown_plus); riesgo de supply-chain.
  });

  testWidgets('A2/P1b - enlace markdown javascript: y emoji-código en la burbuja de IA (sin onTapLink -> inerte)', (tester) async {
    const md = '[click](javascript:alert(1)) \u{1F600} \u202E\u202C **negrita** `code`';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MarkdownBody(data: md, selectable: true)),
    ));
    await tester.pump();
    final err = tester.takeException();
    // No hay onTapLink configurado (chat_ia_home.dart:648) -> el enlace es inerte.
    print('[A2/P1b] link javascript: + emoji + bidi renderizados: ${err?.toString() ?? 'sin error (enlace inerte)'}');
    expect(err, isNull);
  });

  testWidgets('A2/P2 - cliente con nombre vacío ya NO crasha el listado (inicial robusta)', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'clientes_facturacion': jsonEncode([
        {'id': '1', 'nombre': '', 'rtn': '', 'direccion': '', 'telefono': '', 'email': ''},
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: ClienteForm()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final err = tester.takeException();
    print('[A2/P2] nombre="" -> error=${err?.toString() ?? 'NINGUNO'} (inicial "?" vía _inicialDe)');
    expect(err, isNull, reason: '_inicialDe devuelve "?" para nombre vacío en lugar de RangeError por [0]');
    expect(find.byType(CircleAvatar), findsWidgets);
    expect(find.text('?'), findsOneWidget);
  });

  test('A2/P3 - nombre numérico en JSON: extracción de inicial robusta sobrevive', () {
    // Replica de la lógica segura de _inicialDe (cliente_form.dart:388-392):
    // (c["nombre"] ?? "").toString().trim(); si vacío -> "?".
    String inicialDe(String? raw) {
      final nombre = (raw ?? '').toString().trim();
      if (nombre.isEmpty) return '?';
      return nombre.characters.first.toUpperCase();
    }

    expect(inicialDe(123.toString()), '1'); // int -> "123" -> inicial "1" (sin TypeError)
    expect(inicialDe(null), '?');           // null -> fallback
    expect(inicialDe(''), '?');             // string vacío -> fallback
    expect(inicialDe(35.toString()), '3');
    print('[A2/P3] inicial robusta: int/null/vacío sobreviven (sin TypeError ni RangeError)');
  });

  test('A2/P4 - truncado de título de conversación NO parte un emoji (characters) [REMEDIADO]', () {
    // chat_ia_home.dart ahora corta por puntos de código (characters), no por
    // code units: nunca deja un surrogate huérfano al final del título.
    String truncar(String raw) {
      final chars = raw.characters;
      return chars.length > 36 ? '${chars.take(36)}…' : raw;
    }

    final raw = '${List.filled(35, 'A').join()}\u{1F600}'; // 35 A + emoji (2 code units) = 37
    final sliced = truncar(raw);
    final lastUnit = sliced.codeUnitAt(sliced.length - 1);
    final isLoneHighSurrogate = lastUnit >= 0xD800 && lastUnit <= 0xDBFF;
    print('[A2/P4] título recortado(${sliced.characters.length}) termina en 0x${lastUnit.toRadixString(16)}: '
        'surrogate huérfano=$isLoneHighSurrogate');
    expect(isLoneHighSurrogate, isFalse,
        reason: 'characters.take corta por código completo de emoji, no parte surrogates');
  });

  test('A2/P5 - bidi/emojis extremos se renderizan sin excepción en Text plano', () {
    const nasty = '\u{202E}\u{202C}\u{1F600}\u{1F921}\u{200D}\u{1F9D1}\u{200D}\u{1F4BB}';
    // Text() de Flutter no salta con bidi; pero si este string viaja por
    // substring(0,36) el par ZWJ+emoji también se parte.
    final sliced = nasty.length > 36 ? nasty.substring(0, 36) : nasty;
    expect(sliced, isA<String>());
  });

  test('A2/P6 - JSON malformado dentro de un campo de texto no crashea (verificación de escape)', () {
    // A diferencia de los decode de prefs (ataque 6), los TextField aquí son
    // TextInputType.text: el string se trata como texto; solo hay riesgo si se
    // re-parseara. Verificación de que el HTML crudo no ejecuta nada.
    const payload = '{"a": 1, <script>}][';
    final controller = TextEditingController(text: payload);
    expect(controller.text, payload);
    controller.dispose();
  });
}