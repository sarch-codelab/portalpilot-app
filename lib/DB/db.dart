import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PortalPilotDB {
  static const String apiRoot = 'https://portal-pilot.vercel.app';
  static const Duration _timeout = Duration(seconds: 15);
  static SupabaseClient? _supabaseClient;

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
  static Future<void> insertMatriculaCompleta({
    required String alumnoNombre,
    required String alumnoApellidoPaterno,
    required String alumnoApellidoMaterno,
    required String alumnoCurp,
    required String alumnoFechaNacimiento,
    required String alumnoLugarNacimiento,
    required String alumnoGenero,
    required String alumnoNacionalidad,
    required String alumnoTipoSangre,
    required String alumnoNss,
    required String alumnoAlergias,
    required String alumnoCondiciones,
    required String alumnoMedicamentos,
    required String alumnoPeso,
    required String alumnoEstatura,
    required String alumnoDiscapacidad,
    required String alumnoObsMedicas,
    required String tutorNombre,
    required String tutorParentesco,
    required String tutorTelefono,
    required String tutorEmail,
    required String tutorOcupacion,
    required String tutorCurp,
    required String direccionCalle,
    required String direccionColonia,
    required String direccionCP,
    required String direccionAlcaldia,
    required String direccionEstado,
    required String emergNombre,
    required String emergParentesco,
    required String emergTel1,
    required String emergTel2,
    required String emergDireccion,
    required String emergHorario,
    required String empresaCodigo,
    String estado = 'pendiente',
  }) async {
    try {
      final client = await supabaseAsync;
      
      String alumnoApellidoCompleto = '$alumnoApellidoPaterno $alumnoApellidoMaterno'.trim();
      if (alumnoApellidoCompleto.isEmpty) {
        alumnoApellidoCompleto = alumnoApellidoPaterno.isNotEmpty 
            ? alumnoApellidoPaterno 
            : 'Sin apellido';
      }
      
      String encargadoContacto = '';
      if (tutorEmail.isNotEmpty) {
        encargadoContacto = tutorEmail;
      } else if (tutorTelefono.isNotEmpty) {
        encargadoContacto = tutorTelefono;
      } else {
        encargadoContacto = 'No proporcionado';
      }
      
      final data = {
        'alumno_nombre': alumnoNombre.isNotEmpty ? alumnoNombre : 'Sin nombre',
        'alumno_apellido': alumnoApellidoCompleto,
        'nivel_educativo': 'Primaria',
        'encargado_contacto': encargadoContacto,
        'empresa_codigo': empresaCodigo.isNotEmpty ? empresaCodigo : 'ROOT',
        'alumno_apellido_paterno': alumnoApellidoPaterno,
        'alumno_apellido_materno': alumnoApellidoMaterno,
        'alumno_curp': alumnoCurp,
        'alumno_fecha_nacimiento': alumnoFechaNacimiento,
        'alumno_lugar_nacimiento': alumnoLugarNacimiento,
        'alumno_genero': alumnoGenero,
        'alumno_nacionalidad': alumnoNacionalidad,
        'alumno_tipo_sangre': alumnoTipoSangre,
        'alumno_nss': alumnoNss,
        'alumno_alergias': alumnoAlergias,
        'alumno_condiciones': alumnoCondiciones,
        'alumno_medicamentos': alumnoMedicamentos,
        'alumno_peso': alumnoPeso,
        'alumno_estatura': alumnoEstatura,
        'alumno_discapacidad': alumnoDiscapacidad,
        'alumno_obs_medicas': alumnoObsMedicas,
        'tutor_nombre': tutorNombre,
        'tutor_parentesco': tutorParentesco,
        'tutor_telefono': tutorTelefono,
        'tutor_email': tutorEmail,
        'tutor_ocupacion': tutorOcupacion,
        'tutor_curp': tutorCurp,
        'direccion_calle': direccionCalle,
        'direccion_colonia': direccionColonia,
        'direccion_cp': direccionCP,
        'direccion_alcaldia': direccionAlcaldia,
        'direccion_estado': direccionEstado,
        'emerg_nombre': emergNombre,
        'emerg_parentesco': emergParentesco,
        'emerg_tel1': emergTel1,
        'emerg_tel2': emergTel2,
        'emerg_direccion': emergDireccion,
        'emerg_horario': emergHorario,
        'estado': estado,
      };

      debugPrint('📤 Insertando matrícula en Supabase...');
      await client.from('matriculas').insert(data);
      debugPrint('✅ Matrícula insertada correctamente en Supabase');
    } on PostgrestException catch (e) {
      debugPrint('❌ Error de Supabase: ${e.message}');
      debugPrint('❌ Código: ${e.code}');
      debugPrint('❌ Detalles: ${e.details}');
      throw Exception('Error de Supabase: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      throw Exception('Error al guardar matrícula: $e');
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