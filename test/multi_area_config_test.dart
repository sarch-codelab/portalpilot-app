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
      expect(AreasNegocio.porId('comercio').id, AreasNegocio.comercio);
      expect(AreasNegocio.porId('SALUD').id, AreasNegocio.salud);
      expect(AreasNegocio.porId('Educacion').id, AreasNegocio.educacion);
    });

    test('área desconocida cae a General', () {
      final area = AreasNegocio.porId('agricultura');
      expect(area.id, AreasNegocio.general);
      expect(AreasNegocio.porId('').id, AreasNegocio.general);
    });

    test('modulosPorDefecto por área', () {
      expect(AreasNegocio.modulosPorDefecto('finanzas'), [
        'contabilidad',
        'facturacion',
        'inventario',
      ]);
      expect(AreasNegocio.modulosPorDefecto('salud'), [
        'facturacion',
        'inventario',
        'crm',
      ]);
      expect(AreasNegocio.modulosPorDefecto('comercio'), [
        'facturacion',
        'inventario',
        'pos',
        'contabilidad',
        'crm',
      ]);
      expect(
        AreasNegocio.modulosPorDefecto('general'),
        AreasNegocio.todosModulos,
      );
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
        areaNegocio: 'comercio',
        modulosAsignados: AreasNegocio.todosModulos,
      );

      expect(config.inicializado, isTrue);
      expect(config.areaNegocio, 'comercio');
      expect(config.areaInfo.id, 'comercio');
      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.moduloActivo('pos'), isTrue);
      expect(config.moduloActivo('educacion'), isFalse);
    });

    test('persiste flags por empresa y los respeta en recargas', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'comercio');
      await config.setModuloActivo('pos', false);

      // Simula un nuevo login: recarga la misma empresa.
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'comercio');

      expect(
        config.moduloActivo('pos'),
        isFalse,
        reason: 'no debe re-sembrar defaults si ya hay configuración',
      );
      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.areaNegocio, 'comercio');
    });

    test('empresas diferentes mantienen configuración independiente', () async {
      final config = MultiAreaConfig.instance;

      await config.cargar(empresaCodigo: 'EMPRESA-A', areaNegocio: 'comercio');
      await config.setModuloActivo('facturacion', false);

      await config.cargar(empresaCodigo: 'EMPRESA-B', areaNegocio: 'salud');

      expect(config.areaNegocio, 'salud');
      expect(
        config.moduloActivo('facturacion'),
        isTrue,
        reason: 'empresa B no hereda los flags desactivados de empresa A',
      );
      expect(config.moduloActivo('inventario'), isTrue);
    });

    test('setAreaNegocio restablece los módulos por defecto', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'comercio');

      await config.setAreaNegocio('finanzas');

      expect(config.areaNegocio, 'finanzas');
      expect(
        config.modulosActivos.toSet(),
        AreasNegocio.modulosPorDefecto('finanzas').toSet(),
      );
      expect(config.moduloActivo('pos'), isFalse);
    });

    test('setModuloActivo enciende y apaga un módulo', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'comercio');

      await config.setModuloActivo('educacion', true);
      expect(config.moduloActivo('educacion'), isTrue);

      await config.setModuloActivo('educacion', false);
      expect(config.moduloActivo('educacion'), isFalse);
    });

    test('restablecerPorArea vuelve a los defaults del área', () async {
      final config = MultiAreaConfig.instance;
      await config.cargar(empresaCodigo: 'EMPRESA-1', areaNegocio: 'salud');

      await config.setModuloActivo('pos', true);
      await config.setModuloActivo('facturacion', false);

      await config.restablecerPorArea();

      expect(config.moduloActivo('facturacion'), isTrue);
      expect(config.moduloActivo('pos'), isFalse);
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
