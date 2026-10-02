import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo de verificación en dos pasos (2FA).
///
/// El backend responde HTTP 202 a `/api/login` cuando la cuenta exige un
/// segundo factor. Este diálogo recoge el código y lo valida con [onSubmit]:
/// si la validación lanza, el error se muestra dentro del diálogo para que el
/// usuario reintente sin volver a escribir correo y contraseña.
///
/// En modo inscripción ([enroll] = true) muestra el secreto TOTP y la URI
/// `otpauth://` para añadirlos a la app de autenticación, ya que no hay QR
/// generado en el cliente.
class TwoFactorDialog extends StatefulWidget {
  const TwoFactorDialog({
    super.key,
    required this.email,
    required this.onSubmit,
    this.enroll = false,
    this.secret = '',
    this.otpauthUri = '',
  });

  /// Cuenta que se está verificando (solo texto informativo).
  final String email;

  /// Valida el código y devuelve la sesión completa (`token` + `user`).
  /// Si lanza, el mensaje se muestra dentro del diálogo.
  final Future<Map<String, dynamic>> Function(String code) onSubmit;

  /// `true` = la cuenta aún no tiene 2FA y hay que inscribirlo.
  final bool enroll;

  /// Secreto Base32 generado por el backend (solo inscripción).
  final String secret;

  /// URI `otpauth://totp/...` equivalente al QR de la web (solo inscripción).
  final String otpauthUri;

  @override
  State<TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<TwoFactorDialog> {
  static const Color bgCard = Color(0xFF111111);
  static const Color bgTertiary = Color(0xFF0F0F0F);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleDark = Color(0xFF6D28D9);
  static const Color accentPurpleLight = Color(0xFFA78BFA);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFA3A3A3);
  static const Color textDark = Color(0xFF737373);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color borderLight = Color(0x29FFFFFF);

  /// 6 dígitos para el TOTP, 9 caracteres para un código de respaldo
  /// (`XXXX-XXXX`), que es lo más largo que acepta el backend.
  static const int _maxCodeLength = 9;

  final TextEditingController _codeController = TextEditingController();
  String? _error;
  bool _verifying = false;
  bool _secretCopiado = false;

  @override
  void initState() {
    super.initState();
    if (widget.enroll && widget.otpauthUri.isNotEmpty) {
      _copiarAlPortapapeles(widget.otpauthUri);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _copiarAlPortapapeles(String valor) async {
    await Clipboard.setData(ClipboardData(text: valor));
    if (!mounted) return;
    setState(() => _secretCopiado = true);
  }

  /// Limpia el mensaje que el backend devuelve envuelto en `Exception` y le
  /// quita el sufijo técnico `(Código 401)`: aquí solo importa el motivo.
  String _mensajeDe(Object error) => error
      .toString()
      .replaceAll('Exception:', '')
      .replaceAll(RegExp(r'\s*\(Código \d+\)'), '')
      .trim();

  Future<void> _enviar() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Ingresa tu código de verificación');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final sesion = await widget.onSubmit(code);
      if (mounted) Navigator.of(context).pop(sesion);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = _mensajeDe(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderLight),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEncabezado(),
                const SizedBox(height: 24),
                if (widget.enroll) ...[
                  _buildSecreto(),
                  const SizedBox(height: 20),
                ],
                _buildCampoCodigo(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _buildError(),
                ],
                const SizedBox(height: 22),
                _buildAcciones(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accentPurple.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentPurple.withValues(alpha: 0.35)),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: accentPurpleLight,
            size: 26,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.enroll
              ? 'Activa la verificación en dos pasos'
              : 'Verificación en dos pasos',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.enroll
              ? 'Tu cuenta requiere 2FA antes de entrar. Añade el secreto a tu '
                  'app de autenticación y confirma con el código que genere.'
              : 'Ingresa el código de 6 dígitos de tu app de autenticación o un '
                  'código de respaldo para ${widget.email}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSecreto() {
    final valorParaCopiar =
        widget.otpauthUri.isNotEmpty ? widget.otpauthUri : widget.secret;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECRETO DE VERIFICACIÓN',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: textDark,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            valorParaCopiar,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _secretCopiado
                      ? 'Copiado al portapapeles'
                      : 'Pega esta clave en tu app de autenticación.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _secretCopiado ? successGreen : textDark,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () => _copiarAlPortapapeles(valorParaCopiar),
                icon: Icon(
                  _secretCopiado
                      ? Icons.check_rounded
                      : Icons.copy_rounded,
                  size: 15,
                  color: accentPurpleLight,
                ),
                label: const Text(
                  'Copiar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentPurpleLight,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: accentPurpleLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CÓDIGO DE VERIFICACIÓN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgTertiary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _error != null ? errorRed : borderLight,
            ),
          ),
          child: TextField(
            controller: _codeController,
            autofocus: true,
            enabled: !_verifying,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            maxLength: _maxCodeLength,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              UpperCaseTextFormatter(),
            ],
            onSubmitted: (_) => _enviar(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF525252),
                letterSpacing: 8,
              ),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: errorRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: errorRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: errorRed,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed:
                _verifying ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: textMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: borderLight),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentPurple, accentPurpleDark],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accentPurple.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _verifying ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          textPrimary,
                        ),
                      ),
                    )
                  : const Text(
                      'Verificar código',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fuerza el texto a mayúsculas: los códigos de respaldo se validan
/// hasheados en mayúsculas y así no hace falta recordárselo al usuario.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Controla el avance real de cada paso de la carga de acceso.
/// `completed` = cantidad de pasos terminados (0..4). Con 4, todo listo.
class LoadingStepsController extends ChangeNotifier {
  int _completed = 0;
  int get completed => _completed;

  void completeStep() {
    if (_completed < 4) {
      _completed++;
      notifyListeners();
    }
  }

  void reset() {
    _completed = 0;
    notifyListeners();
  }
}

/// Pantalla de carga al acceder al Home.
///
/// Diseño limpio y opaco, con progreso real guiado por [controller]:
/// sin bordes, sin capas translúcidas detrás del texto y sin estilos
/// extremos, para evitar artefactos de renderizado.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.controller});

  final LoadingStepsController controller;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoPulse;

  static const _steps = [
    'Verificando credenciales',
    'Conectando con tu servidor',
    'Preparando tu dashboard',
    'Abriendo tus módulos',
  ];

  @override
  void initState() {
    super.initState();
    _logoPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    widget.controller.addListener(_onProgress);
  }

  @override
  void dispose() {
    _logoPulse.dispose();
    widget.controller.removeListener(_onProgress);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.controller.completed;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF070709),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo opaco con degradado tenue de la marca
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF151022), Color(0xFF070709), Color(0xFF050507)],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                          CurvedAnimation(
                            parent: _logoPulse,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Image.asset(
                          'assets/img/robot_logo.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.blur_on_rounded,
                                  color: Colors.white, size: 64),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Iniciando sesión',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Conectando con tu espacio de trabajo…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9CA3AF),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: completed / 4,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) =>
                                LinearProgressIndicator(
                              value: value,
                              minHeight: 3,
                              backgroundColor: const Color(0xFF22222B),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFA78BFA)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: List.generate(_steps.length, (i) {
                          return _buildStep(i, completed, _steps[i]);
                        }),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Portal Pilot  •  IA integrada',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                          letterSpacing: 1.0,
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
    );
  }

  Widget _buildStep(int index, int completed, String label) {
    final isDone = index < completed;
    final isActive = index == completed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_circle_rounded,
                      size: 18, color: Colors.white)
                  : isActive
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                          ),
                        )
                      : const Icon(Icons.circle,
                          size: 8, color: Color(0xFF3F3F46)),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color:
                  isDone || isActive ? Colors.white : const Color(0xFF70707A),
              height: 1.3,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}