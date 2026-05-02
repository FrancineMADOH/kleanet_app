// Service FCM — initialisation Firebase Messaging et gestion des messages.
//
// Trois cas couverts :
//   - Foreground : message reçu pendant que l'app est ouverte (callback onMessage).
//   - Background/terminé → tap : l'utilisateur tape la notif → app s'ouvre
//     (getInitialMessage + onMessageOpenedApp).
//   - Background handler (top-level) : traitement silencieux sans UI.
//
// Le FCM token est loggé en debug. Quand l'API Fastify sera prête (étape
// NOTIFICATIONS-02), on l'enverra via un endpoint /devices/register.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handler background — doit être une fonction top-level (pas une méthode).
/// Appelé par Firebase quand l'app est en arrière-plan ou terminée.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] background: ${message.messageId} — ${message.notification?.title}');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  // Callback injecté par main.dart pour naviguer vers un écran précis
  // quand l'utilisateur tape une notification (ex: /order/:id).
  void Function(RemoteMessage)? onNotificationTap;

  /// Initialise FCM : permissions, handlers, token.
  /// Appelé UNE seule fois depuis main(), après Firebase.initializeApp().
  Future<void> init() async {
    // Enregistre le handler background avant tout le reste.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Demande la permission (Android 13+ / iOS).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('[FCM] permission: ${settings.authorizationStatus}');
    }

    // Token — sera envoyé à l'API pour cibler cet appareil.
    final token = await _messaging.getToken();
    if (kDebugMode) {
      debugPrint('[FCM] token: $token');
    }

    // Renouvellement automatique du token (ex: réinstallation).
    _messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        debugPrint('[FCM] token refreshed: $newToken');
      }
      // TODO(NOTIFICATIONS-02): envoyer newToken à l'API.
    });

    // Message foreground (app ouverte).
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Tap sur notif quand l'app était en arrière-plan.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Tap sur notif quand l'app était terminée (cold start).
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleTap(initial);
    }
  }

  void _handleForeground(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] foreground: ${message.notification?.title} — ${message.notification?.body}');
    }
    // TODO(NOTIFICATIONS-02): afficher un SnackBar ou une bannière in-app.
  }

  void _handleTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] tapped: ${message.data}');
    }
    onNotificationTap?.call(message);
  }
}
