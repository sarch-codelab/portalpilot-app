import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PortalPilotDB {
  static const String apiRoot = 'https://portal-pilot.vercel.app';
  static const Duration _timeout = Duration(seconds: 15);
  static SupabaseClient? _supabaseClient;


  // ═══════════════════════════════════════════════════════════
  // 🖥️ BASE DE DATOS GLOBALES DE TODAS LAS AREAS
  // ═══════════════════════════════════════════════════════════


  // ═══════════════════════════════════════════════════════════
  // 🔑 CREDENCIALES DE SUPABASE - REEMPLAZA CON LAS TUYAS
  // ═══════════════════════════════════════════════════════════
  static const String _supabaseUrl = 'https://ugadesptdtbrzczxjtdx.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVnYWRlc3B0ZHRicnpjenhqdGR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzNDkzNzUsImV4cCI6MjA5ODkyNTM3NX0.Ln4AcpXu5onUvkQ1x0yKJ0FMPkjqaJmcjy1nXDlu-oc'; 
  // ═══════════════════════════════════════════════════════════

  /// Inicializa Supabase usando credenciales hardcodeadas.
  static Future<void> initialize() async {
    if (_supabaseClient != null) return;

    try {
      debugPrint('🔄 Iniciando conexión con Supabase...');
      debugPrint('📡 URL: $_supabaseUrl');
      
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      
      _supabaseClient = Supabase.instance.client;
      debugPrint('✅ Supabase inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error al inicializar Supabase: $e');
      rethrow;
    }
  }

  /// Retorna el cliente de Supabase, inicializándolo si es necesario.
  static Future<SupabaseClient> get supabaseAsync async {
    if (_supabaseClient == null) {
      debugPrint('⚠️ Supabase no inicializado, inicializando automáticamente...');
      await initialize();
    }
    if (_supabaseClient == null) {
      throw Exception('No se pudo inicializar Supabase.');
    }
    return _supabaseClient!;
  }

  /// Retorna el cliente de Supabase (síncrono).
  static SupabaseClient get supabase {
    if (_supabaseClient == null) {
      throw Exception('Supabase no inicializado. Llama a initialize() primero.');
    }
    return _supabaseClient!;
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
    final client = await supabaseAsync;
    
    final data = {
      // IDENTIFICADORES
      'folio_matricula': folioMatricula,
      'empresa_codigo': empresaCodigo,
      
      // DETALLES DE INSCRIPCIÓN
      'ciclo_escolar': cicloEscolar,
      'nivel_educativo': nivelEducativo,
      'grado': grado,
      'seccion': seccion,
      'turno': turno,
      'tipo_ingreso': tipoIngreso,
      'estado': estado,
      
      // DATOS DEL ALUMNO
      'alumno_nombre': alumnoNombre,
      'alumno_apellido': alumnoApellido,
      'alumno_dni': alumnoDni,
      'alumno_fecha_nacimiento': alumnoFechaNacimiento,
      'alumno_lugar_nacimiento': alumnoLugarNacimiento,
      'alumno_nacionalidad': alumnoNacionalidad,
      
      // SALUD
      'observaciones_salud': observacionesSalud,
      
      // TUTOR
      'tutor_parentesco': tutorParentesco,
      'tutor_nombre': tutorNombre,
      'tutor_telefono': tutorTelefono,
      'tutor_email': tutorEmail,
      
      // DIRECCIÓN
      'direccion_calle': direccionCalle,
      'direccion_municipio': direccionMunicipio,
      'direccion_departamento': direccionDepartamento,
      'direccion_referencia': direccionReferencia,
      'direccion_cp': direccionCP,
      
      // CONTROL FINANCIERO
      'pago_inscripcion_realizado': pagoInscripcionRealizado,
      'metodo_pago': metodoPago,
      'plan_pagos': planPagos,
    };

    debugPrint('📤 Insertando matrícula con folio: $folioMatricula');
    await client.from('matriculas').insert(data);
    debugPrint('✅ Matrícula insertada correctamente en Supabase');
  } on PostgrestException catch (e) {
    debugPrint('❌ Error de Supabase: ${e.message}');
    throw Exception('Error de Supabase: ${e.message}');
  } catch (e) {
    debugPrint('❌ Error inesperado: $e');
    throw Exception('Error al guardar matrícula: $e');
  }
}


  /// Obtiene todas las matrículas de una empresa específica
  /// Obtiene todas las matrículas de una empresa específica
static Future<List<Map<String, dynamic>>> getMatriculasByEmpresa(String empresaCodigo) async {
  try {
    final client = await supabaseAsync;
    
    final response = await client
        .from('matriculas')
        .select()
        .eq('empresa_codigo', empresaCodigo)
        .order('created_at', ascending: false)
        .limit(50); // Limitar a 50 registros más recientes
    
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    debugPrint('❌ Error al obtener matrículas: $e');
    return [];
  }
}

  /// Obtiene estadísticas resumidas de matrículas por empresa
  static Future<Map<String, dynamic>> getEstadisticasMatriculas(String empresaCodigo) async {
    try {
      final client = await supabaseAsync;
      
      final response = await client
          .from('matriculas')
          .select()
          .eq('empresa_codigo', empresaCodigo);
      
      final matriculas = List<Map<String, dynamic>>.from(response);
      
      // Contar por estado
      final estados = <String, int>{};
      for (final m in matriculas) {
        final estado = m['estado'] ?? 'desconocido';
        estados[estado] = (estados[estado] ?? 0) + 1;
      }
      
      // Contar por nivel
      final niveles = <String, int>{};
      for (final m in matriculas) {
        final nivel = m['nivel_educativo'] ?? 'desconocido';
        niveles[nivel] = (niveles[nivel] ?? 0) + 1;
      }
      
      // Contar por grado
      final grados = <String, int>{};
      for (final m in matriculas) {
        final grado = m['grado'] ?? 'desconocido';
        grados[grado] = (grados[grado] ?? 0) + 1;
      }
      
      return {
        'total': matriculas.length,
        'por_estado': estados,
        'por_nivel': niveles,
        'por_grado': grados,
        'ultima_actualizacion': matriculas.isNotEmpty ? matriculas.first['created_at'] : null,
      };
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