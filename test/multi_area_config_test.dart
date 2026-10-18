// Tests funcionales de la configuración Multi-Área:
// catálogo de áreas de negocio, defaults por área, persistencia de flags
// por empresa, toggle de módulos y restablecimiento.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AreasNegocio (catálogo)', () {
    test('porId devuelve el área correcta', () {
      expect(AreasNegocio.porId('retail').id, AreasNegocio.retail);
      expect(AreasNegocio.porId('CANAL_TRADICIONAL').id, AreasNegocio.canalTradicional);
      expect(AreasNegocio.porId('General').id, AreasNegocio.general);
    });

    test('área desconocida cae a retail (default Honduras)', () {
      final area = AreasNegocio.porId('agricultura');
      expect(area.id, AreasNegocio.retail);
      expect(AreasNegocio.porId('').id, AreasNegocio.retail);
    });

    test('modulosPorDefecto por área', () {
      expect(AreasNegocio.modulosPorDefecto('retail'), [
        'pos',
        'facturacion',
        'inventario',
        'crm',
        'contabilidad',
      ]);
      expect(AreasNegocio.modulosPorDefecto('canal_tradicional'), [
        'pos',
        'facturacion',
        'crm',
        'inventario',
      ]);
      expect(AreasNegocio.modulosPorDefecto('general'), [
        'facturacion',
        'inventario',
        'contabilidad',
        'rrhh',
        'crm',
        'pos',
        'comercial',
        'membresias',
        'cotizaciones',
      ]);
    });

    test('área desconocida devuelve lista vacía', () {
      expect(AreasNegocio.modulosPorDefecto('desconocido'), isEmpty);
    });
  });

  group('MultiAreaConfig', () {
    test('siembra defaults según empresa.area_negocio', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'retail',
        modulosAsignados: AreasNegocio.todosModulos,
      );

      expect(config.inicializado, isTrue);
      expect(config.areaNegocio, 'retail');
      expect(config.areaInfo.id, 'retail');
      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.moduloActivo('pos'), isTrue);
      expect(config.moduloActivo('educacion'), isFalse);
    });

    test('persiste flags por empresa y los respeta en recargas', () async {
      final config = MultiAreaConfig.instance;
      // Con asignación del servidor: los flags locales solo pueden apagar
      // módulos de la asignación, nunca reactivar lo que el plan no incluye.
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'retail',
        modulosAsignados: ['pos', 'facturacion', 'inventario', 'crm', 'contabilidad'],
      );
      await config.setModuloActivo('pos', false);

      // Simula un nuevo login: recarga la misma empresa con la misma asignación.
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'retail',
        modulosAsignados: ['pos', 'facturacion', 'inventario', 'crm', 'contabilidad'],
      );

      expect(
        config.moduloActivo('pos'),
        isFalse,
        reason: 'no debe re-sembrar defaults si ya hay configuración',
      );
      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.areaNegocio, 'retail');
    });

    test('módulo agregado por el owner tras un upgrade entra activo', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'retail',
        modulosAsignados: ['pos', 'facturacion'],
      );
      await config.setModuloActivo('pos', false);

      // Nuevo login con más módulos (plan mejorado / owner asignó membresías).
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'retail',
        modulosAsignados: ['pos', 'facturacion', 'membresias'],
      );

      expect(config.moduloActivo('pos'), isFalse, reason: 'el flag local del usuario se respeta');
      expect(config.moduloActivo('membresias'), isTrue,
          reason: 'lo nuevo de la asignación se activa por defecto');
    });

    test('módulo retirado de la asignación desaparece aunque el flag diga lo contrario', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'general',
        modulosAsignados: ['pos', 'facturacion', 'contabilidad', 'rrhh'],
      );

      // El plan bajó: contabilidad/rrhh ya no están en la asignación.
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'general',
        modulosAsignados: ['pos', 'facturacion'],
      );

      expect(config.moduloActivo('contabilidad'), isFalse,
          reason: 'la asignación del servidor manda sobre flags viejos');
      expect(config.moduloActivo('rrhh'), isFalse);
      expect(config.moduloActivo('pos'), isTrue);
    });

    test('empresas diferentes mantienen configuración independiente', () async {
      final config = MultiAreaConfig.instance;

      await config.cargar(empresaCodigo: 'EMPRESA-A', areaNegocio: 'retail');
      await config.setModuloActivo('facturacion', false);

      await config.cargar(empresaCodigo: 'EMPRESA-B', areaNegocio: 'canal_tradicional');

      expect(config.areaNegocio, 'canal_tradicional');
      expect(
        config.moduloActivo('facturacion'),
        isTrue,
        reason: 'empresa B no hereda los flags desactivados de empresa A',
      );
      expect(config.moduloActivo('inventario'), isTrue);
    });

    test('setAreaNegocio restablece los módulos por defecto', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'retail');

      await config.setAreaNegocio('comercial_generico');

      expect(config.areaNegocio, 'comercial_generico');
      expect(
        config.modulosActivos.toSet(),
        AreasNegocio.modulosPorDefecto('comercial_generico').toSet(),
      );
      expect(config.moduloActivo('pos'), isFalse);
    });

    test('setModuloActivo enciende y apaga un módulo', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'retail');

      await config.setModuloActivo('analytics', true);
      expect(config.moduloActivo('analytics'), isTrue);

      await config.setModuloActivo('analytics', false);
      expect(config.moduloActivo('analytics'), isFalse);
    });

    test('restablecerPorArea vuelve a los defaults del área', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'canal_tradicional');

      await config.setModuloActivo('pos', false);
      await config.setModuloActivo('facturacion', false);

      await config.restablecerPorArea();

      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.moduloActivo('pos'), isTrue);
    });

    test('sin área conocida usa los módulos asignados', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: 'agricultura',
        modulosAsignados: ['facturacion', 'crm'],
      );

      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.moduloActivo('crm'), isTrue);
      expect(config.moduloActivo('pos'), isFalse);
    });

    test('sin área y sin asignados habilita todos los módulos', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(
        empresaCodigo: 'EMPRESA-1',
        areaNegocio: '',
        modulosAsignados: const [],
      );

      expect(config.moduloActivo('analytics'), isTrue);
      expect(config.moduloActivo('pos'), isTrue);
      expect(config.modulosActivos.length, AreasNegocio.todosModulos.length);
    });
  });
}
