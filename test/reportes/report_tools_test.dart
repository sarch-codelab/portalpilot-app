// Tests del ReportToolDispatcher con datos en memoria (herméticos: sin sqlite,
// sin AuthController, sin SharedPreferences).
//
// Verifica: aislamiento por tenant, rango de fechas, agregados, noData,
// permisos por rol y correlativo inyectado.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/reportes/report_builder.dart';
import 'package:portal_pilot_app/Shared/reportes/report_data_provider.dart';
import 'package:portal_pilot_app/Shared/reportes/report_tools.dart';

Transaccione _tx({
  required String id,
  required String empresaId,
  required String tipo,
  required double monto,
  required DateTime fecha,
  String? categoria,
  String? descripcion,
  String? metodoPago,
}) {
  return Transaccione(
    id: id,
    empresaId: empresaId,
    tipo: tipo,
    categoria: categoria,
    descripcion: descripcion,
    monto: monto,
    metodoPago: metodoPago,
    fecha: fecha,
    createdAt: fecha,
    updatedAt: fecha,
    synced: false,
  );
}

Producto _prod({
  required String id,
  required String empresaId,
  required String nombre,
  required int stockActual,
  required int stockMinimo,
  required double precioVenta,
  bool activo = true,
  String? categoria,
  String? codigo,
}) {
  return Producto(
    id: id,
    empresaId: empresaId,
    codigo: codigo,
    nombre: nombre,
    categoria: categoria,
    unidadMedida: 'pza',
    precioCompra: precioVenta * 0.7,
    precioVenta: precioVenta,
    stockMinimo: stockMinimo,
    stockActual: stockActual,
    bodega: 'Principal',
    isvRate: 15,
    exento: false,
    activo: activo,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    synced: false,
  );
}

Factura _factura({
  required String id,
  required String empresaId,
  required String correlativo,
  required double total,
  required DateTime createdAt,
  required double isv15,
  String estado = 'emitida',
}) {
  return Factura(
    id: id,
    empresaId: empresaId,
    correlativo: correlativo,
    tipoDocumento: 'Factura',
    cai: 'CAI-TEST',
    condicionPago: 'Contado',
    tipoVenta: 'Gravada',
    items: Uint8List(0),
    subtotal: total - isv15,
    isv15: isv15,
    isv18: 0,
    descuento: 0,
    total: total,
    estado: estado,
    createdAt: createdAt,
    updatedAt: createdAt,
    synced: false,
  );
}

Compra _compra({
  required String id,
  required String empresaId,
  required String proveedorNombre,
  required double total,
  required DateTime fecha,
  required double isv15,
  double isv18 = 0,
  String estado = 'recibida',
  String? correlativo,
  String? numeroFactura,
}) {
  return Compra(
    id: id,
    empresaId: empresaId,
    correlativo: correlativo,
    proveedorId: 'prv-$id',
    proveedorNombre: proveedorNombre,
    numeroFactura: numeroFactura,
    fecha: fecha,
    estado: estado,
    subtotal: total - isv15 - isv18,
    isv15: isv15,
    isv18: isv18,
    descuento: 0,
    total: total,
    createdAt: fecha,
    updatedAt: fecha,
    synced: false,
  );
}

Cliente _cliente({
  required String id,
  required String empresaId,
  required String nombre,
  bool activo = true,
  String? rtn,
  String? telefono,
}) {
  return Cliente(
    id: id,
    empresaId: empresaId,
    nombre: nombre,
    rtn: rtn,
    telefono: telefono,
    activo: activo,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    synced: false,
  );
}

PosClienteCreditoData _credito({
  required String id,
  required String empresaId,
  required String clienteId,
  required double saldoActual,
  required double limiteCredito,
  String? clienteNombre,
  int diasVencimiento = 15,
  String estado = 'activo',
}) {
  return PosClienteCreditoData(
    id: id,
    empresaId: empresaId,
    clienteId: clienteId,
    clienteNombre: clienteNombre,
    limiteCredito: limiteCredito,
    saldoActual: saldoActual,
    diasVencimiento: diasVencimiento,
    estado: estado,
    montoUltimoPago: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    synced: false,
  );
}

FiadoAbono _abono({
  required String id,
  required String empresaId,
  required String clienteId,
  required double monto,
  required DateTime fecha,
  String? clienteNombre,
}) {
  return FiadoAbono(
    id: id,
    empresaId: empresaId,
    clienteId: clienteId,
    clienteNombre: clienteNombre,
    monto: monto,
    fecha: fecha,
    createdAt: fecha,
    synced: false,
  );
}

PosArqueoCajaData _arqueo({
  required String id,
  required String empresaId,
  required DateTime fechaApertura,
  required double efectivo,
  required double tarjeta,
  required double transferencia,
  required double mixto,
  required double gastos,
  required double sistema,
  double? diferencia,
  DateTime? fechaCierre,
}) {
  return PosArqueoCajaData(
    id: id,
    empresaId: empresaId,
    usuarioId: 'u1',
    fechaApertura: fechaApertura,
    fechaCierre: fechaCierre,
    fondoInicial: 0,
    totalVentasEfectivo: efectivo,
    totalVentasTarjeta: tarjeta,
    totalVentasTransferencia: transferencia,
    totalVentasMixto: mixto,
    totalGastos: gastos,
    totalEntradas: 0,
    totalSalidas: 0,
    sistemaTotal: sistema,
    diferencia: diferencia,
    estado: fechaCierre == null ? 'abierto' : 'cerrado',
    createdAt: fechaApertura,
    updatedAt: fechaApertura,
    synced: false,
  );
}

Empleado _empleado({
  required String id,
  required String empresaId,
  required String nombre,
  required double salarioBase,
  String estado = 'activo',
  String? puesto,
  String? departamento,
}) {
  return Empleado(
    id: id,
    empresaId: empresaId,
    nombre: nombre,
    puesto: puesto,
    departamento: departamento,
    salarioBase: salarioBase,
    estado: estado,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    synced: false,
  );
}

NominaData _nomina({
  required String id,
  required String empresaId,
  required int mes,
  required int anio,
  required double neta,
  bool pagado = true,
}) {
  return NominaData(
    id: id,
    empresaId: empresaId,
    mes: mes,
    anio: anio,
    salarioBase: neta,
    bonificaciones: 0,
    deducciones: 0,
    isss: 0,
    rtn: 0,
    ihss: 0,
    neta: neta,
    pagado: pagado,
    createdAt: DateTime(anio, mes, 28),
    synced: false,
  );
}

PosVenta _posVenta({
  required String id,
  required String empresaId,
  required double total,
  required DateTime createdAt,
  String estado = 'completada',
}) {
  return PosVenta(
    id: id,
    empresaId: empresaId,
    subtotal: total,
    descuento: 0,
    isv15: 0,
    isv18: 0,
    total: total,
    metodoPago: 'Efectivo',
    estado: estado,
    createdAt: createdAt,
    updatedAt: createdAt,
    synced: false,
  );
}

ReportDataProviderFake _fake() {
  final f = ReportDataProviderFake();
  f.empresas.add(Empresa(
    id: 'e1',
    codigo: 'EMP-1',
    nombre: 'Tienda Doña Ana',
    plan: 'completo',
    activa: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ));
  // Gastos del tenant (septiembre 2026) + un ingreso que NO cuenta.
  f.transaccionesDb.addAll([
    _tx(
      id: 't1',
      empresaId: 'EMP-1',
      tipo: 'gasto',
      monto: 500,
      fecha: DateTime(2026, 9, 10),
      categoria: 'combustible',
      descripcion: 'Gasolina',
      metodoPago: 'Efectivo',
    ),
    _tx(
      id: 't2',
      empresaId: 'EMP-1',
      tipo: 'gasto',
      monto: 1500,
      fecha: DateTime(2026, 9, 15),
      categoria: 'alquiler',
      descripcion: 'Alquiler local',
      metodoPago: 'Transferencia',
    ),
    _tx(
      id: 't3',
      empresaId: 'EMP-1',
      tipo: 'ingreso',
      monto: 9999,
      fecha: DateTime(2026, 9, 5),
    ),
    // Otro tenant: JAMÁS debe aparecer en el reporte de EMP-1.
    _tx(
      id: 't4',
      empresaId: 'OTRO-9',
      tipo: 'gasto',
      monto: 777,
      fecha: DateTime(2026, 9, 10),
    ),
    // Gasto fuera del rango (mes anterior).
    _tx(
      id: 't5',
      empresaId: 'EMP-1',
      tipo: 'gasto',
      monto: 888,
      fecha: DateTime(2026, 8, 20),
    ),
  ]);
  // Ventas: una factura válida + una anulada.
  f.facturasDb.addAll([
    _factura(
      id: 'f1',
      empresaId: 'EMP-1',
      correlativo: '001-00000042',
      total: 2875,
      isv15: 375,
      createdAt: DateTime(2026, 9, 18),
    ),
    _factura(
      id: 'f2',
      empresaId: 'EMP-1',
      correlativo: '001-00000043',
      total: 900,
      isv15: 0,
      createdAt: DateTime(2026, 9, 19),
      estado: 'anulada',
    ),
  ]);
  // Stock: un activo bajo mínimo y uno inactivo.
  f.productosDb.addAll([
    _prod(
      id: 'p1',
      empresaId: 'EMP-1',
      nombre: 'Aceite 1L',
      stockActual: 2,
      stockMinimo: 5,
      precioVenta: 180,
      categoria: 'Despensa',
    ),
    _prod(
      id: 'p2',
      empresaId: 'EMP-1',
      nombre: 'Arroz 5kg',
      stockActual: 40,
      stockMinimo: 10,
      precioVenta: 210,
      activo: false,
    ),
  ]);
  // Compras: dos válidas en el mes + una anulada + otro tenant + mes anterior.
  f.comprasDb.addAll([
    _compra(
      id: 'c1',
      empresaId: 'EMP-1',
      proveedorNombre: 'Distribuidora Central',
      total: 5000,
      isv15: 652.17,
      fecha: DateTime(2026, 9, 10),
      correlativo: 'CMP-001',
      numeroFactura: 'FAC-100',
    ),
    _compra(
      id: 'c2',
      empresaId: 'EMP-1',
      proveedorNombre: 'Distribuidora Central',
      total: 1500,
      isv15: 0,
      isv18: 228.81,
      fecha: DateTime(2026, 9, 22),
      correlativo: 'CMP-002',
      numeroFactura: 'FAC-101',
    ),
    _compra(
      id: 'c3',
      empresaId: 'EMP-1',
      proveedorNombre: 'Otro Proveedor',
      total: 8888,
      isv15: 0,
      fecha: DateTime(2026, 9, 25),
      estado: 'anulada',
    ),
    _compra(
      id: 'c4',
      empresaId: 'OTRO-9',
      proveedorNombre: 'Tenant Ajeno',
      total: 999,
      isv15: 0,
      fecha: DateTime(2026, 9, 10),
    ),
    _compra(
      id: 'c5',
      empresaId: 'EMP-1',
      proveedorNombre: 'Del Mes Pasado',
      total: 777,
      isv15: 0,
      fecha: DateTime(2026, 8, 20),
    ),
  ]);
  // Clientes: activos e inactivos del tenant + uno ajeno.
  f.clientesDb.addAll([
    _cliente(
      id: 'cl1',
      empresaId: 'EMP-1',
      nombre: 'Ana López',
      rtn: '0801-1990-00001',
      telefono: '9999-0001',
    ),
    _cliente(
      id: 'cl2',
      empresaId: 'EMP-1',
      nombre: 'Zeta Inactivo',
      activo: false,
    ),
    _cliente(id: 'cl3', empresaId: 'OTRO-9', nombre: 'Ajeno SA'),
  ]);
  // Crédito POS (fiado): dos cuentas con saldo del tenant + una a otro tenant.
  f.posClienteCreditoDb.addAll([
    _credito(
      id: 'cr1',
      empresaId: 'EMP-1',
      clienteId: 'cl1',
      clienteNombre: 'Ana López',
      saldoActual: 1500,
      limiteCredito: 5000,
    ),
    _credito(
      id: 'cr2',
      empresaId: 'EMP-1',
      clienteId: 'cl2',
      clienteNombre: 'Zeta Inactivo',
      saldoActual: 0,
      limiteCredito: 1000,
    ),
    _credito(
      id: 'cr3',
      empresaId: 'OTRO-9',
      clienteId: 'cl3',
      saldoActual: 99999,
      limiteCredito: 999999,
    ),
  ]);
  // Abonos del fiado: dos en el mes + uno del mes anterior + uno ajeno.
  f.fiadoAbonosDb.addAll([
    _abono(
      id: 'a1',
      empresaId: 'EMP-1',
      clienteId: 'cl1',
      clienteNombre: 'Ana López',
      monto: 300,
      fecha: DateTime(2026, 9, 5),
    ),
    _abono(
      id: 'a2',
      empresaId: 'EMP-1',
      clienteId: 'cl1',
      clienteNombre: 'Ana López',
      monto: 200,
      fecha: DateTime(2026, 9, 20),
    ),
    _abono(
      id: 'a3',
      empresaId: 'EMP-1',
      clienteId: 'cl1',
      clienteNombre: 'Ana López',
      monto: 111,
      fecha: DateTime(2026, 8, 30),
    ),
    _abono(
      id: 'a4',
      empresaId: 'OTRO-9',
      clienteId: 'cl3',
      monto: 55,
      fecha: DateTime(2026, 9, 6),
    ),
  ]);
  // Arqueos: uno cerrado en el mes + uno abierto + uno de mes anterior + ajeno.
  f.arqueosDb.addAll([
    _arqueo(
      id: 'ar1',
      empresaId: 'EMP-1',
      fechaApertura: DateTime(2026, 9, 1),
      fechaCierre: DateTime(2026, 9, 1),
      efectivo: 4000,
      tarjeta: 1500,
      transferencia: 600,
      mixto: 200,
      gastos: 300,
      sistema: 6300,
      diferencia: 0,
    ),
    _arqueo(
      id: 'ar2',
      empresaId: 'EMP-1',
      fechaApertura: DateTime(2026, 9, 3),
      efectivo: 100,
      tarjeta: 100,
      transferencia: 100,
      mixto: 100,
      gastos: 0,
      sistema: 400,
    ),
    _arqueo(
      id: 'ar3',
      empresaId: 'EMP-1',
      fechaApertura: DateTime(2026, 8, 10),
      fechaCierre: DateTime(2026, 8, 10),
      efectivo: 5000,
      tarjeta: 0,
      transferencia: 0,
      mixto: 0,
      gastos: 0,
      sistema: 5000,
      diferencia: 5,
    ),
    _arqueo(
      id: 'ar4',
      empresaId: 'OTRO-9',
      fechaApertura: DateTime(2026, 9, 2),
      fechaCierre: DateTime(2026, 9, 2),
      efectivo: 777,
      tarjeta: 0,
      transferencia: 0,
      mixto: 0,
      gastos: 0,
      sistema: 777,
      diferencia: 0,
    ),
  ]);
  // Empleados: dos activos + uno inactivo + uno ajeno.
  f.empleadosDb.addAll([
    _empleado(
      id: 'e1',
      empresaId: 'EMP-1',
      nombre: 'Carlos Pérez',
      salarioBase: 12000,
      puesto: 'Cajero',
      departamento: 'Caja',
    ),
    _empleado(
      id: 'e2',
      empresaId: 'EMP-1',
      nombre: 'María Gómez',
      salarioBase: 15000,
      puesto: 'Supervisora',
      departamento: 'Administración',
    ),
    _empleado(
      id: 'e3',
      empresaId: 'EMP-1',
      nombre: 'Inactivo Despedido',
      salarioBase: 8000,
      estado: 'inactivo',
    ),
    _empleado(
      id: 'e4',
      empresaId: 'OTRO-9',
      nombre: 'Ajeno',
      salarioBase: 1,
    ),
  ]);
  // Nómina: una pagada del mes + una de otro mes + una sin pagar.
  f.nominaDb.addAll([
    _nomina(
      id: 'n1',
      empresaId: 'EMP-1',
      mes: 9,
      anio: 2026,
      neta: 21000,
    ),
    _nomina(
      id: 'n2',
      empresaId: 'EMP-1',
      mes: 8,
      anio: 2026,
      neta: 19000,
    ),
    _nomina(
      id: 'n3',
      empresaId: 'EMP-1',
      mes: 9,
      anio: 2026,
      neta: 1,
      pagado: false,
    ),
  ]);
  // Ventas POS: una completada en el mes + una cancelada (para resumen financiero).
  f.posVentasDb.addAll([
    _posVenta(
      id: 'v1',
      empresaId: 'EMP-1',
      total: 1000,
      createdAt: DateTime(2026, 9, 8),
    ),
    _posVenta(
      id: 'v2',
      empresaId: 'EMP-1',
      total: 222,
      createdAt: DateTime(2026, 9, 9),
      estado: 'cancelada',
    ),
    _posVenta(
      id: 'v3',
      empresaId: 'OTRO-9',
      total: 333,
      createdAt: DateTime(2026, 9, 9),
    ),
  ]);
  return f;
}

Future<String> _correlativo() async => 'REP-000001';

ReportToolDispatcher _dispatcher(ReportDataProviderFake p, String rol) =>
    ReportToolDispatcher(
      provider: p,
      authSource: AuthContextSource(
        empresaId: 'EMP-1',
        rol: rol,
        empresaNombre: 'Tienda Doña Ana',
      ),
      correlativoProvider: _correlativo,
    );

void main() {
  group('ReportToolDispatcher — gastos', () {
    test('filtra por tenant, rango del mes y excluye ingresos', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.gastos,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      expect(r.noData, isFalse);
      expect(r.registros, 2); // t1 + t2 (no t3 ingreso, no t4 otro tenant, no t5 agosto)
      expect(r.data.report.number, 'REP-000001');
      expect(r.data.company.name, 'Tienda Doña Ana');
      expect(r.data.table.totalValue, ReportBuilder.money(500 + 1500));
      expect(r.data.table.rows.length, 2);
      // Más reciente primero.
      expect(r.data.table.rows.first['fecha'], '15/09/2026');
      expect(r.mensaje.contains('Reporte de gastos'), isTrue);
    });

    test('rango vacío produce noData con el mensaje correcto', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.gastos,
        const ReportToolParams(desde: null, hasta: null, mes: 1, anio: 2020),
      );
      expect(r.noData, isTrue);
      expect(r.registros, 0);
      expect(r.data.noData, isTrue);
      expect(r.mensaje.contains('No se encontraron datos'), isTrue);
    });
  });

  group('ReportToolDispatcher — ventas', () {
    test('excluye facturas/POS anuladas y agrega solo el tenant', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.ventas,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // f1 (facturación) + v1 (POS); f2 anulada y v2 cancelada se excluyen.
      expect(r.registros, 2);
      expect(r.data.table.totalValue, ReportBuilder.money(2875 + 1000));
      expect(r.data.table.rows.where((row) => row['canal'] == 'Facturación').length, 1);
      expect(r.data.table.rows.where((row) => row['canal'] == 'POS').length, 1);
      // Más reciente primero: v1 (8 sep) es anterior a f1 (18 sep).
      expect(r.data.table.rows.first['canal'], 'Facturación');
    });
  });

  group('ReportToolDispatcher — stock', () {
    test('solo cuenta productos activos y detecta bajo mínimo', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(ReportToolType.stock);
      expect(r.registros, 1);
      final kpiBajo =
          r.data.kpis.firstWhere((k) => k.label == 'Productos bajo mínimo');
      expect(kpiBajo.value, '1'); // Aceite bajo mínimo; Arroz inactivo.
      expect(r.data.table.rows.single['stock'], '2');
    });

    test('catálogo vacío del tenant produce noData', () async {
      final p = ReportDataProviderFake(); // Sin productos.
      final d = ReportToolDispatcher(
        provider: p,
        authSource: const AuthContextSource(
            empresaId: 'EMP-1', rol: 'admin', empresaNombre: 'Vacía'),
        correlativoProvider: _correlativo,
      );
      final r = await d.execute(ReportToolType.stock);
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — compras', () {
    test('filtra por tenant, rango, excluye anuladas y agrega ISV', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.compras,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // c1 + c2 en el mes; c3 anulada, c4 otro tenant y c5 agosto se ignoran.
      expect(r.registros, 2);
      expect(r.data.table.totalValue, ReportBuilder.money(5000 + 1500));
      final kpiIsv =
          r.data.kpis.firstWhere((k) => k.label == 'ISV en compras');
      expect(kpiIsv.value, ReportBuilder.money(652.17 + 228.81));
      final kpiProv =
          r.data.kpis.firstWhere((k) => k.label == 'Proveedor principal');
      expect(kpiProv.value, 'Distribuidora Central');
      // Más reciente primero.
      expect(r.data.table.rows.first['fecha'], '22/09/2026');
    });

    test('sin compras en el periodo produce noData', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.compras,
        const ReportToolParams(mes: 1, anio: 2020),
      );
      expect(r.noData, isTrue);
      expect(r.registros, 0);
    });
  });

  group('ReportToolDispatcher — clientes', () {
    test('devuelve directorio del tenant con saldo fiado del POS', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(ReportToolType.clientes);
      // cl1 + cl2 del tenant; cl3 ajeno se excluye.
      expect(r.registros, 2);
      expect(r.data.kpis.firstWhere((k) => k.label == 'Activos').value, '1');
      expect(r.data.kpis.firstWhere((k) => k.label == 'Con saldo fiado').value,
          '1');
      expect(r.data.table.totalValue, '2');
      // Ordenado A→Z: Ana primero.
      expect(r.data.table.rows.first['nombre'], 'Ana López');
      expect(r.data.table.rows.first['fiado'], ReportBuilder.money(1500));
      expect(r.data.table.rows.last['rtn'], '—'); // Zeta sin RTN.
    });

    test('directorio vacío produce noData', () async {
      final p = ReportDataProviderFake();
      final d = ReportToolDispatcher(
        provider: p,
        authSource: const AuthContextSource(
            empresaId: 'EMP-1', rol: 'admin', empresaNombre: 'Vacía'),
        correlativoProvider: _correlativo,
      );
      final r = await d.execute(ReportToolType.clientes);
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — facturación', () {
    test('excluye facturas anuladas y detecta condición principal', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.facturacion,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // f1 emitida en el mes; f2 anulada se excluye.
      expect(r.registros, 1);
      expect(r.data.table.totalValue, ReportBuilder.money(2875));
      final kpiIva =
          r.data.kpis.firstWhere((k) => k.label == 'ISV facturado');
      expect(kpiIva.value, ReportBuilder.money(375));
      final kpiCond =
          r.data.kpis.firstWhere((k) => k.label == 'Condición principal');
      expect(kpiCond.value, 'Contado');
      expect(r.data.table.rows.single['correlativo'], '001-00000042');
      expect(r.data.table.rows.single['total'], ReportBuilder.money(2875));
    });

    test('sin facturas en el periodo produce noData', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.facturacion,
        const ReportToolParams(mes: 1, anio: 2020),
      );
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — cuentas por cobrar', () {
    test('agrupa saldos del crédito POS y abonos del periodo', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.cuentasPorCobrar,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // Solo cr1 tiene saldo>0; cr2 saldo 0 y cr3 otro tenant se excluyen.
      expect(r.registros, 1);
      expect(r.data.table.totalValue, ReportBuilder.money(1500));
      expect(r.data.kpis.firstWhere((k) => k.label == 'Límite total').value,
          ReportBuilder.money(6000)); // cr1 5000 + cr2 1000
      final kpiAbonos =
          r.data.kpis.firstWhere((k) => k.label == 'Abonos del periodo');
      // a1 + a2 en el mes; a3 agosto y a4 ajeno se excluyen.
      expect(kpiAbonos.value, ReportBuilder.money(500));
      final kpiTop =
          r.data.kpis.firstWhere((k) => k.label == 'Cliente que más abonó');
      expect(kpiTop.value, 'Ana López');
      expect(r.data.table.rows.single['cliente'], 'Ana López');
    });

    test('sin cuentas con saldo produce noData', () async {
      final p = ReportDataProviderFake();
      final d = ReportToolDispatcher(
        provider: p,
        authSource: const AuthContextSource(
            empresaId: 'EMP-1', rol: 'admin', empresaNombre: 'Vacía'),
        correlativoProvider: _correlativo,
      );
      final r = await d.execute(
        ReportToolType.cuentasPorCobrar,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — caja', () {
    test('solo arqueos cerrados del tenant en el rango', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.caja,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // ar1 cerrado en el mes; ar2 abierto, ar3 mes anterior y ar4 ajeno.
      expect(r.registros, 1);
      final kpiVentas =
          r.data.kpis.firstWhere((k) => k.label == 'Ventas en caja');
      // 4000 + 1500 + 600 + 200.
      expect(kpiVentas.value, ReportBuilder.money(6300));
      final kpiGastos =
          r.data.kpis.firstWhere((k) => k.label == 'Gastos de caja');
      expect(kpiGastos.value, ReportBuilder.money(300));
      expect(r.data.table.rows.single['sistema'],
          ReportBuilder.money(6300));
    });

    test('sin arqueos cerrados produce noData', () async {
      final p = ReportDataProviderFake();
      final d = ReportToolDispatcher(
        provider: p,
        authSource: const AuthContextSource(
            empresaId: 'EMP-1', rol: 'admin', empresaNombre: 'Vacía'),
        correlativoProvider: _correlativo,
      );
      final r = await d.execute(
        ReportToolType.caja,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — resumen financiero', () {
    test('combina facturas + POS + otros ingresos y calcula utilidad', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.resumenFinanciero,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // Ventas facturadas = f1 (2875). Ventas POS = v1 (1000), v2 cancelada se
      // excluye. Otros ingresos = t3 (9999). Gastos = t1 + t2 (2000).
      expect(r.registros, 4);
      final kpiIngresos =
          r.data.kpis.firstWhere((k) => k.label == 'Ingresos');
      expect(kpiIngresos.value, ReportBuilder.money(2875 + 1000 + 9999));
      final kpiGastos = r.data.kpis.firstWhere((k) => k.label == 'Gastos');
      expect(kpiGastos.value, ReportBuilder.money(500 + 1500));
      final kpiUtilidad =
          r.data.kpis.firstWhere((k) => k.label == 'Utilidad neta');
      expect(kpiUtilidad.value,
          ReportBuilder.money(2875 + 1000 + 9999 - 2000));
      // Fila de utilidad al final.
      expect(r.data.table.rows.last['concepto'], 'Utilidad neta');
    });

    test('periodo sin movimientos produce noData', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.resumenFinanciero,
        const ReportToolParams(mes: 1, anio: 2020),
      );
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — empleados', () {
    test('cuenta activos, costo salarial y planilla pagada del mes', () async {
      final d = _dispatcher(_fake(), 'admin');
      final r = await d.execute(
        ReportToolType.empleados,
        const ReportToolParams(mes: 9, anio: 2026),
      );
      // e1 + e2 activos del tenant; e3 inactivo, e4 ajeno.
      expect(r.registros, 2);
      expect(r.data.kpis.firstWhere((k) => k.label == 'Empleados').value, '3');
      expect(r.data.kpis.firstWhere((k) => k.label == 'Activos').value, '2');
      final kpiCosto =
          r.data.kpis.firstWhere((k) => k.label == 'Costo salarial');
      expect(kpiCosto.value, ReportBuilder.money(12000 + 15000 + 8000));
      final kpiPlanilla =
          r.data.kpis.firstWhere((k) => k.label == 'Planilla pagada');
      // n1 pagada del mes; n2 otro mes y n3 sin pagar se excluyen.
      expect(kpiPlanilla.value, ReportBuilder.money(21000));
      // Ordenado A→Z.
      expect(r.data.table.rows.first['nombre'], 'Carlos Pérez');
    });

    test('nómina sin empleados produce noData', () async {
      final p = ReportDataProviderFake();
      final d = ReportToolDispatcher(
        provider: p,
        authSource: const AuthContextSource(
            empresaId: 'EMP-1', rol: 'admin', empresaNombre: 'Vacía'),
        correlativoProvider: _correlativo,
      );
      final r = await d.execute(ReportToolType.empleados);
      expect(r.noData, isTrue);
    });
  });

  group('ReportToolDispatcher — seguridad', () {
    test('rol sin permisos lanza ReportPermissionException', () async {
      final d = _dispatcher(_fake(), 'vendedor');
      expect(
        () => d.execute(ReportToolType.gastos),
        throwsA(isA<ReportPermissionException>()),
      );
    });

    test('sin empresa activa lanza ReportToolException', () async {
      final d = ReportToolDispatcher(
        provider: ReportDataProviderFake(),
        authSource: const AuthContextSource(empresaId: '', rol: 'admin'),
        correlativoProvider: _correlativo,
      );
      expect(
        () => d.execute(ReportToolType.gastos),
        throwsA(isA<ReportToolException>()),
      );
    });
  });
}