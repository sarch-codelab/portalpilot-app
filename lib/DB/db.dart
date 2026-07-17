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
      throw Exception('Error del backend: ${response.body}');
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
        throw Exception('Error del backend: ${response.body}');
      }

      final payload = jsonDecode(response.body);
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
        throw Exception('Error del backend: ${response.body}');
      }

      final payload = jsonDecode(response.body);
      return Map<String, dynamic>.from(payload);
    } catch (e) {
      debugPrint('❌ Error al obtener estadísticas: $e');
      throw Exception('Error al obtener estadísticas: $e');
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

    final Map<String, dynamic> data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Error al iniciar sesión.');
    }
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