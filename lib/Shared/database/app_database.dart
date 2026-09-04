import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Empresas extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get codigo => text().nullable()();
  TextColumn get nombre => text()();
  TextColumn get rtn => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get plan => text().withDefault(const Constant('free'))();
  TextColumn get areaNegocio => text().nullable()();
  BlobColumn get config => blob().nullable()();
  BoolColumn get activa => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Usuarios extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text().nullable()();
  TextColumn get nombre => text()();
  TextColumn get apellido => text().nullable()();
  TextColumn get email => text()();
  TextColumn get rolGlobal => text().withDefault(const Constant('user'))();
  TextColumn get avatarUrl => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class EmpresaModulos extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get moduloId => text()();
  BoolColumn get habilitado => boolean().withDefault(const Constant(true))();
  DateTimeColumn get fechaHabilitado => dateTime().withDefault(currentDateAndTime)();
  BlobColumn get config => blob().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {empresaId, moduloId},
      ];
}

class UsuarioModulos extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get usuarioId => text()();
  TextColumn get empresaId => text()();
  TextColumn get moduloId => text()();
  TextColumn get rol => text().withDefault(const Constant('user'))();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {usuarioId, empresaId, moduloId},
      ];
}

class Facturas extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get usuarioId => text().nullable()();
  TextColumn get correlativo => text()();
  TextColumn get tipoDocumento => text().withDefault(const Constant('Factura'))();
  TextColumn get cai => text()();
  TextColumn get rangoInicio => text().nullable()();
  TextColumn get rangoFin => text().nullable()();
  DateTimeColumn get fechaLimiteEmision => dateTime().nullable()();
  TextColumn get clienteNombre => text().nullable()();
  TextColumn get clienteRtn => text().nullable()();
  TextColumn get clienteDireccion => text().nullable()();
  TextColumn get condicionPago => text().withDefault(const Constant('Contado'))();
  TextColumn get tipoVenta => text().withDefault(const Constant('Gravada'))();
  BlobColumn get items => blob()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get isv15 => real().withDefault(const Constant(0.0))();
  RealColumn get isv18 => real().withDefault(const Constant(0.0))();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get estado => text().withDefault(const Constant('emitida'))();
  DateTimeColumn get fechaAnulacion => dateTime().nullable()();
  TextColumn get motivoAnulacion => text().nullable()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Clientes extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get rtn => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Productos extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get codigo => text().nullable()();
  TextColumn get nombre => text()();
  TextColumn get descripcion => text().nullable()();
  TextColumn get categoria => text().nullable()();
  TextColumn get unidadMedida => text().withDefault(const Constant('Unidad'))();
  RealColumn get precioCompra => real().withDefault(const Constant(0.0))();
  RealColumn get precioVenta => real().withDefault(const Constant(0.0))();
  IntColumn get stockMinimo => integer().withDefault(const Constant(0))();
  IntColumn get stockActual => integer().withDefault(const Constant(0))();
  TextColumn get bodega => text().withDefault(const Constant('General'))();
  RealColumn get isvRate => real().withDefault(const Constant(15.0))();
  BoolColumn get exento => boolean().withDefault(const Constant(false))();
  TextColumn get imagenUrl => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transacciones extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get usuarioId => text().nullable()();
  TextColumn get tipo => text()();
  TextColumn get categoria => text().nullable()();
  TextColumn get descripcion => text().nullable()();
  RealColumn get monto => real()();
  TextColumn get metodoPago => text().nullable()();
  TextColumn get referencia => text().nullable()();
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}


class Empleados extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get identidad => text().nullable()();
  TextColumn get rtn => text().nullable()();
  TextColumn get puesto => text().nullable()();
  TextColumn get departamento => text().nullable()();
  RealColumn get salarioBase => real().withDefault(const Constant(0.0))();
  DateTimeColumn get fechaIngreso => dateTime().nullable()();
  TextColumn get estado => text().withDefault(const Constant('activo'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Nomina extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get empleadoId => text().nullable()();
  IntColumn get mes => integer()();
  IntColumn get anio => integer()();
  RealColumn get salarioBase => real().withDefault(const Constant(0.0))();
  RealColumn get bonificaciones => real().withDefault(const Constant(0.0))();
  RealColumn get deducciones => real().withDefault(const Constant(0.0))();
  RealColumn get isss => real().withDefault(const Constant(0.0))();
  RealColumn get rtn => real().withDefault(const Constant(0.0))();
  RealColumn get ihss => real().withDefault(const Constant(0.0))();
  RealColumn get neta => real().withDefault(const Constant(0.0))();
  BoolColumn get pagado => boolean().withDefault(const Constant(false))();
  DateTimeColumn get fechaPago => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {empresaId, empleadoId, mes, anio},
      ];
}

class SyncQueue extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get tabla => text()();
  TextColumn get operacion => text()();
  BlobColumn get datos => blob()();
  TextColumn get empresaId => text().nullable()();
  IntColumn get intentos => integer().withDefault(const Constant(0))();
  IntColumn get maxIntentos => integer().withDefault(const Constant(5))();
  TextColumn get ultimoError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get proximoIntento => dateTime().nullable()();
  BoolColumn get procesando => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Drafts extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get pantalla => text()();
  TextColumn get clave => text()();
  BlobColumn get datos => blob()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {pantalla, clave},
      ];
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SAR HONDURAS TABLES (Paso 3)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// ConfiguraciÃ³n fiscal de la empresa para facturaciÃ³n SAR Honduras.
/// Una fila por empresa (id == empresaId).
class SarConfiguracion extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get rtn => text().nullable()();
  TextColumn get razonSocial => text().nullable()();
  TextColumn get nombreComercial => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get representanteLegal => text().nullable()();
  TextColumn get actividadEconomica => text().nullable()();
  TextColumn get establecimiento => text().withDefault(const Constant('001'))();
  TextColumn get puntoEmision => text().withDefault(const Constant('001'))();
  TextColumn get regimen => text().withDefault(const Constant('general'))();
  BoolColumn get contingenciaActiva => boolean().withDefault(const Constant(false))();
  TextColumn get motivoContingencia => text().nullable()();
  DateTimeColumn get fechaInicioContingencia => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Control de correlativos y CAI por tipo de documento fiscal.
/// Una fila por (empresa, tipoDocumento).
class SarCorrelativo extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get tipoDocumento => text().withDefault(const Constant('01'))();
  TextColumn get cai => text().nullable()();
  TextColumn get numeroResolucion => text().nullable()();
  TextColumn get rangoInicio => text().nullable()();
  TextColumn get rangoFin => text().nullable()();
  DateTimeColumn get fechaLimiteEmision => dateTime().nullable()();
  IntColumn get siguienteNumero => integer().withDefault(const Constant(1))();
  BoolColumn get agotado => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {empresaId, tipoDocumento},
      ];
}

/// BitÃ¡cora de documentos emitidos en rÃ©gimen de contingencia.
class SarContingencia extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get tipoDocumento => text().withDefault(const Constant('01'))();
  TextColumn get correlativo => text()();
  TextColumn get motivo => text().nullable()();
  TextColumn get referencia => text().nullable()();
  DateTimeColumn get fechaEmision => dateTime()();
  RealColumn get monto => real().withDefault(const Constant(0.0))();
  TextColumn get estado => text().withDefault(const Constant('emitido'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// POS TABLES
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class PosVentas extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get usuarioId => text().nullable()();
  TextColumn get terminalId => text().nullable()();
  TextColumn get correlativo => text().nullable()();
  TextColumn get clienteId => text().nullable()();
  TextColumn get clienteNombre => text().nullable()();
  TextColumn get clienteRtn => text().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get isv15 => real().withDefault(const Constant(0.0))();
  RealColumn get isv18 => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get metodoPago => text().withDefault(const Constant('efectivo'))();
  TextColumn get estado => text().withDefault(const Constant('completada'))();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PosVentaItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get ventaId => text()();
  TextColumn get productoId => text().nullable()();
  TextColumn get productoCodigo => text().nullable()();
  TextColumn get productoNombre => text()();
  RealColumn get precioUnitario => real()();
  IntColumn get cantidad => integer()();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get isvRate => real().withDefault(const Constant(15.0))();
  RealColumn get subtotal => real()();
  TextColumn get promocionAplicada => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PosArqueoCaja extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get usuarioId => text()();
  TextColumn get terminalId => text().nullable()();
  DateTimeColumn get fechaApertura => dateTime()();
  DateTimeColumn get fechaCierre => dateTime().nullable()();
  RealColumn get fondoInicial => real().withDefault(const Constant(0.0))();
  RealColumn get totalVentasEfectivo => real().withDefault(const Constant(0.0))();
  RealColumn get totalVentasTarjeta => real().withDefault(const Constant(0.0))();
  RealColumn get totalVentasTransferencia => real().withDefault(const Constant(0.0))();
  RealColumn get totalVentasMixto => real().withDefault(const Constant(0.0))();
  RealColumn get totalGastos => real().withDefault(const Constant(0.0))();
  RealColumn get totalEntradas => real().withDefault(const Constant(0.0))();
  RealColumn get totalSalidas => real().withDefault(const Constant(0.0))();
  RealColumn get sistemaTotal => real().withDefault(const Constant(0.0))();
  RealColumn get conteoFisico => real().nullable()();
  RealColumn get diferencia => real().nullable()();
  TextColumn get observaciones => text().nullable()();
  TextColumn get estado => text().withDefault(const Constant('abierto'))();
  BlobColumn get detalleDenominaciones => blob().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PosPromociones extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get tipo => text()();
  TextColumn get descripcion => text().nullable()();
  BlobColumn get configuracion => blob()();
  DateTimeColumn get fechaInicio => dateTime().nullable()();
  DateTimeColumn get fechaFin => dateTime().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  BoolColumn get aplicaTodosProductos => boolean().withDefault(const Constant(false))();
  BlobColumn get productosIds => blob().nullable()();
  BlobColumn get categoriasIds => blob().nullable()();
  IntColumn get prioridad => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PosClienteCredito extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get clienteId => text()();
  TextColumn get clienteNombre => text().nullable()();
  RealColumn get limiteCredito => real().withDefault(const Constant(0.0))();
  RealColumn get saldoActual => real().withDefault(const Constant(0.0))();
  IntColumn get diasVencimiento => integer().withDefault(const Constant(30))();
  TextColumn get estado => text().withDefault(const Constant('activo'))();
  DateTimeColumn get fechaUltimoPago => dateTime().nullable()();
  RealColumn get montoUltimoPago => real().withDefault(const Constant(0.0))();
  DateTimeColumn get fechaUltimaVenta => dateTime().nullable()();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {empresaId, clienteId},
      ];
}

class PosConfig extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get terminalId => text()();
  TextColumn get impresoraTipo => text().nullable()();
  TextColumn get impresoraDireccion => text().nullable()();
  TextColumn get impresoraAncho => text().withDefault(const Constant('80'))();
  BoolColumn get cajonAutomatico => boolean().withDefault(const Constant(true))();
  BoolColumn get sonidoVenta => boolean().withDefault(const Constant(true))();
  BoolColumn get pantallaCompleta => boolean().withDefault(const Constant(true))();
  TextColumn get moneda => text().withDefault(const Constant('L'))();
  IntColumn get decimales => integer().withDefault(const Constant(2))();
  BlobColumn get datosExtra => blob().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {empresaId, terminalId},
      ];
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CANAL TRADICIONAL TABLES (Paso 5)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// Ruta de reparto/visita del canal tradicional.
class Rutas extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get vendedor => text().nullable()();
  TextColumn get frecuencia => text().withDefault(const Constant('semanal'))();
  IntColumn get diaSemana => integer().nullable()();
  TextColumn get descripcion => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Clientes asignados a una ruta.
class RutaClientes extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get rutaId => text()();
  TextColumn get empresaId => text()();
  TextColumn get clienteId => text()();
  TextColumn get clienteNombre => text().nullable()();
  IntColumn get orden => integer().withDefault(const Constant(0))();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {rutaId, clienteId},
      ];
}

/// Historial de abonos realizados contra las cuentas por cobrar (fiado).
class FiadoAbonos extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get clienteId => text()();
  TextColumn get clienteNombre => text().nullable()();
  TextColumn get ventaId => text().nullable()();
  TextColumn get facturaId => text().nullable()();
  RealColumn get monto => real()();
  TextColumn get metodoPago => text().nullable()();
  TextColumn get referencia => text().nullable()();
  TextColumn get notas => text().nullable()();
  TextColumn get usuarioId => text().nullable()();
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CANAL MODERNO TABLES (Paso 6)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// Sucursal del canal moderno. Su `codigo` se usa como bodega de los
/// productos (`productos.bodega`) para separar inventario por sucursal.
class Sucursales extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get codigo => text().nullable()();
  TextColumn get nombre => text()();
  TextColumn get direccion => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get encargado => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  BoolColumn get esPrincipal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Traslado de inventario entre sucursales.
/// estados: pendiente -> en_transito -> recibida | cancelada
class Transferencias extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get correlativo => text().nullable()();
  TextColumn get origenId => text()();
  TextColumn get origenNombre => text()();
  TextColumn get destinoId => text()();
  TextColumn get destinoNombre => text()();
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  TextColumn get observaciones => text().nullable()();
  TextColumn get usuarioId => text().nullable()();
  DateTimeColumn get fechaEnvio => dateTime().nullable()();
  DateTimeColumn get fechaRecepcion => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items de una transferencia de inventario.
class TransferenciaItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get transferenciaId => text()();
  TextColumn get empresaId => text()();
  TextColumn get productoId => text()();
  TextColumn get productoCodigo => text().nullable()();
  TextColumn get productoNombre => text()();
  IntColumn get cantidad => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MEMBRESÃAS TABLES (Paso 7)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// Plan de membresÃ­a: define precio, descuento preferencial y vigencia.
class Membresias extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get descripcion => text().nullable()();
  RealColumn get precio => real().withDefault(const Constant(0.0))();
  RealColumn get descuentoPorcentaje => real().withDefault(const Constant(0.0))();
  IntColumn get vigenciaMeses => integer().withDefault(const Constant(1))();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Socio / miembro del programa de membresÃ­as.
class Socios extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get documento => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// AfiliaciÃ³n de un socio a un plan de membresÃ­a (vigencia).
/// estados: activa -> vencida | cancelada
class SocioMembresias extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get socioId => text()();
  TextColumn get socioNombre => text()();
  TextColumn get membresiaId => text()();
  TextColumn get membresiaNombre => text()();
  RealColumn get descuentoPorcentaje => real().withDefault(const Constant(0.0))();
  RealColumn get precioPagado => real().withDefault(const Constant(0.0))();
  DateTimeColumn get fechaInicio => dateTime()();
  DateTimeColumn get fechaFin => dateTime()();
  TextColumn get estado => text().withDefault(const Constant('activa'))();
  TextColumn get notas => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Precio preferencial por producto asignado a un socio.
class SocioPrecios extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get socioId => text()();
  TextColumn get productoId => text()();
  TextColumn get productoCodigo => text().nullable()();
  TextColumn get productoNombre => text()();
  RealColumn get precioPreferencial => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {empresaId, socioId, productoId},
      ];
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// COMERCIAL GENÃ‰RICO TABLES (Paso 8)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// Proveedor / suministrador.
class Proveedores extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get nombre => text()();
  TextColumn get contacto => text().nullable()();
  TextColumn get telefono => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get direccion => text().nullable()();
  TextColumn get rtn => text().nullable()();
  IntColumn get condicionesPago => integer().withDefault(const Constant(30))();
  TextColumn get notas => text().nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// CotizaciÃ³n a proveedor.
/// estados: borrador -> enviada -> aceptada | rechazada | vencida
class Cotizaciones extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get correlativo => text().nullable()();
  TextColumn get proveedorId => text()();
  TextColumn get proveedorNombre => text()();
  DateTimeColumn get fecha => dateTime()();
  IntColumn get validezDias => integer().withDefault(const Constant(30))();
  TextColumn get estado => text().withDefault(const Constant('borrador'))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get isv15 => real().withDefault(const Constant(0.0))();
  RealColumn get isv18 => real().withDefault(const Constant(0.0))();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get notas => text().nullable()();
  TextColumn get usuarioId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items de una cotizaciÃ³n.
class CotizacionItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get cotizacionId => text()();
  TextColumn get empresaId => text()();
  TextColumn get productoId => text().nullable()();
  TextColumn get productoCodigo => text().nullable()();
  TextColumn get productoNombre => text()();
  TextColumn get descripcion => text().nullable()();
  IntColumn get cantidad => integer()();
  RealColumn get precioUnitario => real()();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get isvRate => real().withDefault(const Constant(15.0))();
  RealColumn get subtotal => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Orden de compra a proveedor.
/// estados: borrador -> enviada -> recibida | parcial | cancelada
class OrdenesCompra extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get correlativo => text().nullable()();
  TextColumn get proveedorId => text()();
  TextColumn get proveedorNombre => text()();
  TextColumn get cotizacionId => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  DateTimeColumn get fechaEntrega => dateTime().nullable()();
  TextColumn get estado => text().withDefault(const Constant('borrador'))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get isv15 => real().withDefault(const Constant(0.0))();
  RealColumn get isv18 => real().withDefault(const Constant(0.0))();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get notas => text().nullable()();
  TextColumn get usuarioId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items de una orden de compra.
class OrdenCompraItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get ordenCompraId => text()();
  TextColumn get empresaId => text()();
  TextColumn get productoId => text().nullable()();
  TextColumn get productoCodigo => text().nullable()();
  TextColumn get productoNombre => text()();
  TextColumn get descripcion => text().nullable()();
  IntColumn get cantidad => integer()();
  RealColumn get precioUnitario => real()();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get isvRate => real().withDefault(const Constant(15.0))();
  RealColumn get subtotal => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Compra / factura de proveedor (recepciÃ³n de mercancÃ­a).
/// estados: pendiente -> pagada | parcial | anulada
class Compras extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get empresaId => text()();
  TextColumn get correlativo => text().nullable()();
  TextColumn get proveedorId => text()();
  TextColumn get proveedorNombre => text()();
  TextColumn get ordenCompraId => text().nullable()();
  TextColumn get numeroFactura => text().nullable()();
  DateTimeColumn get fecha => dateTime()();
  DateTimeColumn get fechaVencimiento => dateTime().nullable()();
  TextColumn get estado => text().withDefault(const Constant('pendiente'))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get isv15 => real().withDefault(const Constant(0.0))();
  RealColumn get isv18 => real().withDefault(const Constant(0.0))();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get notas => text().nullable()();
  TextColumn get usuarioId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items de una compra (recepciÃ³n).
class CompraItems extends Table {
  TextColumn get id => text().withLength(min: 1, max: 36)();
  TextColumn get compraId => text()();
  TextColumn get empresaId => text()();
  TextColumn get productoId => text().nullable()();
  TextColumn get productoCodigo => text().nullable()();
  TextColumn get productoNombre => text()();
  TextColumn get descripcion => text().nullable()();
  IntColumn get cantidad => integer()();
  RealColumn get precioUnitario => real()();
  RealColumn get descuento => real().withDefault(const Constant(0.0))();
  RealColumn get isvRate => real().withDefault(const Constant(15.0))();
  RealColumn get subtotal => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Empresas,
  Usuarios,
  EmpresaModulos,
  UsuarioModulos,
  Facturas,
  Clientes,
  Productos,
  Transacciones,
  Empleados,
  Nomina,
  SyncQueue,
  Drafts,
  SarConfiguracion,
  SarCorrelativo,
  SarContingencia,
  PosVentas,
  PosVentaItems,
  PosArqueoCaja,
  PosPromociones,
  PosClienteCredito,
  PosConfig,
  Rutas,
  RutaClientes,
  FiadoAbonos,
  Sucursales,
  Transferencias,
  TransferenciaItems,
  Membresias,
  Socios,
  SocioMembresias,
  SocioPrecios,
  Proveedores,
  Cotizaciones,
  CotizacionItems,
  OrdenesCompra,
  OrdenCompraItems,
  Compras,
  CompraItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(sarConfiguracion);
            await m.createTable(sarCorrelativo);
            await m.createTable(sarContingencia);
          }
          if (from < 3) {
            await m.addColumn(sarConfiguracion, sarConfiguracion.regimen);
            await m.addColumn(
              posClienteCredito,
              posClienteCredito.clienteNombre,
            );
            await m.addColumn(
              posClienteCredito,
              posClienteCredito.fechaUltimaVenta,
            );
            await m.createTable(rutas);
            await m.createTable(rutaClientes);
            await m.createTable(fiadoAbonos);
          }
          if (from < 4) {
            await m.createTable(sucursales);
            await m.createTable(transferencias);
            await m.createTable(transferenciaItems);
          }
          if (from < 5) {
            await m.createTable(membresias);
            await m.createTable(socios);
            await m.createTable(socioMembresias);
            await m.createTable(socioPrecios);
          }
          if (from < 6) {
            await m.createTable(proveedores);
            await m.createTable(cotizaciones);
            await m.createTable(cotizacionItems);
            await m.createTable(ordenesCompra);
            await m.createTable(ordenCompraItems);
            await m.createTable(compras);
            await m.createTable(compraItems);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'portal_pilot.db'));
    return NativeDatabase.createInBackground(file);
  });
}
