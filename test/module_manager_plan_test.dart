import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Modules/module_manager.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';

/// Regresión del BUG 1: el backend entrega modulos_app (ids de APP:
/// pos, canal_tradicional, contabilidad...) y ModuleManager traducía con
/// isWebModuleAvailable() (que solo acepta ids WEB: pos_caja, ...) → set vacío
/// → Home caía al fallback hardcodeado ['facturacion','inventario','crm','pos'].
Future<void> _loginConModulos(
  List<String> modulos,
  String plan, {
  List<String> features = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await AuthController.instance.setSession(
    nombre: 'Prueba',
    apellido: 'Modulos',
    email: 'mods@ejemplo.com',
    rol: 'admin',
    area: 'compras',
    rango: '1',
    empresaCodigo: 'MOD01',
    empresaNombre: 'Empresa Modulos',
    token: 'token-prueba',
    modulos: modulos,
    features: features,
    empresaPlan: plan,
    empresaAreaNegocio: 'general',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModuleManager traduce modulos_app del backend (BUG 1)', () {
    test('Pulpería: los ids app del login producen módulos activos', () async {
      await _loginConModulos(const [
        'settings',
        'pos',
        'canal_tradicional',
        'inventario',
        'facturacion',
        'fiscal_advanced',
        'contabilidad',
      ], 'Pulpería');
      await ModuleManager.instance.syncWithBackend();

      final activos = ModuleManager.instance.activeAppModuleIds;
      expect(
        activos,
        containsAll([
          'settings',
          'pos',
          'canal_tradicional',
          'inventario',
          'facturacion',
          'fiscal_advanced',
          'contabilidad',
        ]),
      );
      expect(ModuleManager.instance.activeWebModuleIds, isNotEmpty);
      expect(ModuleManager.instance.getActiveModulesForHome(), isNotEmpty);
    });

    test('Pulpería preset coincide con sus cinco módulos publicados', () async {
      await _loginConModulos(const [], 'Pulpería');
      await ModuleManager.instance.applyPreset('pulperia');

      expect(
        ModuleManager.instance.activeWebModuleIds,
        equals({
          'pos_caja',
          'cuentas_por_cobrar',
          'inventario_basico',
          'facturacion_sar',
          'contabilidad_pyme',
        }),
      );
      expect(
        ModuleManager.instance.activeAppModuleIds,
        containsAll({
          'pos',
          'canal_tradicional',
          'inventario',
          'facturacion',
          'contabilidad',
        }),
      );
    });

    test('una lista vacía del backend no activa módulos genéricos', () async {
      await _loginConModulos(const [], 'Pulpería');
      await ModuleManager.instance.syncWithBackend();

      expect(ModuleManager.instance.activeAppModuleIds, isEmpty);
    });

    test(
      'restaurar una sesión sin módulos no recupera el catálogo genérico',
      () async {
        SharedPreferences.setMockInitialValues({
          'company_code': 'MOD01',
          'auth_token': '',
        });
        await AuthController.instance.restore();

        expect(AuthController.instance.modulos, isEmpty);
      },
    );

    test(
      'Chat IA requiere la feature ia aunque el id app esté asignado',
      () async {
        await _loginConModulos(
          const ['chat_ia'],
          'Pulpería',
          features: const ['pos'],
        );
        await ModuleManager.instance.syncWithBackend();

        expect(ModuleManager.instance.isAppModuleAllowed('chat_ia'), isFalse);
      },
    );

    test('Tienda: los ids app del login producen módulos activos', () async {
      await _loginConModulos(const [
        'settings',
        'pos',
        'canal_moderno',
        'inventario',
        'facturacion',
        'compras_proveedores',
        'cotizaciones',
        'analytics',
      ], 'Tienda');
      await ModuleManager.instance.syncWithBackend();

      expect(
        ModuleManager.instance.activeAppModuleIds,
        containsAll([
          'settings',
          'pos',
          'canal_moderno',
          'inventario',
          'facturacion',
          'compras_proveedores',
          'cotizaciones',
          'analytics',
        ]),
      );
      expect(
        ModuleManager.instance.getActiveModulesForHome().length,
        greaterThanOrEqualTo(8),
      );
    });

    test(
      'ids WEB del backend siguen funcionando (retrocompatibilidad)',
      () async {
        await _loginConModulos(const [
          'pos_caja',
          'inventario_basico',
        ], 'Business');
        await ModuleManager.instance.syncWithBackend();

        expect(
          ModuleManager.instance.activeWebModuleIds,
          containsAll(['pos_caja', 'inventario_basico']),
        );
        expect(
          ModuleManager.instance.activeAppModuleIds,
          containsAll(['pos', 'inventario']),
        );
      },
    );

    test('un id desconocido no genera módulos', () async {
      await _loginConModulos(const ['no_existe'], 'Prueba');
      await ModuleManager.instance.syncWithBackend();

      expect(ModuleManager.instance.activeWebModuleIds, isEmpty);
      expect(ModuleManager.instance.activeExtraAppModuleIds, isEmpty);
    });
  });
}
