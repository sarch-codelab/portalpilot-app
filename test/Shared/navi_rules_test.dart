// Tests de NaviRules.puedeAccederA: el fix de normalización de roles evita
// bloquear a administradores cuyo rol llegue distinto de "admin" (p. ej. la
// cuenta staff de Portal Pilot con rol "Administrador del Sistema").

import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/services/navi_rules.dart';

void main() {
  group('NaviRules.puedeAccederA — roles administrativos', () {
    test('admin accede a reportes', () {
      expect(NaviRules.puedeAccederA('admin', 'reportes'), isTrue);
    });

    test('Administrador del Sistema accede a reportes y usuarios', () {
      expect(NaviRules.puedeAccederA('Administrador del Sistema', 'reportes'), isTrue);
      expect(NaviRules.puedeAccederA('administrador del sistema', 'gestionar_usuarios'), isTrue);
    });

    test('Admin impreso con acentos/mayúsculas accede', () {
      expect(NaviRules.puedeAccederA('Admín', 'reportes'), isTrue);
    });

    test('Super Admin accede', () {
      expect(NaviRules.puedeAccederA('Super Admin', 'reportes'), isTrue);
    });

    test('root accede', () {
      expect(NaviRules.puedeAccederA('root', 'reportes'), isTrue);
    });

    test('Gerente accede a reportes', () {
      expect(NaviRules.puedeAccederA('Gerente', 'reportes'), isTrue);
    });

    test('dueño accede a reportes', () {
      expect(NaviRules.puedeAccederA('Dueño', 'reportes'), isTrue);
    });

    test('vendedor aún NO accede a reportes (permisos limitados)', () {
      expect(NaviRules.puedeAccederA('vendedor', 'reportes'), isFalse);
    });

    test('contador accede a reportes pero no a gestionar_usuarios', () {
      expect(NaviRules.puedeAccederA('contador', 'reportes'), isTrue);
      expect(NaviRules.puedeAccederA('contador', 'gestionar_usuarios'), isFalse);
    });

    test('Empleado sin rol administrativo NO accede a reportes', () {
      expect(NaviRules.puedeAccederA('Empleado', 'reportes'), isFalse);
    });

    test('rol vacío no accede', () {
      expect(NaviRules.puedeAccederA('', 'reportes'), isFalse);
    });
  });
}