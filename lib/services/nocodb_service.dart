import 'dart:convert';
import 'package:http/http.dart' as http;

class NocoDBService {
  // ============================================================
  // 🔧 CONFIGURACIÓN - CORREGIDA
  // ============================================================
  static const String baseUrl =
      'https://app.nocodb.com'; // ← Solo el dominio, sin extras
  static const String apiToken =
      'nc_pat_zawRZGjBBt71tyamIeQP9G1lEnS3ZzO5Ggxtk_3T';
  static const String baseId = 'px82297mndrc9ur';
  static const String tableEmpresas = 'mk9n7ppeyujbn5y';
  static const String tableUsuarios = 'mbetwog5kom45mg';
  static const String tableTransacciones = 'mxa0iif8367hu3x';

  // Headers para autenticación
  Map<String, String> get _headers => {
        'xc-token': apiToken,
        'Content-Type': 'application/json',
      };

  // ============================================================
  // 📦 EMPRESAS (CRUD)
  // ============================================================

  /// Obtener todas las empresas
  Future<List<Map<String, dynamic>>> getEmpresas() async {
    try {
      final url = Uri.parse('$baseUrl/api/v2/tables/$tableEmpresas/records');
      print('📡 GET: $url'); // Para depuración
      final response = await http.get(url, headers: _headers);

      print('📥 Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['list']);
      } else {
        print('❌ Error body: ${response.body}');
        throw Exception('Error al obtener empresas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getEmpresas: $e');
      return [];
    }
  }

  /// Crear una nueva empresa
  Future<Map<String, dynamic>?> createEmpresa({
    required String nombre,
    required String codigo,
    required String plan,
  }) async {
    try {
      final body = {
        'nombre': nombre,
        'codigo': codigo.toUpperCase(),
        'plan': plan,
        'fecha_registro': DateTime.now().toIso8601String(),
        'estado': 'activo',
      };

      final url = Uri.parse('$baseUrl/api/v2/tables/$tableEmpresas/records');
      print('📡 POST: $url');
      print('📦 Body: $body');

      final response =
          await http.post(url, headers: _headers, body: jsonEncode(body));

      print('📥 Status: ${response.statusCode}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Empresa creada: $nombre');
        return jsonDecode(response.body);
      } else {
        print('❌ Error body: ${response.body}');
        throw Exception('Error al crear empresa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error createEmpresa: $e');
      return null;
    }
  }

  /// Obtener empresa por código
  Future<Map<String, dynamic>?> getEmpresaByCodigo(String codigo) async {
    final empresas = await getEmpresas();
    try {
      return empresas.firstWhere((e) => e['codigo'] == codigo.toUpperCase());
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // 👤 USUARIOS (CRUD)
  // ============================================================

  /// Obtener todos los usuarios
  Future<List<Map<String, dynamic>>> getUsuarios() async {
    try {
      final url = Uri.parse('$baseUrl/api/v2/tables/$tableUsuarios/records');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['list']);
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getUsuarios: $e');
      return [];
    }
  }

  /// Login de usuario (valida email, password y código de empresa)
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    required String empresaCodigo,
  }) async {
    try {
      // 1. Verificar que la empresa existe
      final empresa = await getEmpresaByCodigo(empresaCodigo);
      if (empresa == null) {
        return {'error': 'Empresa no encontrada', 'success': false};
      }

      // 2. Buscar usuario en esa empresa
      final usuarios = await getUsuarios();
      final usuario = usuarios.firstWhere(
        (u) => u['email'] == email && u['empresa_id'] == empresa['id'],
        orElse: () => {},
      );

      if (usuario.isEmpty) {
        return {'error': 'Usuario no encontrado', 'success': false};
      }

      // 3. Verificar contraseña
      if (usuario['password'] != password) {
        return {'error': 'Contraseña incorrecta', 'success': false};
      }

      return {
        'success': true,
        'usuario': usuario,
        'empresa': empresa,
      };
    } catch (e) {
      print('❌ Error login: $e');
      return {'error': 'Error de conexión', 'success': false};
    }
  }

  /// Crear un nuevo usuario
  Future<Map<String, dynamic>?> createUsuario({
    required String nombre,
    required String email,
    required String password,
    required String rol,
    required int empresaId,
  }) async {
    try {
      final body = {
        'nombre': nombre,
        'email': email,
        'password': password,
        'rol': rol,
        'empresa_id': empresaId,
        'activo': true,
      };

      final url = Uri.parse('$baseUrl/api/v2/tables/$tableUsuarios/records');
      final response =
          await http.post(url, headers: _headers, body: jsonEncode(body));

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Usuario creado: $email');
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al crear usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error createUsuario: $e');
      return null;
    }
  }

  // ============================================================
  // 💰 TRANSACCIONES (Auditoría Cyberyx)
  // ============================================================

  /// Crear una transacción de pago
  Future<Map<String, dynamic>?> createTransaccion({
    required int empresaId,
    required double monto,
    required String plan,
    required String hashTransaccion,
  }) async {
    try {
      final body = {
        'empresa_id': empresaId,
        'monto': monto,
        'plan': plan,
        'hash_transaccion': hashTransaccion,
        'fecha_pago': DateTime.now().toIso8601String(),
        'estado': 'completado',
      };

      final url =
          Uri.parse('$baseUrl/api/v2/tables/$tableTransacciones/records');
      final response =
          await http.post(url, headers: _headers, body: jsonEncode(body));

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(
            '✅ Transacción registrada: ${hashTransaccion.substring(0, 10)}...');
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al crear transacción: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error createTransaccion: $e');
      return null;
    }
  }

  /// Obtener transacciones de una empresa
  Future<List<Map<String, dynamic>>> getTransaccionesByEmpresa(
      int empresaId) async {
    try {
      final todas = await getTransacciones();
      return todas.where((t) => t['empresa_id'] == empresaId).toList();
    } catch (e) {
      print('❌ Error getTransaccionesByEmpresa: $e');
      return [];
    }
  }

  /// Obtener todas las transacciones
  Future<List<Map<String, dynamic>>> getTransacciones() async {
    try {
      final url =
          Uri.parse('$baseUrl/api/v2/tables/$tableTransacciones/records');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['list']);
      } else {
        throw Exception(
            'Error al obtener transacciones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getTransacciones: $e');
      return [];
    }
  }

  // ============================================================
  // 🔐 AUDITORÍA CYBERYX
  // ============================================================

  static String generateHash(String data) {
    return '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
  }

  Future<bool> verifyChainIntegrity() async {
    final transacciones = await getTransacciones();
    if (transacciones.isEmpty) return true;

    String? previousHash;
    for (var tx in transacciones) {
      final currentHash = tx['hash_transaccion'];
      if (previousHash != null && previousHash != tx['hash_anterior']) {
        print('⚠️ CADENA ROTA detectada');
        return false;
      }
      previousHash = currentHash;
    }
    print('✅ Cadena de auditoría intacta');
    return true;
  }
}
