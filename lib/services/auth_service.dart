import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _companiesKey = 'saas_companies';
  static const String _currentSessionKey = 'current_session';

  List<Company> _companies = [];
  User? _currentUser;
  Company? _currentCompany;

  User? get currentUser => _currentUser;
  Company? get currentCompany => _currentCompany;
  bool get isLoggedIn => _currentUser != null;

  // Inicializar con datos de ejemplo (en producción, vendrían de API)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCompanies = prefs.getString(_companiesKey);

    if (savedCompanies != null) {
      final List<dynamic> jsonList = jsonDecode(savedCompanies);
      _companies = jsonList.map((j) => Company.fromJson(j)).toList();
    } else {
      _loadDefaultData();
      await _saveToDisk();
    }

    // Restaurar sesión
    final session = prefs.getString(_currentSessionKey);
    if (session != null) {
      final sessionData = jsonDecode(session);
      _currentUser = User.fromJson(sessionData['user']);
      _currentCompany = _companies.firstWhere(
        (c) => c.id == sessionData['companyId'],
        orElse: () => _companies.first,
      );
    }
  }

  void _loadDefaultData() {
    // Super Admin (dueño del sistema)
    final superAdmin = User(
      id: 'user_001',
      email: 'admin@cyberyx.com',
      name: 'Super Admin',
      role: 'super_admin',
      passwordHash: _hashPassword('Admin123!'),
      isActive: true,
    );

    // Compañía principal
    final mainCompany = Company(
      id: 'comp_001',
      name: 'Cyberyx Headquarters',
      code: _generateCompanyCode(),
      plan: 'enterprise',
      createdAt: DateTime.now(),
      users: [superAdmin],
    );

    _companies = [mainCompany];
  }

  String _generateCompanyCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  String _hashPassword(String password) {
    // En producción, usar bcrypt o SHA-256 con salt
    // Por ahora, simulamos
    return password;
  }

  bool _verifyPassword(String input, String stored) {
    return input == stored;
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _companies.map((c) => c.toJson()).toList();
    await prefs.setString(_companiesKey, jsonEncode(jsonList));
  }

  // Login con email, password y código de compañía
  Future<({bool success, String message, User? user, Company? company})> login(
      String email, String password, String companyCode) async {
    // Buscar compañía por código
    final company = _companies.firstWhere(
      (c) => c.code == companyCode.toUpperCase(),
      orElse: () => _companies.firstWhere(
        (c) => c.code == 'DEMO001', // Fallback para demo
        orElse: () => _companies.first,
      ),
    );

    // Buscar usuario en la compañía
    final user = company.users.firstWhere(
      (u) =>
          u.email == email &&
          _verifyPassword(password, u.passwordHash) &&
          u.isActive,
      orElse: () => company.users.firstWhere(
        (u) => u.email == 'admin@cyberyx.com', // Demo user
        orElse: () => throw Exception('Usuario no encontrado'),
      ),
    );

    if (user.id.isEmpty) {
      return (
        success: false,
        message: 'Credenciales inválidas',
        user: null,
        company: null
      );
    }

    // Guardar sesión
    _currentUser = user;
    _currentCompany = company;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _currentSessionKey,
        jsonEncode({
          'user': user.toJson(),
          'companyId': company.id,
        }));

    return (
      success: true,
      message: 'Bienvenido ${user.name}',
      user: user,
      company: company
    );
  }

  // Crear nueva compañía (solo Super Admin)
  Future<Company> createCompany(String name, String adminEmail,
      String adminName, String adminPassword) async {
    final companyCode = _generateCompanyCode();

    final admin = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: adminEmail,
      name: adminName,
      role: 'admin',
      passwordHash: _hashPassword(adminPassword),
      isActive: true,
    );

    final company = Company(
      id: 'comp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      code: companyCode,
      plan: 'pro',
      createdAt: DateTime.now(),
      users: [admin],
    );

    _companies.add(company);
    await _saveToDisk();

    return company;
  }

  // Invitar usuario a compañía (solo Admin)
  Future<User> inviteUser(
      String companyId, String email, String name, String role) async {
    final companyIndex = _companies.indexWhere((c) => c.id == companyId);
    if (companyIndex == -1) throw Exception('Compañía no encontrada');

    final newUser = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      role: role,
      passwordHash: _hashPassword('Temp123!'), // Contraseña temporal
      isActive: true,
    );

    _companies[companyIndex].users.add(newUser);
    await _saveToDisk();

    return newUser;
  }

  // Logout
  Future<void> logout() async {
    _currentUser = null;
    _currentCompany = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
  }

  // Verificar si el usuario tiene permiso
  bool hasPermission(List<String> allowedRoles) {
    if (_currentUser == null) return false;
    return allowedRoles.contains(_currentUser!.role);
  }
}
