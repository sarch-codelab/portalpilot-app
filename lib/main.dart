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

  await LocalDatabaseService.instance.initialize();
  await SarService.instance.initialize();
  await OrientationService.instance.initialize();
  await OfflineSyncService.instance.initialize();

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
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B5CF6),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF000000),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF080808),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF111111),
              surfaceTintColor: Colors.transparent,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFF111111),
              border: OutlineInputBorder(),
            ),
          ),
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6D28D9),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1F2937),
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          home: _windowRestored
              ? const SplashScreen()
              : Scaffold(
                  backgroundColor: const Color(0xFF000000),
                  body: Center(
                    child: Image.asset(
                      'assets/img/robot_logo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
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
                    backgroundColor: isDark ? const Color(0xFF080808) : Colors.white,
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
                            color: isDark ? Colors.white : const Color(0xFF18202B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'WORKSPACE',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
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
