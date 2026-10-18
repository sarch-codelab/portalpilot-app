import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:portal_pilot_app/Shared/services/app_update_service.dart';

/// Servicio para manejar notificaciones push de Firebase (FCM)
/// Escucha mensajes de "nueva versión disponible" y dispara verificación
class FCMUpdateService {
  FCMUpdateService._privateConstructor();
  static final FCMUpdateService instance = FCMUpdateService._privateConstructor();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundSubscription;

  bool _initialized = false;

  /// Inicializa FCM y configura listeners
  Future<void> initialize() async {
    if (_initialized) return;

    // Solicitar permisos (iOS/Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCMUpdateService] Permisos: ${settings.authorizationStatus}');

    // Configurar notificaciones locales
    await _initLocalNotifications();

    // Obtener token FCM (para enviar a tu servidor si quieres targetear dispositivos)
    final token = await _messaging.getToken();
    debugPrint('[FCMUpdateService] FCM Token: $token');

    // Manejar mensaje cuando la app está en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Manejar cuando usuario toca notificación y abre app (terminated/background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Verificar si la app fue abierta desde una notificación (terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Suscribir al tema "app_updates" para recibir pushes de nueva versión
    await _messaging.subscribeToTopic('app_updates');
    debugPrint('[FCMUpdateService] suscrito a topic: app_updates');

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);

    // Crear canal para Android
    const channel = AndroidNotificationChannel(
      'app_updates',
      'Actualizaciones de App',
      description: 'Notificaciones cuando hay nueva versión disponible',
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Mensaje recibido con app en primer plano
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCMUpdateService] Mensaje foreground: ${message.data}');
    _processUpdateMessage(message);
  }

  /// Usuario tocó notificación y abrió app
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCMUpdateService] Mensaje opened app: ${message.data}');
    _processUpdateMessage(message);
  }

  /// Procesa mensaje de tipo "update_available"
  void _processUpdateMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'update_available' || data['update'] == 'true') {
      debugPrint('[FCMUpdateService] Push de actualización recibido');
      // Disparar verificación inmediata
      AppUpdateService.instance.checkForUpdate(force: true, silent: false);
    }
  }

  /// Muestra notificación local "Actualización disponible"
  Future<void> showLocalUpdateNotification(AppUpdateInfo updateInfo) async {
    const androidDetails = AndroidNotificationDetails(
      'app_updates',
      'Actualizaciones de App',
      channelDescription: 'Notificaciones cuando hay nueva versión disponible',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction('install_now', 'Instalar ahora'),
        AndroidNotificationAction('later', 'Después'),
      ],
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      999, // ID fijo para actualizaciones
      'Nueva versión: ${updateInfo.versionName}',
      updateInfo.forceUpdate
          ? 'Actualización obligatoria. Toca para instalar.'
          : 'Disponible v${updateInfo.versionName}. ${updateInfo.changelog.firstOrNull ?? ''}',
      details,
      payload: 'update_${updateInfo.versionCode}',
    );
  }

  /// Cancela suscripción al topic (ej. logout)
  Future<void> unsubscribeFromUpdates() async {
    await _messaging.unsubscribeFromTopic('app_updates');
  }

  /// Re-suscribe (ej. login)
  Future<void> resubscribeToUpdates() async {
    await _messaging.subscribeToTopic('app_updates');
  }

  void dispose() {
    _messageSubscription?.cancel();
    _backgroundSubscription?.cancel();
  }
}