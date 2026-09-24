// lib/Shared/reportes/report_data_provider.dart
// Capa de acceso a datos para el sistema de reportes.
//
// ReportTools NUNCA ejecuta SQL: dependen de esta interfaz, que garantiza:
// 1. Las consultas SIEMPRE reciben el `empresaId` del tenant autenticado
//    (AuthController / AIManager) — nunca elige el tenant el modelo IA.
// 2. Toda consulta filtra por `empresaId`: es imposible mezclar tenants.
//
// `ReportDataProviderDrift` es la implementación de producción (drift local).
// `ReportDataProviderFake` se usa en tests unitarios (herméticos, sin sqlite).

import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

abstract class ReportDataProvider {
  Future<Empresa?> empresa(String codigo);

  Future<List<Factura>> facturas(String empresaId);

  Future<List<Transaccione>> transacciones(String empresaId);

  Future<List<PosVenta>> posVentas(String empresaId);

  Future<List<PosVentaItem>> posVentaItems(List<String> ventaIds);

  Future<List<Compra>> compras(String empresaId);

  Future<List<CompraItem>> compraItems(List<String> compraIds);

  Future<List<Producto>> productos(String empresaId);

  Future<List<Cliente>> clientes(String empresaId);

  Future<List<Empleado>> empleados(String empresaId);

  Future<List<NominaData>> nomina(String empresaId);

  Future<List<FiadoAbono>> fiadoAbonos(String empresaId);

  Future<List<PosClienteCreditoData>> posClienteCredito(String empresaId);

  Future<List<PosArqueoCajaData>> arqueosCaja(String empresaId);
}

/// Implementación de producción: usa la base local drift (offline-first).
class ReportDataProviderDrift implements ReportDataProvider {
  ReportDataProviderDrift();

  AppDatabase get _db => LocalDatabaseService.instance.database;

  @override
  Future<Empresa?> empresa(String codigo) async {
    if (codigo.isEmpty) return null;
    return await (_db.select(_db.empresas)
          ..where((e) => e.codigo.equals(codigo)))
        .getSingleOrNull();
  }

  @override
  Future<List<Factura>> facturas(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.facturas)
          ..where((f) => f.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<Transaccione>> transacciones(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.transacciones)
          ..where((t) => t.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<PosVenta>> posVentas(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.posVentas)
          ..where((v) => v.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<PosVentaItem>> posVentaItems(List<String> ventaIds) async {
    if (ventaIds.isEmpty) return const [];
    return await (_db.select(_db.posVentaItems)
          ..where((i) => i.ventaId.isIn(ventaIds)))
        .get();
  }

  @override
  Future<List<Compra>> compras(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.compras)
          ..where((c) => c.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<CompraItem>> compraItems(List<String> compraIds) async {
    if (compraIds.isEmpty) return const [];
    return await (_db.select(_db.compraItems)
          ..where((i) => i.compraId.isIn(compraIds)))
        .get();
  }

  @override
  Future<List<Producto>> productos(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.productos)
          ..where((p) => p.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<Cliente>> clientes(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.clientes)
          ..where((c) => c.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<Empleado>> empleados(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.empleados)
          ..where((e) => e.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<NominaData>> nomina(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.nomina)
          ..where((n) => n.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<FiadoAbono>> fiadoAbonos(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.fiadoAbonos)
          ..where((a) => a.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<PosClienteCreditoData>> posClienteCredito(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.posClienteCredito)
          ..where((c) => c.empresaId.equals(empresaId)))
        .get();
  }

  @override
  Future<List<PosArqueoCajaData>> arqueosCaja(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return await (_db.select(_db.posArqueoCaja)
          ..where((a) => a.empresaId.equals(empresaId)))
        .get();
  }
}

/// Implementación de prueba: datos en memoria. Todas las consultas filtran
/// por `empresaId` (mismo contrato que la implementación de producción).
class ReportDataProviderFake implements ReportDataProvider {
  ReportDataProviderFake();

  final List<Empresa> empresas = [];
  final List<Factura> facturasDb = [];
  final List<Transaccione> transaccionesDb = [];
  final List<PosVenta> posVentasDb = [];
  final List<PosVentaItem> posVentaItemsDb = [];
  final List<Compra> comprasDb = [];
  final List<CompraItem> compraItemsDb = [];
  final List<Producto> productosDb = [];
  final List<Cliente> clientesDb = [];
  final List<Empleado> empleadosDb = [];
  final List<NominaData> nominaDb = [];
  final List<FiadoAbono> fiadoAbonosDb = [];
  final List<PosClienteCreditoData> posClienteCreditoDb = [];
  final List<PosArqueoCajaData> arqueosDb = [];

  @override
  Future<Empresa?> empresa(String codigo) async {
    for (final e in empresas) {
      if (e.codigo == codigo) return e;
    }
    return null;
  }

  @override
  Future<List<Factura>> facturas(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return facturasDb.where((f) => f.empresaId == empresaId).toList();
  }

  @override
  Future<List<Transaccione>> transacciones(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return transaccionesDb.where((t) => t.empresaId == empresaId).toList();
  }

  @override
  Future<List<PosVenta>> posVentas(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return posVentasDb.where((v) => v.empresaId == empresaId).toList();
  }

  @override
  Future<List<PosVentaItem>> posVentaItems(List<String> ventaIds) async {
    if (ventaIds.isEmpty) return const [];
    return posVentaItemsDb
        .where((i) => ventaIds.contains(i.ventaId))
        .toList();
  }

  @override
  Future<List<Compra>> compras(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return comprasDb.where((c) => c.empresaId == empresaId).toList();
  }

  @override
  Future<List<CompraItem>> compraItems(List<String> compraIds) async {
    if (compraIds.isEmpty) return const [];
    return compraItemsDb
        .where((i) => compraIds.contains(i.compraId))
        .toList();
  }

  @override
  Future<List<Producto>> productos(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return productosDb.where((p) => p.empresaId == empresaId).toList();
  }

  @override
  Future<List<Cliente>> clientes(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return clientesDb.where((c) => c.empresaId == empresaId).toList();
  }

  @override
  Future<List<Empleado>> empleados(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return empleadosDb.where((e) => e.empresaId == empresaId).toList();
  }

  @override
  Future<List<NominaData>> nomina(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return nominaDb.where((n) => n.empresaId == empresaId).toList();
  }

  @override
  Future<List<FiadoAbono>> fiadoAbonos(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return fiadoAbonosDb.where((a) => a.empresaId == empresaId).toList();
  }

  @override
  Future<List<PosClienteCreditoData>> posClienteCredito(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return posClienteCreditoDb
        .where((c) => c.empresaId == empresaId)
        .toList();
  }

  @override
  Future<List<PosArqueoCajaData>> arqueosCaja(String empresaId) async {
    if (empresaId.isEmpty) return const [];
    return arqueosDb.where((a) => a.empresaId == empresaId).toList();
  }
}