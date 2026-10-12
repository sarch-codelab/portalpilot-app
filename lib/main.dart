import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:portal_pilot_app/Shared/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:portal_pilot_app/Shared/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:portal_pilot_app/Shared/services/db_service.dart';
import 'package:portal_pilot_app/Shared/services/local_db_service.dart';
import 'package:portal_pilot_app/Shared/services/sar_service.dart';
import 'package:portal_pilot_app/Shared/services/window_manager.dart';
import 'package:portal_pilot_app/Shared/services/orientation_service.dart';
import 'package:portal_pilot_app/Shared/services/offline_sync_service.dart';
import 'package:portal_pilot_app/Shared/services/sync_service.dart'
    as durable_sync;
import 'package:portal_pilot_app/Shared/services/session_guard.dart';
import 'package:portal_pilot_app/Shared/services/app_update_service.dart';
import 'package:portal_pilot_app/Shared/services/fcm_update_service.dart';
import 'package:portal_pilot_app/Shared/utils/json_guard.dart';
import 'package:portal_pilot_app/Shared/utils/local_paths.dart';
import 'package:portal_pilot_app/Shared/widgets/pp_notifications.dart';
import 'package:portal_pilot_app/launch_screen.dart';

void main() {
  // TODO el arranque (ensureInitialized incluido) corre en la MISMA zona
  // capturadora: mezclar zonas entre ensureInitialized y runApp dispara el
  // assertion "Zone mismatch" del framework.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Sandbox/entornos con escritura restringida: redirige Documents,
      // AppData y Temp a una carpeta local si PORTAL_PILOT_DATA_DIR está
      // definida. No hace nada en producción.
      configureLocalPaths();

      // Aviso global al usuario cuando se detectan datos JSON corruptos (P1):
      // los servicios avisan vía JsonGuard.reportCorrupt sin contexto, y aquí la
      // raíz de la app muestra el toast oficial.
      JsonGuard.onCorrupt = (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final ctx = SessionGuard.navigatorKey.currentContext;
            if (ctx == null) return;
            PPNotifications.error(
              ctx,
              JsonGuard.kCorruptDataMessage,
              title: 'Datos corruptos',
            );
          } catch (e) {
            debugPrint('⚠️ No se pudo notificar datos corruptos: $e');
          }
        });
      };

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('🚨 Flutter error: ${details.exception}');
        debugPrint('Stack: ${details.stack}');
      };

      await _initApp();
    },
    (error, stack) {
      debugPrint('🚨 Error no capturado: $error');
      debugPrint('Stack: $stack');
    },
  );
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
    await durable_sync.SyncService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ SyncService persistente init error: $e');
  }

  try {
    await PortalPilotDB.initialize();
  } catch (e) {
    debugPrint('Error al inicializar backend: $e');
  }

  // Inicializar servicios de actualización (solo Android)
  if (Platform.isAndroid) {
    try {
      await FCMUpdateService.instance.initialize();
      await AppUpdateService.instance.checkForUpdate(force: true);
      AppUpdateService.instance.startPeriodicCheck();
      debugPrint('[PortalPilot] Servicios de actualización iniciados');
    } catch (e) {
      debugPrint(
        '[PortalPilot] Error iniciando servicios de actualización: $e',
      );
    }
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
  StreamSubscription<AppUpdateInfo>? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _initWindow();
    _listenForUpdates();
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  void _listenForUpdates() {
    if (!Platform.isAndroid) return;
    _updateSubscription = AppUpdateService.instance.updateStream.listen((
      updateInfo,
    ) {
      if (mounted) {
        _showUpdateDialog(updateInfo);
      }
    });
    // Verificar si ya hay actualización pendiente al iniciar
    final pending = AppUpdateService.instance.pendingUpdate;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdateDialog(pending);
      });
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo updateInfo) async {
    final dismissed = await AppUpdateService.instance.isVersionDismissed(
      updateInfo.versionCode,
    );
    if (dismissed && !updateInfo.forceUpdate) return;

    // Re-obtenemos el context tras el await: el anterior pudo desmontarse.
    final ctx = SessionGuard.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    await showDialog<bool>(
      context: ctx,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text(
              'Actualización ${updateInfo.forceUpdate ? 'Obligatoria' : 'Disponible'}',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versión ${updateInfo.versionName} (${updateInfo.versionCode})',
            ),
            const SizedBox(height: 12),
            if (updateInfo.changelog.isNotEmpty) ...[
              const Text(
                'Novedades:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...updateInfo.changelog.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(c, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (updateInfo.forceUpdate)
              const Text(
                'Esta actualización es obligatoria para continuar usando la app.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const Text('¿Deseas actualizar ahora?'),
          ],
        ),
        actions: [
          if (!updateInfo.forceUpdate)
            TextButton(
              onPressed: () async {
                await AppUpdateService.instance.dismissVersion(
                  updateInfo.versionCode,
                );
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: const Text('Después'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await _downloadAndInstall(updateInfo);
            },
            child: const Text('Instalar ahora'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(AppUpdateInfo updateInfo) async {
    final context = SessionGuard.navigatorKey.currentContext;
    if (context == null) return;

    PPNotifications.info(
      context,
      'Descargando actualización v${updateInfo.versionName}...',
    );

    try {
      await AppUpdateService.instance.downloadAndInstall(updateInfo);
      // La app se cerrará automáticamente al instalar el APK
      // El usuario debe volver a abrir la app manualmente
    } catch (e) {
      if (context.mounted) {
        PPNotifications.error(context, 'Error al actualizar: $e');
      }
    }
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
          navigatorKey: SessionGuard.navigatorKey,
          themeMode: themeMode,
          darkTheme: ThemePalette.buildTheme(isDark: true),
          theme: ThemePalette.buildTheme(isDark: false),
          home: _windowRestored
              ? const SplashScreen()
              : const Scaffold(
                  backgroundColor: Color(0xFF000000),
                  body: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: ColoredBox(color: Color(0xFF000000)),
                    ),
                  ),
                ),
          builder: (context, child) {
            final appWidget = CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.f11): () {
                  AppWindowManager.instance.toggleFullScreen();
                },
                const SingleActivator(LogicalKeyboardKey.f11, alt: true): () {
                  AppWindowManager.instance.toggleFullScreen();
                },
              },
              child: Focus(
                autofocus: true,
                child: child ?? const SizedBox.shrink(),
              ),
            );

            if (!Platform.isWindows) {
              return appWidget;
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return ValueListenableBuilder<bool>(
              valueListenable: AppWindowManager.instance.isFullScreenNotifier,
              builder: (context, isFullScreen, _) {
                if (isFullScreen) {
                  return appWidget;
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: WindowCaption(
                        backgroundColor: isDark
                            ? const Color(0xFF000000)
                            : Colors.white,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFB94DDC,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'WORKSPACE',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFD16BF0)
                                      : const Color(0xFF8B2FB0),
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
                    Expanded(child: appWidget),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
