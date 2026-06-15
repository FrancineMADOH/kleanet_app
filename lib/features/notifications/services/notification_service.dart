// Service FCM — initialisation Firebase Messaging et gestion des messages.
//
// Trois cas couverts :
//   - Foreground : message reçu pendant que l'app est ouverte → stocké dans
//     NotificationProvider (badge mis à jour).
//   - Background/terminé → tap : l'utilisateur tape la notif → navigation
//     vers la bonne commande via le callback [onNotificationTap].
//   - Background handler (top-level) : Firebase exige une fonction top-level,
//     pas une méthode — déclarée ci-dessous.
//
// Câblage dans main.dart :
//   1. NotificationService.instance.notificationProvider = provider;
//   2. NotificationService.instance.onNotificationTap = (msg) { ... };
//   3. await NotificationService.instance.init();

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../providers/notification_provider.dart';

/// Handler background — doit être une fonction top-level (contrainte Firebase).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('[FCM] background: ${message.messageId} — ${message.notification?.title}');
  }
  // Pas d'accès à NotificationProvider ici (isolat séparé).
  // Le message apparaîtra dans la barre de notification système.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  /// Clé injectée dans MaterialApp.router (scaffoldMessengerKey) — permet
  /// d'afficher un SnackBar banner quand une notif arrive au premier plan,
  /// sans avoir besoin d'un BuildContext local.
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Injecté depuis main.dart — permet de stocker les notifs reçues.
  NotificationProvider? notificationProvider;

  /// Injecté depuis main.dart — permet de naviguer vers une commande
  /// quand l'utilisateur tape une notification.
  void Function(RemoteMessage)? onNotificationTap;

  /// Initialise FCM : enregistre le handler background, demande la
  /// permission, configure les 3 listeners, et log le token.
  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Demande la permission d'envoi de notifications (Android 13+ / iOS).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('[FCM] permission: ${settings.authorizationStatus}');
    }

    // Token initial — envoyé à l'API par AuthProvider après login.
    final token = await _messaging.getToken();
    if (kDebugMode) {
      debugPrint('[FCM] token: $token');
    }

    // Renouvellement du token (réinstallation, effacement de données…).
    _messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        debugPrint('[FCM] token refreshed: $newToken');
      }
      // TODO(NOTIFICATIONS-02): envoyer newToken à l'API via AuthRepository.
    });

    // Message reçu quand l'app est au premier plan.
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Tap sur la notification système quand l'app était en arrière-plan.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Tap sur la notification qui a relancé l'app depuis l'état terminé.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleTap(initial);
    }
  }

  /// Retourne le FCM token courant. Appelé par AuthProvider après login
  /// pour l'envoyer au backend (PATCH /profile).
  Future<String?> getToken() => _messaging.getToken();

  void _handleForeground(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] foreground: ${message.notification?.title}');
    }
    // Stocke la notification dans le provider (badge + centre notifs).
    notificationProvider?.addFromMessage(message);

    // Affiche un SnackBar banner si le titre est disponible.
    // scaffoldMessengerKey doit être câblé dans MaterialApp.router.
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (body != null)
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E3A5F), // AppColors.primary
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] tapped: ${message.data}');
    }
    // Stocke d'abord (cas cold-start : la notif n'a pas encore été ajoutée).
    notificationProvider?.addFromMessage(message);
    // Puis navigue.
    onNotificationTap?.call(message);
  }
}
