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
      expect(AreasNegocio.porId('Educacion').id, AreasNegocio.educacion);
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
        'educacion',
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
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'retail');
      await config.setModuloActivo('pos', false);

      // Simula un nuevo login: recarga la misma empresa.
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'retail');

      expect(
        config.moduloActivo('pos'),
        isFalse,
        reason: 'no debe re-sembrar defaults si ya hay configuración',
      );
      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.areaNegocio, 'retail');
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

      await config.setModuloActivo('educacion', true);
      expect(config.moduloActivo('educacion'), isTrue);

      await config.setModuloActivo('educacion', false);
      expect(config.moduloActivo('educacion'), isFalse);
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

      expect(config.areaNegocio, 'agricultura');
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

      expect(config.moduloActivo('educacion'), isTrue);
      expect(config.moduloActivo('pos'), isTrue);
      expect(config.modulosActivos.length, AreasNegocio.todosModulos.length);
    });
  });
}
