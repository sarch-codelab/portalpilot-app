// lib/Shared/services/operaciones_service.dart
// Cliente de las APIs operativas de FASE 5: mermas, pasillos, mesas, cuentas
// abiertas y control de acceso de socios.
//
// REGLA DE ESTA CAPA: aqui NO hay reglas de negocio. No se calcula ISV, no se
// descuenta stock, no se valida permisos ni plan. Todo eso vive en el backend y
// la pantalla solo presenta lo que el servidor devuelve, incluidos los errores.
//
// Cada metodo devuelve la respuesta cruda de ApiService (`Map<String,dynamic>`),
// que trae `error` en vez de lanzar excepcion. Quien llama decide si eso es un
// estado vacio (403 por plan), un error visible o un reintento.

import 'package:portal_pilot_app/Shared/services/api_service.dart';

/// Resultado tipado de una consulta de lista.
class ListaOperativa<T> {
  final List<T> items;
  final String? error;
  final bool sinPermiso;

  const ListaOperativa(this.items, {this.error, this.sinPermiso = false});

  const ListaOperativa.vacia({this.error, this.sinPermiso = false}) : items = const [];

  bool get hayError => error != null;
  bool get vacia => items.isEmpty;
}

/// Un producto tal y como lo expone /api/productos, para los selectores.
class ProductoOperativo {
  final String id;
  final String codigo;
  final String nombre;
  final String? categoria;
  final String? marca;
  final String? pasilloId;
  final double stock;
  final double precioVenta;
  final bool activo;

  const ProductoOperativo({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.categoria,
    this.marca,
    this.pasilloId,
    this.stock = 0,
    this.precioVenta = 0,
    this.activo = true,
  });

  factory ProductoOperativo.desdeFila(Map<String, dynamic> f) {
    return ProductoOperativo(
      id: (f['id'] ?? '').toString(),
      codigo: (f['codigo'] ?? '').toString(),
      nombre: (f['nombre'] ?? '').toString(),
      categoria: f['categoria']?.toString(),
      marca: f['marca']?.toString(),
      pasilloId: f['pasillo_id']?.toString(),
      stock: _d(f['stock_actual']),
      precioVenta: _d(f['precio_venta']),
      activo: f['activo'] == null || f['activo'] == true,
    );
  }

  static double _d(dynamic v) =>
      v == null ? 0 : (double.tryParse(v.toString()) ?? 0);
}

class OperacionesService {
  OperacionesService._privateConstructor();
  static final OperacionesService instance = OperacionesService._privateConstructor();

  ApiService get _api => ApiService.instance;

  static bool _esFalloPlan(Map<String, dynamic> r) {
    final codigo = (r['code'] ?? r['codigo'] ?? '').toString().toUpperCase();
    return codigo.contains('PLAN') || codigo == '403' || r['status'] == 403;
  }

  static String? _errorDe(Map<String, dynamic> r) {
    final e = r['error'];
    if (e == null) return null;
    final s = e.toString().trim();
    return s.isEmpty ? 'Error desconocido' : s;
  }

  static List<Map<String, dynamic>> _filas(dynamic lista) {
    if (lista is! List) return const [];
    return lista.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  // ---------------------------------------------------------------- mermas

  /// Listado de mermas. [desde]/[hasta] en ISO (yyyy-mm-dd).
  Future<ListaOperativa<Map<String, dynamic>>> mermas({
    String? productoId,
    String? desde,
    String? hasta,
  }) async {
    final q = <String, String>{
      if (productoId != null && productoId.isNotEmpty) 'producto_id': productoId,
      if (desde != null && desde.isNotEmpty) 'desde': desde,
      if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
    };
    final r = await _api.get('/api/mermas', queryParams: q.isEmpty ? null : q);
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['mermas']));
  }

  /// Resumen de perdidas por tipo y producto (lo calcula el servidor).
  Future<ListaOperativa<Map<String, dynamic>>> resumenMermas({
    String? desde,
    String? hasta,
  }) async {
    final q = <String, String>{
      if (desde != null && desde.isNotEmpty) 'desde': desde,
      if (hasta != null && hasta.isNotEmpty) 'hasta': hasta,
    };
    final r = await _api.get('/api/mermas/resumen', queryParams: q.isEmpty ? null : q);
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa([r]);
  }

  /// Registra una merma. El stock, el kardex y el costo los aplica el backend;
  /// por eso aqui solo se envian los datos capturados por el usuario.
  Future<Map<String, dynamic>> registrarMerma({
    required String productoId,
    required String cantidad,
    required String tipo,
    required String motivo,
    String? notas,
  }) async {
    return _api.post('/api/mermas', body: {
      'producto_id': productoId,
      'cantidad': cantidad,
      'tipo': tipo,
      'motivo': motivo,
      if (notas != null && notas.isNotEmpty) 'notas': notas,
    });
  }

  /// Productos para el selector de merma: solo activos.
  Future<ListaOperativa<ProductoOperativo>> productos({String? pasilloId}) async {
    final q = <String, String>{
      'activo': 'true',
      if (pasilloId != null && pasilloId.isNotEmpty) 'pasillo_id': pasilloId,
    };
    final r = await _api.get('/api/productos', queryParams: q);
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(
      _filas(r['productos']).map(ProductoOperativo.desdeFila).toList(),
    );
  }

  // -------------------------------------------------------------- pasillos

  Future<ListaOperativa<Map<String, dynamic>>> pasillos() async {
    final r = await _api.get('/api/pasillos');
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['pasillos']));
  }

  Future<Map<String, dynamic>> crearPasillo({
    required String nombre,
    String? codigo,
  }) =>
      _api.post('/api/pasillos', body: {
        'nombre': nombre,
        if (codigo != null && codigo.isNotEmpty) 'codigo': codigo,
      });

  Future<Map<String, dynamic>> editarPasillo(String id, {String? nombre, String? codigo}) =>
      _api.put('/api/pasillos/$id', body: {
        if (nombre != null) 'nombre': nombre,
        if (codigo != null) 'codigo': codigo,
      });

  /// El backend desactiva en vez de borrar (PUT con activo:false): el pasillo
  /// queda en el historico de sus productos. Por eso la app no adivina.
  Future<Map<String, dynamic>> desactivarPasillo(String id) =>
      _api.put('/api/pasillos/$id', body: {'activo': false});

  Future<Map<String, dynamic>> reactivarPasillo(String id) =>
      _api.put('/api/pasillos/$id', body: {'activo': true});

  // ----------------------------------------------------------------- mesas

  Future<ListaOperativa<Map<String, dynamic>>> mesas() async {
    final r = await _api.get('/api/mesas');
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['mesas']));
  }

  Future<Map<String, dynamic>> crearMesa({
    required String nombre,
    String? codigo,
    String? zona,
    int? capacidad,
    String? precioConsumo,
  }) =>
      _api.post('/api/mesas', body: {
        'nombre': nombre,
        if (codigo != null && codigo.isNotEmpty) 'codigo': codigo,
        if (zona != null && zona.isNotEmpty) 'zona': zona,
        if (capacidad != null) 'capacidad': capacidad,
        if (precioConsumo != null && precioConsumo.isNotEmpty) 'precio_consumo': precioConsumo,
      });

  /// Estado manual. El backend NO admite `ocupada`: esa la gobierna el ciclo de
  /// la cuenta abierta, por eso la app solo ofrece reservada/fuera_servicio/libre.
  Future<Map<String, dynamic>> editarMesa(
    String id, {
    String? nombre,
    String? zona,
    int? capacidad,
    String? precioConsumo,
    String? estado,
    bool? activa,
  }) =>
      _api.put('/api/mesas/$id', body: {
        if (nombre != null) 'nombre': nombre,
        if (zona != null) 'zona': zona,
        if (capacidad != null) 'capacidad': capacidad,
        if (precioConsumo != null) 'precio_consumo': precioConsumo,
        if (estado != null) 'estado': estado,
        if (activa != null) 'activa': activa,
      });

  Future<Map<String, dynamic>> desactivarMesa(String id) => _api.delete('/api/mesas/$id');

  // ------------------------------------------------------- cuentas abiertas

  Future<ListaOperativa<Map<String, dynamic>>> cuentas({String estado = 'abierta'}) async {
    final r = await _api.get('/api/cuentas-abiertas', queryParams: {'estado': estado});
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['cuentas']));
  }

  /// Cuenta + mesa + detalle. `detalle` es la lista de consumos ya cobrados en
  /// precios e ISV por el backend.
  Future<ListaOperativa<Map<String, dynamic>>> cuenta(String id) async {
    final r = await _api.get('/api/cuentas-abiertas/$id');
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa([r]);
  }

  Future<Map<String, dynamic>> abrirCuenta({
    required String clienteNombre,
    String? mesaId,
    String? socioId,
    String? notas,
  }) =>
      _api.post('/api/cuentas-abiertas', body: {
        'cliente_nombre': clienteNombre,
        if (mesaId != null && mesaId.isNotEmpty) 'mesa_id': mesaId,
        if (socioId != null && socioId.isNotEmpty) 'socio_id': socioId,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      });

  /// Agrega consumos. El precio y el ISV los pone el catalogo del tenant.
  Future<Map<String, dynamic>> agregarConsumos(
    String cuentaId,
    List<Map<String, dynamic>> items,
  ) =>
      _api.post('/api/cuentas-abiertas/$cuentaId/consumos', body: {'items': items});

  /// Cambia la cantidad de una linea. El backend ajusta stock por la diferencia.
  Future<Map<String, dynamic>> editarConsumo(
    String cuentaId,
    String detalleId, {
    required String cantidad,
  }) =>
      _api.put('/api/cuentas-abiertas/$cuentaId/consumos/$detalleId',
          body: {'cantidad': cantidad});

  /// Elimina una linea y devuelve el stock. Solo mientras la cuenta este abierta.
  Future<Map<String, dynamic>> eliminarConsumo(String cuentaId, String detalleId) =>
      _api.delete('/api/cuentas-abiertas/$cuentaId/consumos/$detalleId');

  Future<Map<String, dynamic>> cerrarCuenta(
    String cuentaId, {
    required String formaPago,
    String? descuento,
  }) =>
      _api.post('/api/cuentas-abiertas/$cuentaId/cerrar', body: {
        'forma_pago': formaPago,
        if (descuento != null && descuento.isNotEmpty) 'descuento': descuento,
      });

  // ------------------------------------------------------ socios y accesos

  /// Socios del tenant. [q] se envia como `search`: el backend lo resuelve
  /// sobre nombre, numero_socio y email.
  Future<ListaOperativa<Map<String, dynamic>>> socios({String? q}) async {
    final r = await _api.get('/api/membresias/socios',
        queryParams: (q == null || q.trim().isEmpty) ? null : {'search': q.trim()});
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['socios']));
  }

  Future<Map<String, dynamic>> crearSocio({
    required String nombre,
    String? email,
    String? telefono,
    String? planId,
    String? fechaVencimiento,
  }) =>
      _api.post('/api/membresias/socios', body: {
        'nombre': nombre,
        if (email != null && email.isNotEmpty) 'email': email,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        if (planId != null && planId.isNotEmpty) 'plan_id': planId,
        if (fechaVencimiento != null && fechaVencimiento.isNotEmpty)
          'fecha_vencimiento': fechaVencimiento,
      });

  /// Actualiza socio. El estado y el vencimiento los gobierna el negocio: la app
  /// los envia, el backend valida.
  Future<Map<String, dynamic>> editarSocio(
    String id, {
    String? email,
    String? telefono,
    String? planId,
    String? fechaVencimiento,
    String? estado,
  }) =>
      _api.put('/api/membresias/socios/$id', body: {
        if (email != null) 'email': email,
        if (telefono != null) 'telefono': telefono,
        if (planId != null) 'plan_id': planId,
        if (fechaVencimiento != null) 'fecha_vencimiento': fechaVencimiento,
        if (estado != null) 'estado': estado,
      });

  /// Planes de membresia para asignar a un socio.
  Future<ListaOperativa<Map<String, dynamic>>> planesMembresia() async {
    final r = await _api.get('/api/membresias/planes');
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['planes']));
  }

  /// Token del QR de la credencial. La firma la verifica el backend.
  Future<ListaOperativa<Map<String, dynamic>>> qrSocio(String socioId) async {
    final r = await _api.get('/api/membresias/socios/$socioId/qr');
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa([r]);
  }

  /// Miembros actualmente dentro del club (ultimo registro por socio).
  Future<ListaOperativa<Map<String, dynamic>>> dentroAhora() async {
    final r = await _api.get('/api/socios-accesos/actuales');
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['dentro']));
  }

  /// Historial de accesos, opcionalmente de un socio.
  Future<ListaOperativa<Map<String, dynamic>>> accesos({String? socioId, String? estado}) async {
    final q = <String, String>{
      if (socioId != null && socioId.isNotEmpty) 'socio_id': socioId,
      if (estado != null && estado.isNotEmpty) 'estado': estado,
    };
    final r = await _api.get('/api/socios-accesos', queryParams: q.isEmpty ? null : q);
    final err = _errorDe(r);
    if (err != null) {
      return ListaOperativa.vacia(error: err, sinPermiso: _esFalloPlan(r));
    }
    return ListaOperativa(_filas(r['accesos']));
  }

  /// Registra entrada, salida o rechazo. Las reglas (vencimiento, estado del
  /// socio) las aplica el backend, que responde 409 con el motivo.
  Future<Map<String, dynamic>> registrarAcceso({
    String? socioId,
    String? socioNombre,
    required String tipoAcceso,
    String? motivo,
    String? puerta,
    String? turno,
  }) =>
      _api.post('/api/socios-accesos', body: {
        if (socioId != null && socioId.isNotEmpty) 'socio_id': socioId,
        if (socioNombre != null && socioNombre.isNotEmpty) 'socio_nombre': socioNombre,
        'tipo_acceso': tipoAcceso,
        if (motivo != null && motivo.isNotEmpty) 'motivo_rechazo': motivo,
        if (puerta != null && puerta.isNotEmpty) 'puerta': puerta,
        if (turno != null && turno.isNotEmpty) 'turno': turno,
      });

  /// Lector de la puerta: valida la firma del QR y registra el acceso.
  Future<Map<String, dynamic>> validarQr(String token, {String? puerta}) =>
      _api.post('/api/socios-accesos/validar-qr', body: {
        'token': token,
        if (puerta != null && puerta.isNotEmpty) 'puerta': puerta,
      });
}