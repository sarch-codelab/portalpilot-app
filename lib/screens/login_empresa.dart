import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_navigator.dart';
import '../services/nocodb_service.dart';

class LoginEmpresaScreen extends StatefulWidget {
  const LoginEmpresaScreen({super.key});

  @override
  State<LoginEmpresaScreen> createState() => _LoginEmpresaScreenState();
}

class _LoginEmpresaScreenState extends State<LoginEmpresaScreen> {
  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final NocoDBService _nocodb = NocoDBService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  bool _rememberCompany = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCompany = prefs.getString('saved_company_code');
    if (savedCompany != null && savedCompany.isNotEmpty) {
      setState(() {
        _companyCodeController.text = savedCompany;
        _rememberCompany = true;
      });
    }
  }

  Future<void> _saveCompanyCode(String code) async {
    if (_rememberCompany && code.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_company_code', code);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_company_code');
    }
  }

  Future<void> _login() async {
    final companyCode = _companyCodeController.text.trim().toUpperCase();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (companyCode.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _nocodb.login(
        email: email,
        password: password,
        empresaCodigo: companyCode,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result != null && result['success'] == true) {
          // Guardar sesión
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'userName', result['usuario']['nombre'] ?? 'Usuario');
          await prefs.setString('userEmail', result['usuario']['email'] ?? '');
          await prefs.setString(
              'userRole', result['usuario']['rol'] ?? 'operator');
          await prefs.setString(
              'empresaNombre', result['empresa']['nombre'] ?? 'Mi Empresa');
          await prefs.setString(
              'empresaPlan', result['empresa']['plan'] ?? 'Pro');
          await prefs.setString('empresaCodigo', companyCode);
          await prefs.setBool('isLoggedIn', true);

          // Guardar código de empresa si está marcado
          await _saveCompanyCode(companyCode);

          // Navegar al MainNavigator
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigator()),
            );
          }
        } else {
          setState(() =>
              _errorMessage = result?['error'] ?? 'Credenciales inválidas');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error de conexión. Verifica tu internet.';
        });
      }
      print('Error de login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF0A0B0F),
              Color(0xFF030408),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.business_center,
                          size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Título
                  const Text(
                    "Acceso Corporativo",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Ingresa con el código de tu empresa",
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Formulario
                  Container(
                    width: isMobile ? double.infinity : 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        // Código de empresa
                        _buildTextField(
                          controller: _companyCodeController,
                          label: "CÓDIGO DE EMPRESA",
                          hint: "Ej: TECH01",
                          icon: Icons.qr_code,
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: 20),

                        // Email
                        _buildTextField(
                          controller: _emailController,
                          label: "CORREO ELECTRÓNICO",
                          hint: "admin@empresa.com",
                          icon: Icons.email_outlined,
                          color: const Color(0xFF8B5CF6),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Contraseña
                        _buildTextField(
                          controller: _passwordController,
                          label: "CONTRASEÑA",
                          hint: "••••••••",
                          icon: Icons.lock_outline,
                          color: const Color(0xFF8B5CF6),
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                              color: Colors.white54,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),

                        // Recordar empresa
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberCompany,
                              onChanged: (value) {
                                setState(
                                    () => _rememberCompany = value ?? false);
                              },
                              activeColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Colors.white38),
                            ),
                            const Text(
                              "Recordar código de empresa",
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Botón de login
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "INGRESAR",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Demo credentials
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                "📋 Credenciales de prueba",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Código: TECH01",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white54),
                              ),
                              Text(
                                "Email: admin@techsolutions.com",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white54),
                              ),
                              Text(
                                "Contraseña: Tech123!",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
              prefixIcon: Icon(icon, size: 20, color: Colors.white54),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}
