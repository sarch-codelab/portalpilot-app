// lib/Shared/services/auth_controller.dart
// Controlador de sesión central. Fuente única de verdad del usuario autenticado.
// Reemplaza la lectura dispersa de SharedPreferences por una única fuente
// dinámica (ChangeNotifier) que actualiza todas las pantallas suscritas.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portal_pilot_app/Shared/utils/logger.dart';

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
  String _empresaAreaNegocio = '';
  String _empresaPlan = 'Prueba';
  String _token = '';
  List<String> _modulos = const [];
  List<String> _features = const [];
  bool _soloLectura = false;
  bool _isLoggedIn = false;

  String get nombre => _nombre;
  String get apellido => _apellido;
  String get email => _email;
  String get rol => _rol;
  String get area => _area;
  String get rango => _rango;
  String get empresaCodigo => _empresaCodigo;
  String get empresaNombre => _empresaNombre;
  String get empresaAreaNegocio => _empresaAreaNegocio;
  String get empresaPlan => _empresaPlan;
  String get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  List<String> get modulos => _modulos;
  List<String> get features => _features;

  /// Verdadero cuando el trial de 15 días venció sin pago: la empresa puede
  /// consultar y exportar datos, pero no registrar movimientos nuevos.
  bool get soloLectura => _soloLectura;

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

  /// Devuelve `true` si el tenant tiene la feature indicada en su plan.
  /// ROOT siempre tiene acceso a todo.
  bool tieneFeature(String feature) {
    if (esRoot) return true;
    if (_features.isEmpty) return true; // sesión antigua sin features cargadas → no bloquear
    return _features.contains(feature);
  }

  /// Carga la sesión persistida desde SharedPreferences (arranque de la app).
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _nombre = prefs.getString('user_nombre') ?? '';
    _apellido = prefs.getString('user_apellido') ?? '';
    _email = prefs.getString('user_email') ?? '';
    _rol = prefs.getString('user_role') ?? 'admin';
    _area = prefs.getString('user_area') ?? '';
    _rango = prefs.getString('user_rango') ?? '';
    _empresaCodigo = prefs.getString('company_code') ?? 'ROOT';
    _empresaNombre = prefs.getString('empresa_nombre') ?? '';
    _empresaAreaNegocio = prefs.getString('empresa_area_negocio') ?? '';
    _empresaPlan = normalizarPlan(prefs.getString('empresa_plan') ?? '');
    _token = prefs.getString('auth_token') ?? '';
    final modulosRaw = prefs.getString('user_modulos') ?? '';
    _modulos = modulosRaw.isNotEmpty
        ? modulosRaw
              .split(',')
              .map((m) => m.trim())
              .where((m) => m.isNotEmpty)
              .toList()
        : const ['facturacion', 'inventario', 'contabilidad', 'rrhh', 'crm', 'pos', 'comercial', 'membresias'];
    final featuresRaw = prefs.getString('empresa_features') ?? '';
    _features = featuresRaw.isNotEmpty
        ? featuresRaw
              .split(',')
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty)
              .toList()
        : const [];
    _soloLectura = prefs.getBool('empresa_solo_lectura') ?? false;
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
    List<String>? features,
    bool? soloLectura,
    String? empresaAreaNegocio,
    String? empresaPlan,
  }) async {
    _nombre = nombre;
    _apellido = apellido;
    _email = email;
    _rol = rol;
    _area = area;
    _rango = rango;
    _empresaCodigo = empresaCodigo.toUpperCase();
    _empresaNombre = empresaNombre;
    _empresaAreaNegocio = (empresaAreaNegocio ?? '').trim().toLowerCase();
    _empresaPlan = normalizarPlan(empresaPlan ?? '');
    _token = token;
    _isLoggedIn = true;
    if (modulos != null) _modulos = modulos;
    if (features != null) _features = features;
    if (soloLectura != null) _soloLectura = soloLectura;

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
    await prefs.setString('empresa_area_negocio', _empresaAreaNegocio);
    await prefs.setString('empresa_plan', _empresaPlan);
    await prefs.setString('auth_token', token);
    await prefs.setString('user_modulos', _modulos.join(','));
    await prefs.setString('empresa_features', _features.join(','));
    await prefs.setBool('empresa_solo_lectura', _soloLectura);
    notifyListeners();
    Logger().audit(
      'login',
      'usuario',
      email,
      userId: email,
      module: 'auth',
      changes: {'empresa': _empresaCodigo, 'rol': _rol, 'plan': _empresaPlan},
    );
  }

  /// Normaliza el nombre del plan a uno de los planes conocidos
  /// (Prueba | Business | Enterprise). Desconocidos → Prueba.
  static String normalizarPlan(String plan) {
    final p = plan.trim().toLowerCase();
    if (p.contains('business') || p == 'business' || p == 'comercial') return 'Business';
    if (p.contains('enterprise') || p == 'enterprise' || p == 'empresa') return 'Enterprise';
    return 'Prueba';
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

  /// Actualiza el plan de la empresa en tiempo real (cambio de suscripción).
  Future<void> setPlan(String plan) async {
    _empresaPlan = normalizarPlan(plan);
    // Un plan pagado sale del modo solo lectura.
    if (_empresaPlan != 'Prueba' && _soloLectura) {
      await marcarSoloLectura(activo: false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('empresa_plan', _empresaPlan);
    notifyListeners();
  }

  /// Activa/desactiva el modo solo lectura (trial vencido) y lo persiste.
  Future<void> marcarSoloLectura({bool activo = true}) async {
    if (_soloLectura == activo) return;
    _soloLectura = activo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('empresa_solo_lectura', activo);
    notifyListeners();
  }

  /// Cierra la sesión limpiando todas las claves de usuario.
  Future<void> logout() async {
    final email = _email;
    _nombre = '';
    _apellido = '';
    _email = '';
    _rol = '';
    _area = '';
    _rango = '';
    _empresaCodigo = 'ROOT';
    _empresaNombre = '';
    _empresaAreaNegocio = '';
    _empresaPlan = 'Prueba';
    _token = '';
    _modulos = const [];
    _features = const [];
    _soloLectura = false;
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
    await prefs.remove('empresa_area_negocio');
    await prefs.remove('empresa_plan');
    await prefs.remove('auth_token');
    await prefs.remove('user_modulos');
    await prefs.remove('empresa_features');
    await prefs.remove('empresa_solo_lectura');
    notifyListeners();
    Logger().audit(
      'logout',
      'usuario',
      email,
      userId: email,
      module: 'auth',
    );
  }
}
