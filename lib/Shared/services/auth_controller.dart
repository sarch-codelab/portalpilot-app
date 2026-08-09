// lib/Shared/services/auth_controller.dart
// Controlador de sesión central. Fuente única de verdad del usuario autenticado.
// Reemplaza la lectura dispersa de SharedPreferences por una única fuente
// dinámica (ChangeNotifier) que actualiza todas las pantallas suscritas.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends ChangeNotifier {
  AuthController._privateConstructor();

  static final AuthController instance = AuthController._privateConstructor();

  String _nombre = '';
  String _apellido = '';
  String _email = '';
  String _rol = '';
  String _area = '';
  String _rango = '';
  String _empresaCodigo = 'ROOT';
  String _empresaNombre = '';
  String _token = '';
  List<String> _modulos = const [];
  bool _isLoggedIn = false;

  String get nombre => _nombre;
  String get apellido => _apellido;
  String get email => _email;
  String get rol => _rol;
  String get area => _area;
  String get rango => _rango;
  String get empresaCodigo => _empresaCodigo;
  String get empresaNombre => _empresaNombre;
  String get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  List<String> get modulos => _modulos;

  String get nombreCompleto {
    final n = _nombre.trim();
    final a = _apellido.trim();
    if (n.isEmpty) return 'Usuario';
    return a.isEmpty ? n : '$n $a';
  }

  bool get esRoot =>
      _empresaCodigo.toUpperCase() == 'ROOT' ||
      _rol.toLowerCase().contains('root') ||
      _rol.toLowerCase().contains('admin');

  /// Carga la sesión persistida desde SharedPreferences (arranque de la app).
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _nombre = prefs.getString('user_nombre') ?? '';
    _apellido = prefs.getString('user_apellido') ?? '';
    _email = prefs.getString('user_email') ?? '';
    _rol = prefs.getString('user_role') ?? 'profesor';
    _area = prefs.getString('user_area') ?? '';
    _rango = prefs.getString('user_rango') ?? '';
    _empresaCodigo = prefs.getString('company_code') ?? 'ROOT';
    _empresaNombre = prefs.getString('empresa_nombre') ?? '';
    _token = prefs.getString('auth_token') ?? '';
    final modulosRaw = prefs.getString('user_modulos') ?? '';
    _modulos = modulosRaw.isNotEmpty
        ? modulosRaw.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList()
        : const ['educacion'];
    _isLoggedIn = _token.isNotEmpty;
    notifyListeners();
  }

  /// Persiste la sesión (llamado tras un login exitoso).
  Future<void> setSession({
    required String nombre,
    required String apellido,
    required String email,
    required String rol,
    required String area,
    required String rango,
    required String empresaCodigo,
    required String empresaNombre,
    required String token,
    List<String>? modulos,
  }) async {
    _nombre = nombre;
    _apellido = apellido;
    _email = email;
    _rol = rol;
    _area = area;
    _rango = rango;
    _empresaCodigo = empresaCodigo.toUpperCase();
    _empresaNombre = empresaNombre;
    _token = token;
    _isLoggedIn = true;
    if (modulos != null) _modulos = modulos;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('user_email', email);
    await prefs.setString('user_role', rol);
    await prefs.setString('user_area', area);
    await prefs.setString('user_rango', rango);
    await prefs.setString('company_code', _empresaCodigo);
    await prefs.setString('user_nombre', nombre);
    await prefs.setString('user_apellido', apellido);
    await prefs.setString('empresa_nombre', empresaNombre);
    await prefs.setString('auth_token', token);
    await prefs.setString('user_modulos', _modulos.join(','));
    notifyListeners();
  }

  /// Actualiza el nombre/rol de la sesión en memoria y en disco (perfil).
  Future<void> updateProfile({String? nombre, String? apellido}) async {
    if (nombre != null) _nombre = nombre;
    if (apellido != null) _apellido = apellido;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_nombre', _nombre);
    await prefs.setString('user_apellido', _apellido);
    notifyListeners();
  }

  /// Cierra la sesión limpiando todas las claves de usuario.
  Future<void> logout() async {
    _nombre = '';
    _apellido = '';
    _email = '';
    _rol = '';
    _area = '';
    _rango = '';
    _empresaCodigo = 'ROOT';
    _empresaNombre = '';
    _token = '';
    _modulos = const [];
    _isLoggedIn = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_area');
    await prefs.remove('user_rango');
    await prefs.remove('company_code');
    await prefs.remove('user_nombre');
    await prefs.remove('user_apellido');
    await prefs.remove('empresa_nombre');
    await prefs.remove('auth_token');
    await prefs.remove('user_modulos');
    notifyListeners();
  }
}
