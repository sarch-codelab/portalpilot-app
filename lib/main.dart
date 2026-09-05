import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';
import 'package:portal_pilot_app/Shared/services/window_manager.dart';
import 'package:portal_pilot_app/Shared/services/orientation_service.dart';
import 'package:portal_pilot_app/Shared/services/offline_sync_service.dart';
import 'package:portal_pilot_app/launch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Atrapar errores async no recuperados para evitar crashes en móvil.
  runZonedGuarded(() async {
    await _initApp();
  }, (error, stack) {
    debugPrint('🚨 Error no capturado: $error');
    debugPrint('Stack: $stack');
  });

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 Flutter error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };
}

Future<void> _initApp() async {
  await LocalDatabaseService.instance.initialize();
  await SarService.instance.initialize();

  try {
    await OrientationService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ OrientationService init error: $e');
  }

  try {
    await OfflineSyncService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ OfflineSyncService init error: $e');
  }

  try {
    await PortalPilotDB.initialize();
  } catch (e) {
    debugPrint('Error al inicializar backend: $e');
  }

  runApp(const PortalPilotApp());
}

class _WindowLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      AppWindowManager.instance.saveWindow();
    }
  }
}

class PortalPilotApp extends StatefulWidget {
  const PortalPilotApp({super.key});

  @override
  State<PortalPilotApp> createState() => _PortalPilotAppState();
}

class _PortalPilotAppState extends State<PortalPilotApp> {
  bool _windowRestored = false;

  @override
  void initState() {
    super.initState();
    _initWindow();
  }

  Future<void> _initWindow() async {
    if (Platform.isWindows) {
      await AppWindowManager.instance.initialize();
      await AppWindowManager.instance.restoreWindow();
      if (mounted) {
        setState(() => _windowRestored = true);
        WidgetsBinding.instance.addObserver(_WindowLifecycleObserver());
      }
    } else {
      if (mounted) setState(() => _windowRestored = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Portal Pilot',
          themeMode: themeMode,
          darkTheme: ThemePalette.buildTheme(isDark: true),
          theme: ThemePalette.buildTheme(isDark: false),
          home: _windowRestored
              ? const SplashScreen()
              : const Scaffold(
                  backgroundColor: Color(0xFF070510),
                  body: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: ColoredBox(
                        color: Color(0xFF070510),
                      ),
                    ),
                  ),
                ),
          builder: (context, child) {
            if (!Platform.isWindows || child == null) {
              return child ?? const SizedBox.shrink();
            }
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Column(
              children: [
                SizedBox(
                  height: 44,
                  child: WindowCaption(
                    backgroundColor: isDark ? const Color(0xFF0A0814) : Colors.white,
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    title: Row(
                      children: [
                        Image.asset(
                          'assets/img/robot_logo.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Portal Pilot',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFF5F2FF)
                                : const Color(0xFF1E1B2A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB94DDC).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'WORKSPACE',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFD16BF0) : const Color(0xFF8B2FB0),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            );
          },
        );
      },
    );
  }
}