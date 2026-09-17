// ignore_for_file: avoid_print
// ATAQUE 3 — Memory Leak Incesante.
// ListView/GridView con muchos ítems y entrar/salir 20 veces, midiendo
// limpieza de controladores, tickers y suscripciones.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/ChatIA/chat_ia_home.dart';
import 'package:portal_pilot_app/Modules/Facturacion/clientes/cliente_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A3/P1 - 20 ciclos entrar/salir de ChatIA (AnimationController.repeat) sin ticker leak', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(const MaterialApp(home: ChatIAHome()));
      await tester.pump(const Duration(milliseconds: 200)); // el pulso corre
      await tester.pumpWidget(const SizedBox());            // salida
      // Si _pulseCtrl no se dispose en State.dispose, el Ticker sigue vivo:
      // pumpAndSettle fallaría ("A Ticker was still active") o colgaría.
      await tester.pumpAndSettle();
    }
    final err = tester.takeException();
    print('[A3/P1] 20x chat + dispose: ${err?.toString() ?? 'sin ticker/timer fugado'}');
    expect(err, isNull, reason: 'Ticker de ChatIAHome debe liberarse en dispose() (chat_ia_home.dart:93)');
  });

  testWidgets('A3/P2 - 1000 clientes: ClienteForm usa SliverList.builder VIRTUALIZADO (no construye los 1000)', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final clientes = List.generate(1000, (i) => {
      'id': '$i',
      'nombre': 'Cliente $i',
      'rtn': '',
      'direccion': '',
      'telefono': '',
      'email': 'c$i@test.com',
    });
    SharedPreferences.setMockInitialValues({'clientes_facturacion': jsonEncode(clientes)});
    await tester.pumpWidget(const MaterialApp(home: ClienteForm()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final err = tester.takeException();
    // El listado es SliverPadding > SliverList.builder: el delegate conoce los
    // 1000 ítems pero SOLO se materializan las tarjetas del viewport + cache.
    final builderDelegates = find
        .byType(SliverList, skipOffstage: false)
        .evaluate()
        .map((e) => (e.widget as SliverList).delegate)
        .whereType<SliverChildBuilderDelegate>()
        .toList();
    final itemCount = builderDelegates.isEmpty ? 0 : builderDelegates.first.estimatedChildCount;
    final builtCards = find.byType(CircleAvatar).evaluate().length;
    print('[A3/P2] 1000 clientes: itemCount=$itemCount | tarjetas MATERIALIZADAS=$builtCards | '
        'error=${err?.toString() ?? 'ninguno'}');
    expect(err, isNull);
    expect(itemCount, 1000,
        reason: 'SliverList.builder conoce los 1000 ítems (itemCount) pero NO construye todos a la vez');
    expect(builtCards, lessThan(50),
        reason: 'Virtualización: con SliverList.builder solo se construyen las tarjetas visibles, '
            'no los 1000 widgets del dataset en cada frame');
    // ciclo 2: entrar/salir 20 veces para recorrer el peor caso.
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(const MaterialApp(home: ClienteForm()));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    }
    final err2 = tester.takeException();
    print('[A3/P2b] 20x entrar/salir de la lista de 1000 (lazy): ${err2?.toString() ?? 'sin crash'}');
    expect(err2, isNull);
  });

  test('A3/P3 - suscripción gestionada: HomeScreen guarda y cancela la StreamSubscription (REMEDIADO)', () {
    // home_screen.dart ahora almacena la suscripción en `_syncStatusSubscription`
    // y la cancela en dispose() (antes: listen() huérfano que se acumulaba en
    // cada `pushAndRemoveUntil(HomeScreen())`).
    final src = File('lib/Home/home_screen.dart').readAsStringSync();
    expect(src.contains('_syncStatusSubscription = '), isTrue,
        reason: 'home_screen.dart debe guardar la suscripción para poder cancelarla');
    expect(src.contains('_syncStatusSubscription?.cancel()'), isTrue,
        reason: 'dispose() debe cancelar la suscripción para no acumular leaks por re-mount');
    print('[A3/P3] home_screen.dart: suscripción guardada y cancelada en dispose [REMEDIADO]');
  });
}