import 'package:flutter/material.dart';

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