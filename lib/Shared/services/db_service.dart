import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PortalPilotDB {
  static const String apiRoot = String.fromEnvironment(
    'API_ROOT',
    defaultValue: 'https://portalpilot-app.vercel.app',
  );
  static const Duration _timeout = Duration(seconds: 20);

  /// Inicializa la capa de backend para producción.
  static Future<void> initialize() async {
    debugPrint('🔄 Backend listo para producción mediante Vercel.');
  }

  /// Inserta una matrícula completa con todos los campos del formulario
  /// Inserta una matrícula completa con todos los campos del formulario actual
static Future<void> insertMatriculaCompleta({
  // IDENTIFICADOR INSTITUCIONAL
  required String folioMatricula,

  // DETALLES DE INSCRIPCIÓN
  required String cicloEscolar,
  required String nivelEducativo,
  required String grado,
  required String seccion,
  required String turno,
  required String tipoIngreso,

  // DATOS DEL ALUMNO
  required String alumnoNombre,
  required String alumnoApellido,
  required String alumnoDni,
  required String alumnoFechaNacimiento,
  required String alumnoLugarNacimiento,
  required String alumnoNacionalidad,

  // SALUD (SIMPLIFICADA)
  required String observacionesSalud,

  // TUTOR RESPONSABLE
  required String tutorParentesco,
  required String tutorNombre,
  required String tutorTelefono,
  required String tutorEmail,

  // DIRECCIÓN
  required String direccionCalle,
  required String direccionMunicipio,
  required String direccionDepartamento,
  required String direccionReferencia,
  required String direccionCP,

  // CONTROL FINANCIERO
  required bool pagoInscripcionRealizado,
  required String metodoPago,
  required String planPagos,

  // EMPRESA
  required String empresaCodigo,
  String estado = 'pendiente',
}) async {
  try {
    final data = {
      'folio_matricula': folioMatricula,
      'empresa_codigo': empresaCodigo,
      'ciclo_escolar': cicloEscolar,
      'nivel_educativo': nivelEducativo,
      'grado': grado,
      'seccion': seccion,
      'turno': turno,
      'tipo_ingreso': tipoIngreso,
      'estado': estado,
      'alumno_nombre': alumnoNombre,
      'alumno_apellido': alumnoApellido,
      'alumno_dni': alumnoDni,
      'alumno_fecha_nacimiento': alumnoFechaNacimiento,
      'alumno_lugar_nacimiento': alumnoLugarNacimiento,
      'alumno_nacionalidad': alumnoNacionalidad,
      'observaciones_salud': observacionesSalud,
      'tutor_parentesco': tutorParentesco,
      'tutor_nombre': tutorNombre,
      'tutor_telefono': tutorTelefono,
      'tutor_email': tutorEmail,
      'direccion_calle': direccionCalle,
      'direccion_municipio': direccionMunicipio,
      'direccion_departamento': direccionDepartamento,
      'direccion_referencia': direccionReferencia,
      'direccion_cp': direccionCP,
      'pago_inscripcion_realizado': pagoInscripcionRealizado,
      'metodo_pago': metodoPago,
      'plan_pagos': planPagos,
    };

    debugPrint('📤 Insertando matrícula con folio: $folioMatricula');
    final response = await http
        .post(
          Uri.parse('$apiRoot/api/matriculas'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(_timeout);

    if (response.statusCode >= 400) {
      throw Exception('Error del backend: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
    }

    debugPrint('✅ Matrícula insertada correctamente en Vercel');
  } catch (e) {
    debugPrint('❌ Error inesperado: $e');
    throw Exception('Error al guardar matrícula: $e');
  }
}


  /// Obtiene todas las matrículas de una empresa específica
  static Future<List<Map<String, dynamic>>> getMatriculasByEmpresa(String empresaCodigo) async {
    try {
      final uri = Uri.parse('$apiRoot/api/matriculas?empresaCodigo=$empresaCodigo');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Error del backend: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
      }

      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is List) {
        return List<Map<String, dynamic>>.from(payload.map((item) => Map<String, dynamic>.from(item)));
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error al obtener matrículas: $e');
      return [];
    }
  }

  /// Obtiene estadísticas resumidas de matrículas por empresa
  static Future<Map<String, dynamic>> getEstadisticasMatriculas(String empresaCodigo) async {
    try {
      final uri = Uri.parse('$apiRoot/api/matriculas/stats?empresaCodigo=$empresaCodigo');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Error del backend: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
      }

      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      return Map<String, dynamic>.from(payload);
    } catch (e) {
      debugPrint('❌ Error al obtener estadísticas: $e');
      throw Exception('Error al obtener estadísticas: $e');
    }
  }


  // ═══════════════════════════════════════════════════════════════
  // SYNC SUPABASE (vía serverless Vercel) — best-effort / offline-safe
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

  /// Facturas ─────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getFacturas(String empresaCodigo) async {
    try {
      final payload = await _getJson('/api/facturas', {'empresaCodigo': empresaCodigo});
      if (payload is List) {
        return List<Map<String, dynamic>>.from(payload.map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (e) {
      debugPrint('❌ getFacturas: $e');
    }
    return [];
  }

  static Future<bool> insertFactura({required Map<String, dynamic> factura, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/facturas', {'empresa_codigo': empresaCodigo, 'factura': factura});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertFactura: $e');
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
        debugPrint('⚠️ anularFactura -> ${response.statusCode}: ${utf8.decode(response.bodyBytes, allowMalformed: true)}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ anularFactura: $e');
      return false;
    }
  }

  /// Transacciones contables ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTransacciones(String empresaCodigo) async {
    try {
      final payload = await _getJson('/api/transacciones', {'empresaCodigo': empresaCodigo});
      if (payload is List) {
        return List<Map<String, dynamic>>.from(payload.map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (e) {
      debugPrint('❌ getTransacciones: $e');
    }
    return [];
  }

  static Future<bool> insertTransaccion({required Map<String, dynamic> transaccion, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/transacciones', {
        'empresa_codigo': empresaCodigo,
        'transaccion': transaccion,
      });
      return result != null;
    } catch (e) {
      debugPrint('❌ insertTransaccion: $e');
      return false;
    }
  }

  /// Clientes ─────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getClientes(String empresaCodigo) async {
    try {
      final payload = await _getJson('/api/clientes', {'empresaCodigo': empresaCodigo});
      if (payload is List) {
        return List<Map<String, dynamic>>.from(payload.map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (e) {
      debugPrint('❌ getClientes: $e');
    }
    return [];
  }

  static Future<bool> insertCliente({required Map<String, dynamic> cliente, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/clientes', {'empresa_codigo': empresaCodigo, 'cliente': cliente});
      return result != null;
    } catch (e) {
      debugPrint('❌ insertCliente: $e');
      return false;
    }
  }

  /// Productos / Inventario ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProductos(String empresaCodigo) async {
    try {
      final payload = await _getJson('/api/productos', {'empresaCodigo': empresaCodigo});
      if (payload is List) {
        return List<Map<String, dynamic>>.from(payload.map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (e) {
      debugPrint('❌ getProductos: $e');
    }
    return [];
  }

  static Future<bool> syncProductos({required List<Map<String, dynamic>> productos, required String empresaCodigo}) async {
    try {
      final result = await _postJson('/api/productos', {'empresa_codigo': empresaCodigo, 'productos': productos});
      return result != null;
    } catch (e) {
      debugPrint('❌ syncProductos: $e');
      return false;
    }
  }

  /// Cierre de venta POS (factura + descuento de stock) ───────────
  static Future<Map<String, dynamic>?> registrarVenta({
    required Map<String, dynamic> venta,
    required String empresaCodigo,
  }) async {
    try {
      final result = await _postJson('/api/ventas', {'empresa_codigo': empresaCodigo, 'venta': venta});
      if (result is Map<String, dynamic>) return result;
    } catch (e) {
      debugPrint('❌ registrarVenta: $e');
    }
    return null;
  }

  /// Notas (estado completo por clave periodo|grado|seccion|asignatura)
  static Future<Map<String, dynamic>?> getNotas(String empresaCodigo, String clave) async {
    try {
      final payload = await _getJson('/api/notas', {'empresaCodigo': empresaCodigo, 'clave': clave});
      if (payload is List && payload.isNotEmpty) {
        return Map<String, dynamic>.from(payload.first is Map ? payload.first as Map : {});
      }
    } catch (e) {
      debugPrint('❌ getNotas: $e');
    }
    return null;
  }

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
      debugPrint('❌ saveNotas: $e');
      return false;
    }
  }

  /// Login contra el backend Express (NocoDB). No usa Supabase.
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