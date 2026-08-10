import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:portal_pilot_app/Shared/database/app_database.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';

class PortalPilotDB {
  static const String apiRoot = String.fromEnvironment(
    'API_ROOT',
    defaultValue: 'https://portalpilot-app.vercel.app',
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
  // MATRÍCULAS (offline-first)
  // ═══════════════════════════════════════════════════════════════

  /// Inserta una matrícula completa - guarda localmente y encola sync
  static Future<void> insertMatriculaCompleta({
    required String folioMatricula,
    required String cicloEscolar,
    required String nivelEducativo,
    required String grado,
    required String seccion,
    required String turno,
    required String tipoIngreso,
    required String alumnoNombre,
    required String alumnoApellido,
    required String alumnoDni,
    required String alumnoFechaNacimiento,
    required String alumnoLugarNacimiento,
    required String alumnoNacionalidad,
    required String observacionesSalud,
    required String tutorParentesco,
    required String tutorNombre,
    required String tutorTelefono,
    required String tutorEmail,
    required String direccionCalle,
    required String direccionMunicipio,
    required String direccionDepartamento,
    required String direccionReferencia,
    required String direccionCP,
    required bool pagoInscripcionRealizado,
    required String metodoPago,
    required String planPagos,
    required String empresaCodigo,
    String estado = 'pendiente',
  }) async {
    final id = folioMatricula;
    final localDb = _localDb;

    await localDb.insertMatriculaLocal(
      id: id,
      empresaId: empresaCodigo,
      estudianteNombre: '$alumnoNombre $alumnoApellido',
      estudianteId: alumnoDni,
      grado: grado,
      seccion: seccion,
      turno: turno,
      estado: estado,
      fechaMatricula: DateTime.now(),
      observaciones: observacionesSalud,
    );

    debugPrint('✅ Matrícula guardada localmente: $folioMatricula');
  }

  /// Obtiene matrículas desde BD local (instantáneo, funciona offline)
  static Future<List<Map<String, dynamic>>> getMatriculasByEmpresa(String empresaCodigo) async {
    final matriculas = await _localDb.getMatriculas(empresaCodigo);
    return matriculas.map((m) => {
          'id': m.id ?? '',
          'folio_matricula': m.id ?? '',
          'empresa_codigo': m.empresaId ?? '',
          'ciclo_escolar': '2024-2025',
          'nivel_educativo': m.grado ?? '',
          'grado': m.grado ?? '',
          'seccion': m.seccion ?? '',
          'turno': m.turno ?? '',
          'tipo_ingreso': 'nuevo',
          'alumno_nombre': (m.estudianteNombre ?? '').split(' ').first,
          'alumno_apellido': (m.estudianteNombre ?? '').split(' ').length > 1
              ? (m.estudianteNombre ?? '').split(' ').skip(1).join(' ')
              : '',
          'alumno_dni': m.estudianteId ?? '',
          'alumno_fecha_nacimiento': '',
          'alumno_lugar_nacimiento': '',
          'alumno_nacionalidad': '',
          'observaciones_salud': m.observaciones ?? '',
          'tutor_parentesco': '',
          'tutor_nombre': '',
          'tutor_telefono': '',
          'tutor_email': '',
          'direccion_calle': '',
          'direccion_municipio': '',
          'direccion_departamento': '',
          'direccion_referencia': '',
          'direccion_cp': '',
          'pago_inscripcion_realizado': false,
          'metodo_pago': '',
          'plan_pagos': '',
          'estado': m.estado ?? 'pendiente',
          'created_at': m.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'updated_at': m.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        }).toList();
  }

  /// Obtiene estadísticas desde BD local
  static Future<Map<String, dynamic>> getEstadisticasMatriculas(String empresaCodigo) async {
    final matriculas = await _localDb.getMatriculas(empresaCodigo);
    return {
      'total': matriculas.length,
      'activas': matriculas.where((m) => m.estado == 'activa').length,
      'pendientes': matriculas.where((m) => m.estado == 'pendiente').length,
      'inactivas': matriculas.where((m) => m.estado == 'inactiva').length,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // READ METHODS (offline-first - read from local DB)
  // ═══════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getFacturas(String empresaCodigo) async {
    final facturas = await _localDb.getFacturas(empresaCodigo);
    return facturas.map((f) => {
      'id': f.id ?? '',
      'empresa_id': f.empresaId ?? '',
      'usuario_id': f.usuarioId,
      'correlativo': f.correlativo ?? '',
      'tipo_documento': f.tipoDocumento ?? 'Factura',
      'cai': f.cai ?? '',
      'rango_inicio': f.rangoInicio,
      'rango_fin': f.rangoFin,
      'fecha_limite_emision': f.fechaLimiteEmision?.toIso8601String(),
      'cliente_nombre': f.clienteNombre,
      'cliente_rtn': f.clienteRtn,
      'cliente_direccion': f.clienteDireccion,
      'condicion_pago': f.condicionPago ?? 'Contado',
      'tipo_venta': f.tipoVenta ?? 'Gravada',
      'items': f.items,
      'subtotal': f.subtotal ?? 0.0,
      'isv_15': f.isv15 ?? 0.0,
      'isv_18': f.isv18 ?? 0.0,
      'descuento': f.descuento ?? 0.0,
      'total': f.total ?? 0.0,
      'estado': f.estado ?? 'emitida',
      'fecha_anulacion': f.fechaAnulacion?.toIso8601String(),
      'motivo_anulacion': f.motivoAnulacion,
      'notas': f.notas,
      'created_at': f.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': f.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getClientes(String empresaCodigo) async {
    final clientes = await _localDb.getClientes(empresaCodigo);
    return clientes.map((c) => {
      'id': c.id ?? '',
      'empresa_id': c.empresaId ?? '',
      'nombre': c.nombre ?? '',
      'rtn': c.rtn,
      'direccion': c.direccion,
      'telefono': c.telefono,
      'email': c.email,
      'notas': c.notas,
      'activo': c.activo ?? true,
      'created_at': c.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': c.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getProductos(String empresaCodigo) async {
    final productos = await _localDb.getProductos(empresaCodigo);
    return productos.map((p) => {
      'id': p.id ?? '',
      'empresa_id': p.empresaId ?? '',
      'codigo': p.codigo,
      'nombre': p.nombre ?? '',
      'descripcion': p.descripcion,
      'categoria': p.categoria,
      'unidad_medida': p.unidadMedida ?? 'Unidad',
      'precio_compra': p.precioCompra ?? 0.0,
      'precio_venta': p.precioVenta ?? 0.0,
      'stock_minimo': p.stockMinimo ?? 0,
      'stock_actual': p.stockActual ?? 0,
      'bodega': p.bodega ?? 'General',
      'isv_rate': p.isvRate ?? 15.0,
      'exento': p.exento ?? false,
      'imagen_url': p.imagenUrl,
      'activo': p.activo ?? true,
      'created_at': p.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': p.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getTransacciones(String empresaCodigo) async {
    final transacciones = await _localDb.getTransacciones(empresaCodigo);
    return transacciones.map((t) => {
      'id': t.id ?? '',
      'empresa_id': t.empresaId ?? '',
      'usuario_id': t.usuarioId,
      'tipo': t.tipo ?? '',
      'categoria': t.categoria,
      'descripcion': t.descripcion,
      'monto': t.monto ?? 0.0,
      'metodo_pago': t.metodoPago,
      'referencia': t.referencia,
      'fecha': t.fecha?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': t.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': t.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    }).toList();
  }

  static Future<Map<String, dynamic>?> getNotas(String empresaCodigo, String clave) async {
    // clave format: matriculaId|materia|trimestre
    final parts = clave.split('|');
    if (parts.length != 3) return null;
    
    final matriculaId = parts[0];
    final materia = parts[1];
    final trimestre = int.tryParse(parts[2]) ?? 1;
    
    final notas = await _localDb.getNotas(empresaCodigo, matriculaId);
    Nota? nota;
    for (final n in notas) {
      if (n.materia == materia && n.trimestre == trimestre) {
        nota = n;
        break;
      }
    }
    
    if (nota == null) return null;
    
    return {
      'materia': nota.materia ?? '',
      'trimestre': nota.trimestre ?? 1,
      'nota': nota.nota,
      'observaciones': nota.observaciones,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // SYNC METHODS (used by SyncService)
  // ═══════════════════════════════════════════════════════════════

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$apiRoot$path');
    if (query == null) return base;
    return base.replace(queryParameters: query);
  }

  static Future<dynamic> _postJson(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(_uri(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(_timeout);
    if (response.statusCode >= 400) {
      debugPrint('⚠️ POST $path -> ${response.statusCode}: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<dynamic> _getJson(String path, [Map<String, String>? query]) async {
    final response = await http.get(_uri(path, query)).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('⚠️ GET $path -> ${response.statusCode}');
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// Facturas - sync to backend
  static Future<bool> insertFactura({required Map<String, dynamic> factura, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/facturas', {'empresa_codigo': empresaCodigo, 'factura': factura});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertFactura sync: $e');
      return false;
    }
  }

  static Future<bool> anularFactura({required String id, required String empresaCodigo}) async {
    try {
      final uri = _uri('/api/facturas', {'id': id});
      final response = await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
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
      return result != null;
    } catch (e) {
      debugPrint('❌ insertTransaccion sync: $e');
      return false;
    }
  }

  /// Clientes - sync to backend
  static Future<bool> insertCliente({required Map<String, dynamic> cliente, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/clientes', {'empresa_codigo': empresaCodigo, 'cliente': cliente});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertCliente sync: $e');
      return false;
    }
  }

  /// Productos - sync to backend
  static Future<bool> syncProductos({required List<Map<String, dynamic>> productos, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/productos', {'empresa_codigo': empresaCodigo, 'productos': productos});
      return result != null;
    } catch (e) {
      debugPrint('❌ syncProductos sync: $e');
      return false;
    }
  }

  /// Proveedores - sync to backend
  static Future<bool> insertProveedor({required Map<String, dynamic> proveedor, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/proveedores', {'empresa_codigo': empresaCodigo, 'proveedor': proveedor});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertProveedor sync: $e');
      return false;
    }
  }

  /// Cotizaciones - sync to backend
  static Future<bool> insertCotizacion({required Map<String, dynamic> cotizacion, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/cotizaciones', {'empresa_codigo': empresaCodigo, 'cotizacion': cotizacion});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertCotizacion sync: $e');
      return false;
    }
  }

  /// Ordenes de compra - sync to backend
  static Future<bool> insertOrdenCompra({required Map<String, dynamic> orden, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/ordenes-compra', {'empresa_codigo': empresaCodigo, 'orden_compra': orden});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertOrdenCompra sync: $e');
      return false;
    }
  }

  /// Compras (recepción) - sync to backend
  static Future<bool> insertCompra({required Map<String, dynamic> compra, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/compras', {'empresa_codigo': empresaCodigo, 'compra': compra});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertCompra sync: $e');
      return false;
    }
  }

  /// Ventas/POS - sync to backend
  static Future<Map<String, dynamic>?> registrarVenta({
    required Map<String, dynamic> venta,
    required String empresaCodigo,
  }) async {
    try {
      final result = await _postJson('/api/ventas', {'empresa_codigo': empresaCodigo, 'venta': venta});
      if (result is Map<String, dynamic>) return result;
    } catch (e) {
      debugPrint('❌ registrarVenta sync: $e');
    }
    return null;
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
      return result != null;
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
      empresaNombre: user['empresa_nombre']?.toString(),
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