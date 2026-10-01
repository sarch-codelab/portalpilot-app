import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

class PortalPilotDB {
  static const String apiRoot = String.fromEnvironment(
    'API_ROOT',
    defaultValue: 'https://portal-pilot.vercel.app',
  );
  static const Duration _timeout = Duration(seconds: 20);

  static final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  /// Inicializa la capa de backend para producción.
  static Future<void> initialize() async {
    debugPrint('🔄 Backend listo para producción mediante Vercel.');
  }

  /// Obtiene la empresa actual desde el token/usuario logueado
  static String? _currentEmpresaCodigo;
  static void setEmpresaCodigo(String codigo) => _currentEmpresaCodigo = codigo;
  static String? get empresaCodigo => _currentEmpresaCodigo;

  // ═══════════════════════════════════════════════════════════════
  // READ METHODS (offline-first - read from local DB)
  // ═══════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getFacturas(String empresaCodigo) async {
    final facturas = await _localDb.getFacturas(empresaCodigo);
    return facturas.map((f) => {
      'id': f.id,
      'empresa_id': f.empresaId,
      'usuario_id': f.usuarioId,
      'correlativo': f.correlativo,
      'tipo_documento': f.tipoDocumento,
      'cai': f.cai,
      'rango_inicio': f.rangoInicio,
      'rango_fin': f.rangoFin,
      'fecha_limite_emision': f.fechaLimiteEmision?.toIso8601String(),
      'cliente_nombre': f.clienteNombre,
      'cliente_rtn': f.clienteRtn,
      'cliente_direccion': f.clienteDireccion,
      'condicion_pago': f.condicionPago,
      'tipo_venta': f.tipoVenta,
      'items': f.items,
      'subtotal': f.subtotal,
      'isv_15': f.isv15,
      'isv_18': f.isv18,
      'descuento': f.descuento,
      'total': f.total,
      'estado': f.estado,
      'fecha_anulacion': f.fechaAnulacion?.toIso8601String(),
      'motivo_anulacion': f.motivoAnulacion,
      'notas': f.notas,
      'created_at': f.createdAt.toIso8601String(),
      'updated_at': f.updatedAt.toIso8601String(),
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getClientes(String empresaCodigo) async {
    final clientes = await _localDb.getClientes(empresaCodigo);
    return clientes.map((c) => {
      'id': c.id,
      'empresa_id': c.empresaId,
      'nombre': c.nombre,
      'rtn': c.rtn,
      'direccion': c.direccion,
      'telefono': c.telefono,
      'email': c.email,
      'notas': c.notas,
      'activo': c.activo,
      'created_at': c.createdAt.toIso8601String(),
      'updated_at': c.updatedAt.toIso8601String(),
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getProductos(String empresaCodigo) async {
    final productos = await _localDb.getProductos(empresaCodigo);
    return productos.map((p) => {
      'id': p.id,
      'empresa_id': p.empresaId,
      'codigo': p.codigo,
      'nombre': p.nombre,
      'descripcion': p.descripcion,
      'categoria': p.categoria,
      'unidad_medida': p.unidadMedida,
      'precio_compra': p.precioCompra,
      'precio_venta': p.precioVenta,
      'stock_minimo': p.stockMinimo,
      'stock_actual': p.stockActual,
      'bodega': p.bodega,
      'isv_rate': p.isvRate,
      'exento': p.exento,
      'is_perishable': p.isPerishable,
      'imagen_url': p.imagenUrl,
      'activo': p.activo,
      'created_at': p.createdAt.toIso8601String(),
      'updated_at': p.updatedAt.toIso8601String(),
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getTransacciones(String empresaCodigo) async {
    final transacciones = await _localDb.getTransacciones(empresaCodigo);
    return transacciones.map((t) => {
      'id': t.id,
      'empresa_id': t.empresaId,
      'usuario_id': t.usuarioId,
      'tipo': t.tipo,
      'categoria': t.categoria,
      'descripcion': t.descripcion,
      'monto': t.monto,
      'metodo_pago': t.metodoPago,
      'referencia': t.referencia,
      'fecha': t.fecha.toIso8601String(),
      'created_at': t.createdAt.toIso8601String(),
      'updated_at': t.updatedAt.toIso8601String(),
    }).toList();
  }
  // ═══════════════════════════════════════════════════════════════
  // SYNC METHODS (used by SyncService)
  // ═══════════════════════════════════════════════════════════════

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$apiRoot$path');
    if (query == null) return base;
    return base.replace(queryParameters: query);
  }

  /// Headers con autenticación Bearer para los endpoints de la WEB (producción).
  static Map<String, String> get _headers {
    final token = AuthController.instance.token;
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _postJson(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    if (response.statusCode >= 400) {
      debugPrint('⚠️ POST $path -> ${response.statusCode}: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// No borra el elemento de la cola cuando un endpoint responde 2xx con
  /// errores parciales; el lote debe quedar pendiente para reintento.
  static bool _responseAccepted(dynamic result) {
    if (result == null) return false;
    if (result is! Map) return true;
    if (result['error'] != null || result['success'] == false) return false;
    final errors = result['errores'];
    return errors is! List || errors.isEmpty;
  }

  /// Facturas - sync to backend
  static Future<bool> insertFactura({required Map<String, dynamic> factura, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/facturas', {'empresa_codigo': empresaCodigo, 'factura': factura});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertFactura sync: $e');
      return false;
    }
  }

  static Future<bool> anularFactura({required String id, required String empresaCodigo}) async {
    try {
      final response = await http
          .patch(
            _uri('/api/facturas', {'id': id}),
            headers: _headers,
            body: jsonEncode({
              'empresa_codigo': empresaCodigo,
              'estado': 'anulada',
              'fecha_anulacion': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(_timeout);
      if (response.statusCode >= 400) {
        debugPrint('⚠️ anularFactura sync -> ${response.statusCode}: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ anularFactura sync: $e');
      return false;
    }
  }

  /// Transacciones - sync to backend
  static Future<bool> insertTransaccion({required Map<String, dynamic> transaccion, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/transacciones', {
        'empresa_codigo': empresaCodigo,
        'transaccion': transaccion,
      });
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertTransaccion sync: $e');
      return false;
    }
  }

  /// Clientes - sync to backend
  static Future<bool> insertCliente({required Map<String, dynamic> cliente, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/clientes', {'empresa_codigo': empresaCodigo, 'cliente': cliente});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertCliente sync: $e');
      return false;
    }
  }

  /// Productos - sync to backend
  static Future<bool> syncProductos({required List<Map<String, dynamic>> productos, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/productos', {'empresa_codigo': empresaCodigo, 'productos': productos});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ syncProductos sync: $e');
      return false;
    }
  }

  /// Productos - borrar por código y empresa en la API.
  static Future<bool> deleteProducto({required String id, required String codigo, required String empresaCodigo}) async {
    try {
      if (empresaCodigo.trim().isEmpty || codigo.trim().isEmpty) return false;
      final response = await http
          .delete(
            _uri('/api/productos'),
            headers: _headers,
            body: jsonEncode({'empresa_codigo': empresaCodigo, 'codigo': codigo}),
          )
          .timeout(_timeout);
      if (response.statusCode >= 400) {
        debugPrint('⚠️ DELETE /api/productos -> ${response.statusCode}: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ deleteProducto sync: $e');
      return false;
    }
  }

  /// Proveedores - sync to backend
  static Future<bool> insertProveedor({required Map<String, dynamic> proveedor, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/proveedores', {'empresa_codigo': empresaCodigo, 'proveedor': proveedor});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertProveedor sync: $e');
      return false;
    }
  }

  /// Cotizaciones - sync to backend
  static Future<bool> insertCotizacion({required Map<String, dynamic> cotizacion, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/cotizaciones', {'empresa_codigo': empresaCodigo, 'cotizacion': cotizacion});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertCotizacion sync: $e');
      return false;
    }
  }

  /// Ordenes de compra - sync to backend
  static Future<bool> insertOrdenCompra({required Map<String, dynamic> orden, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/ordenes-compra', {'empresa_codigo': empresaCodigo, 'orden_compra': orden});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertOrdenCompra sync: $e');
      return false;
    }
  }

  /// Compras (recepción) - sync to backend
  static Future<bool> insertCompra({required Map<String, dynamic> compra, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/compras', {'empresa_codigo': empresaCodigo, 'compra': compra});
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertCompra sync: $e');
      return false;
    }
  }

  /// POS - registra la venta directamente en /api/pos/ventas. Es la ruta que
  /// el backend desplegado soporta (la /api/sync genérica del despliegue
  /// actual no conoce pos_ventas y responde "Tabla no soportada").
  static Future<bool> insertPosVenta({required Map<String, dynamic> ventaPayload}) async {
    try {
      final result = await _postJson('/api/pos/ventas', ventaPayload);
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ insertPosVenta sync: $e');
      return false;
    }
  }

  /// Sync genérico por tabla (ruta /api/sync) para cualquier entidad.
  /// El backend hace upsert idempotente fila por fila y reporta errores
  /// individuales para que la cola siga procesando el resto.
  static Future<bool> syncRows({
    required String tabla,
    required String empresaCodigo,
    required List<Map<String, dynamic>> rows,
    String operacion = 'insert',
  }) async {
    try {
      final result = await _postJson('/api/sync', {
        'empresa_codigo': empresaCodigo,
        'tabla': tabla,
        'operacion': operacion,
        'rows': rows,
      });
      if (!_responseAccepted(result) || result is! Map) return false;
      final confirmed = result['ok'];
      return confirmed is num && confirmed.toInt() == rows.length;
    } catch (e) {
      debugPrint('❌ syncRows ($tabla) sync: $e');
      return false;
    }
  }

  /// Notas - sync to backend
  static Future<bool> saveNotas({
    required String empresaCodigo,
    required String clave,
    required Map<String, dynamic> datos,
  }) async {
    try {
      final result = await _postJson('/api/notas', {
        'empresa_codigo': empresaCodigo,
        'clave': clave,
        'datos': datos,
      });
      return _responseAccepted(result);
    } catch (e) {
      debugPrint('❌ saveNotas sync: $e');
      return false;
    }
  }

  /// Login contra el backend Express (requiere internet)
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$apiRoot/api/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);

    final String responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(responseBody) as Map<String, dynamic>?;
    } catch (_) {
      data = null;
    }

    if (response.statusCode == 200) {
      return data ?? {};
    }

    String errorMessage = 'Error al iniciar sesión.';
    if (data != null) {
      if (data['error'] != null) {
        errorMessage = data['error'].toString();
      } else if (data['message'] != null) {
        errorMessage = data['message'].toString();
      } else if (data['protection'] != null) {
        errorMessage =
            'La API está protegida por Vercel. Desactiva la protección de despliegue o usa un dominio público válido.';
      }
    } else if (response.statusCode == 401) {
      errorMessage =
          'No autorizado. El despliegue está protegido o la API requiere autenticación.';
    } else if (response.statusCode == 404) {
      errorMessage =
          'No se encontró el endpoint de login. Revisa la URL de la API y la configuración de Vercel.';
    }

    throw Exception('$errorMessage (Código ${response.statusCode})');
  }
}

class UserModel {
  final String id;
  final String? nombre;
  final String? apellido;
  final String email;
  final String rol;
  final String? area;
  final String? rango;
  final String status;
  final String empresaCodigo;
  final String? empresaNombre;
  final String token;

  UserModel({
    required this.id,
    this.nombre,
    this.apellido,
    required this.email,
    required this.rol,
    this.area,
    this.rango,
    required this.status,
    required this.empresaCodigo,
    this.empresaNombre,
    required this.token,
  });

  factory UserModel.fromBackendJson(Map<String, dynamic> user, String token) {
    return UserModel(
      id: (user['id'] ?? '').toString(),
      nombre: user['nombre']?.toString(),
      apellido: user['apellido']?.toString(),
      email: user['email']?.toString() ?? '',
      rol: user['rol']?.toString() ?? 'Empleado',
      area: user['area']?.toString(),
      rango: user['rango']?.toString(),
      status: user['status']?.toString() ?? 'active',
      empresaCodigo: (user['empresa_codigo'] ?? '').toString().trim().toUpperCase(),
      empresaNombre: user['empresa_nombre']?.toString() ?? user['tenant']?.toString(),
      token: token,
    );
  }

  bool get isRoot =>
      empresaCodigo == 'ROOT' ||
      rol.toLowerCase().contains('root') ||
      rol.toLowerCase().contains('admin');

  bool get isActive {
    final s = status.toLowerCase();
    return s == 'active' || s == 'activo';
  }
}
