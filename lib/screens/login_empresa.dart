import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main_navigator.dart';
import '../services/nocodb_service.dart';

class LoginEmpresaScreen extends StatefulWidget {
  const LoginEmpresaScreen({super.key});

  @override
  State<LoginEmpresaScreen> createState() => _LoginEmpresaScreenState();
}

class _LoginEmpresaScreenState extends State<LoginEmpresaScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyCodeController = TextEditingController();
  final NocoDBService _nocodb = NocoDBService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Datos demo para pruebas (reemplazar con datos reales de NocoDB)
    _companyCodeController.text = 'TECH01';
    _emailController.text = 'admin@techsolutions.com';
    _passwordController.text = 'Tech123!';
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _companyCodeController.text.isEmpty) {
      setState(() => _errorMessage = 'Completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 🔐 Autenticación real contra NocoDB
      final result = await _nocodb.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        empresaCodigo: _companyCodeController.text.trim().toUpperCase(),
      );

      setState(() => _isLoading = false);

      if (result != null && result['success'] == true) {
        // Guardar sesión en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario', jsonEncode(result['usuario']));
        await prefs.setString('empresa', jsonEncode(result['empresa']));
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const MainNavigator(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } else {
        setState(() => _errorMessage = result?['error'] ?? 'Credenciales inválidas');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: Verifica tu internet';
      });
      print('❌ Error login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final containerWidth = isMobile ? double.infinity : 420.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF0A0E17), Color(0xFF0F1118), Color(0xFF05080F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white54),
                    ),
                  ),
                  FadeInDown(
                    child: Container(
                      width: isMobile ? 60 : 80,
                      height: isMobile ? 60 : 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.business_center,
                            size: 35, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInDown(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      isMobile ? 'Acceso Empresa' : 'Acceso Corporativo',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Ingresa con el código de tu empresa',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 11 : 13,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      width: containerWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 20 : 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACCESO A TU EMPRESA',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cada empresa tiene un código único',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.white54),
                            ),
                            const SizedBox(height: 32),
                            _buildTextField(
                              controller: _companyCodeController,
                              label: 'CÓDIGO DE EMPRESA',
                              hint: 'Ej: TECH01',
                              icon: Icons.qr_code,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _emailController,
                              label: 'CORREO ELECTRÓNICO',
                              hint: 'tu@empresa.com',
                              icon: Icons.email_outlined,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'CONTRASEÑA',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFEF4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 16, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_errorMessage,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFEF4444))),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('INGRESAR',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                '¿No tienes código? Contrata un plan en PortalPilot',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                      ),
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
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white54)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E17),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
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