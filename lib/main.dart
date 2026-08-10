import 'dart:io';
import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';
import 'package:portal_pilot_app/Shared/services/window_manager.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:portal_pilot_app/launch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalDatabaseService.instance.initialize();
  await SarService.instance.initialize();

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
            primaryColor: const Color(0xFF8B5CF6),
            scaffoldBackgroundColor: const Color(0xFF000000),
          ),
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF7C3AED),
            scaffoldBackgroundColor: const Color(0xFFF0F0F5),
          ),
          home: _windowRestored
              ? const SplashScreen()
              : const Scaffold(
                  backgroundColor: Color(0xFF000000),
                  body: Center(
                    child: Icon(
                      Icons.blur_on_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 40,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
