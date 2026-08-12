import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/auth_controller.dart';
import 'package:portal_pilot_app/Shared/services/multi_area_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:portal_pilot_app/Home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedTab = 'login';
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final NotificationManager _notificationManager = NotificationManager();

  // ═══ PALETA PREMIUM ═══
  static const Color bgPrimary = Color(0xFF000000);
  static const Color bgSecondary = Color(0xFF080808);
  static const Color bgTertiary = Color(0xFF0F0F0F);
  static const Color cardColor = Color(0xFF111111);

  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleDark = Color(0xFF6D28D9);
  static const Color accentPurpleLight = Color(0xFFA78BFA);
  static const Color accentPurpleDeep = Color(0xFF5B21B6);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA3A3A3);
  static const Color textDark = Color(0xFF525252);

  static const Color errorRed = Color(0xFFEF4444);

  static const Color borderLight = Color(0x29FFFFFF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _emailController.text = prefs.getString('saved_email') ?? '';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final Map<String, dynamic> response = await PortalPilotDB.login(
        email: email,
        password: password,
      );

      final Map<String, dynamic> userJson = response['user'] ?? {};
      final String token = response['token'] ?? '';

      final loggedUser = UserModel.fromBackendJson(userJson, token);

      if (!loggedUser.isActive) {
        throw Exception('Tu cuenta está pendiente de activación por el Owner.');
      }

      final String areaNegocio = _areaNegocioDesdeRespuesta(response, userJson);

      final area = (loggedUser.area ?? '').toLowerCase();
      String modulos = 'educacion';

      if (area == 'educacion' || area == 'educación') {
        modulos = 'educacion,facturacion,inventario,contabilidad,rrhh,crm,pos,comercial,membresias';
      } else if (area == 'finanzas') {
        modulos = 'contabilidad,facturacion';
      } else if (area == 'salud') {
        modulos = 'facturacion,inventario';
      } else if (loggedUser.isRoot) {
        modulos = 'educacion,facturacion,inventario,contabilidad,rrhh,crm,pos,comercial,membresias';
      }

      await AuthController.instance.setSession(
        nombre: loggedUser.nombre ?? '',
        apellido: loggedUser.apellido ?? '',
        email: loggedUser.email,
        rol: loggedUser.rol,
        area: loggedUser.area ?? '',
        rango: loggedUser.rango ?? '',
        empresaCodigo: loggedUser.empresaCodigo,
        empresaNombre: loggedUser.empresaNombre ?? '',
        token: token,
        modulos: modulos.split(',').map((m) => m.trim()).toList(),
        empresaAreaNegocio: areaNegocio,
      );

      await MultiAreaConfig.instance.cargar(
        areaNegocio: areaNegocio,
        modulosAsignados: modulos.split(',').map((m) => m.trim()).toList(),
      );

      _notificationManager.showNotification(
        'Acceso concedido. Cargando Dashboard...',
        NotificationType.success,
      );

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    } catch (e) {
      _notificationManager.showNotification(
        e.toString().replaceAll('Exception:', '').trim(),
        NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Extrae empresa.area_negocio de la respuesta del backend (si existe).
  String _areaNegocioDesdeRespuesta(
    Map<String, dynamic> response,
    Map<String, dynamic> userJson,
  ) {
    final empresa = response['empresa'];
    if (empresa is Map<String, dynamic>) {
      final v = empresa['area_negocio'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    for (final key in ['area_negocio', 'empresa_area_negocio']) {
      final v = response[key] ?? userJson[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  Future<void> _handleRegister() async {
    _notificationManager.showNotification(
      'Redirigiendo al portal de registro...',
      NotificationType.info,
    );

    await Future.delayed(const Duration(milliseconds: 800));

    final uri = Uri.parse(String.fromEnvironment('WEB_DOMAIN', defaultValue: 'https://portalpilot-app.vercel.app') + '/login.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _notificationManager.showNotification(
        'No se pudo abrir el portal de registro',
        NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: bgPrimary,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.8,
                colors: [
                  accentPurple.withValues(alpha: 0.06),
                  accentPurpleDeep.withValues(alpha: 0.02),
                  bgPrimary,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 16,
            right: 16,
            child: NotificationStack(manager: _notificationManager),
          ),
          SafeArea(
            child: isDesktop
                ? _buildDesktopLayout(size)
                : _buildMobileLayout(size),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Size size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(flex: 11, child: _buildLeftPanel(constraints)),
            Expanded(flex: 9, child: _buildRightPanel(constraints)),
          ],
        );
      },
    );
  }

  Widget _buildLeftPanel(BoxConstraints constraints) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.2, 0.0),
          radius: 1.4,
          colors: [
            accentPurpleDeep.withValues(alpha: 0.25),
            accentPurpleDark.withValues(alpha: 0.08),
            bgPrimary,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBrandLogo(),
                const SizedBox(height: 40),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Get Started\nwith Portal Pilot',
                    style: GoogleFonts.syne(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu portal corporativo inteligente con IA integrada para gestión financiera autónoma.',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                _buildStepTile(1, 'Crea tu empresa', true),
                const SizedBox(height: 14),
                _buildStepTile(2, 'Accede a tu dashboard', false),
                const SizedBox(height: 14),
                _buildStepTile(3, 'Gestiona con IA', false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(BoxConstraints constraints) {
    return Container(
      color: bgPrimary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildAuthCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandLogo(),
              const SizedBox(height: 16),
              Text(
                'Portal Pilot',
                style: GoogleFonts.syne(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 28),
              _buildAuthCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrandLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accentPurple, accentPurpleDark],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accentPurple.withValues(
                  alpha: 0.5 * _pulseAnimation.value,
                ),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.blur_on_rounded,
            color: textPrimary,
            size: 26,
          ),
        );
      },
    );
  }

  Widget _buildStepTile(int step, String label, bool active) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentPurple.withValues(alpha: 0.18),
                  accentPurpleDark.withValues(alpha: 0.08),
                ],
              )
            : null,
        color: active ? null : bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? accentPurple.withValues(alpha: 0.4) : borderLight,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accentPurple.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          if (active)
            Container(
              width: 3.5,
              height: 22,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accentPurple, accentPurpleDark],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: accentPurple.withValues(alpha: 0.7),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentPurple, accentPurpleDark],
                    )
                  : null,
              color: active ? null : bgSecondary,
              border: Border.all(
                color: active ? Colors.transparent : borderLight,
              ),
            ),
            child: Center(
              child: active
                  ? const Icon(
                      Icons.check_rounded,
                      color: textPrimary,
                      size: 16,
                    )
                  : Text(
                      '$step',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? textPrimary : textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 60,
            offset: const Offset(0, 25),
          ),
          BoxShadow(
            color: accentPurple.withValues(alpha: 0.06),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabs(),
          const SizedBox(height: 28),
          if (_selectedTab == 'login')
            Flexible(child: _buildLoginForm())
          else
            Flexible(child: _buildRegisterForm()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('login', 'Iniciar Sesión')),
          const SizedBox(width: 4),
          Expanded(child: _buildTabButton('register', 'Crear Cuenta')),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentPurple, accentPurpleDark],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? textPrimary : textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            label: 'CORREO ELECTRÓNICO',
            hint: 'tu@empresa.com',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu correo';
              if (!v.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'CONTRASEÑA',
            hint: '••••••••',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            onFieldSubmitted: (_) => _handleLogin(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: textMuted,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: true,
                        onChanged: (_) {},
                        activeColor: accentPurple,
                        side: BorderSide(color: borderLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recordarme',
                      style:
                          GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _notificationManager.showNotification(
                    'Función de recuperación disponible',
                    NotificationType.info,
                  ),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: accentPurpleLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _buildPrimaryButton(
            label: 'Iniciar Sesión',
            icon: Icons.chevron_right_rounded,
            isLoading: _isLoading,
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgTertiary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderLight),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentPurple, accentPurpleDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentPurple.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: textPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Registro Empresarial',
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configura tu cuenta empresarial en nuestro portal externo con verificación corporativa.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Comenzar Registro',
          icon: Icons.open_in_new_rounded,
          onPressed: _handleRegister,
        ),
        const SizedBox(height: 14),
        Text(
          'Serás redirigido a portalpilot-app.vercel.app',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: textDark,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgTertiary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderLight),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textDark),
              prefixIcon: Icon(prefixIcon, color: textMuted, size: 18),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: GoogleFonts.dmSans(fontSize: 11, color: errorRed),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentPurple, accentPurpleDark],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accentPurple.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textPrimary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18, color: textPrimary),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SISTEMA DE NOTIFICACIONES ISLA DINÁMICA
// ═══════════════════════════════════════════════════════════

enum NotificationType { success, error, info, warning }

class NotificationModel {
  final int id;
  final String message;
  final NotificationType type;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  Color get color {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF10B981);
      case NotificationType.error:
        return const Color(0xFFEF4444);
      case NotificationType.warning:
        return const Color(0xFFF59E0B);
      case NotificationType.info:
        return const Color(0xFF007AFF);
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.error:
        return Icons.cancel_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }
}

class NotificationManager extends ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  final Map<int, Timer> _timers = {};

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  void showNotification(String message, NotificationType type) {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, notification);
    notifyListeners();

    _timers[notification.id] = Timer(
      const Duration(milliseconds: 4500),
      () => dismissNotification(notification.id),
    );

    if (_notifications.length > 5) {
      final toRemove = _notifications.last;
      _timers[toRemove.id]?.cancel();
      _timers.remove(toRemove.id);
      _notifications.removeLast();
      notifyListeners();
    }
  }

  void dismissNotification(int id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}

class NotificationStack extends StatefulWidget {
  final NotificationManager manager;

  const NotificationStack({super.key, required this.manager});

  @override
  State<NotificationStack> createState() => _NotificationStackState();
}

class _NotificationStackState extends State<NotificationStack> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.manager,
      builder: (context, child) {
        final notifications = widget.manager.notifications.take(5).toList();

        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: notifications.asMap().entries.map((entry) {
              return _buildNotification(entry.value, entry.key);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildNotification(NotificationModel notification, int index) {
    final isTop = index == 0;
    final scale = 1.0 - (index * 0.06);
    final opacity = 1.0 - (index * 0.15);
    final translateY = index * 8.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, translateY * animValue),
          child: Transform.scale(
            scale: scale * animValue + (1 - animValue) * 0.8,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: opacity,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => widget.manager.dismissNotification(notification.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111).withValues(alpha: 0.92),
                  border: Border.all(
                    color: isTop
                        ? notification.color.withValues(alpha: 0.4)
                        : const Color(0x29FFFFFF),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                    if (isTop)
                      BoxShadow(
                        color: notification.color.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: notification.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: notification.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            notification.icon,
                            color: notification.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            notification.message,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFFFFF),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: const Color(0xFF525252),
                        ),
                      ],
                    ),
                    if (isTop) ...[
                      const SizedBox(height: 10),
                      _NotificationProgressBar(
                        color: notification.color,
                        duration: const Duration(milliseconds: 4500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationProgressBar extends StatefulWidget {
  final Color color;
  final Duration duration;

  const _NotificationProgressBar({required this.color, required this.duration});

  @override
  State<_NotificationProgressBar> createState() =>
      _NotificationProgressBarState();
}

class _NotificationProgressBarState extends State<_NotificationProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * (1 - _controller.value),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color,
                        widget.color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
