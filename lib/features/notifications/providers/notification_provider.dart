// Provider du centre de notifications.
//
// Rôles :
//   - Stocker la liste des notifications reçues (persistance SharedPreferences).
//   - Exposer unreadCount pour le badge 🔔 de l'AppBar.
//   - Permettre à NotificationService d'ajouter une notification depuis un
//     message FCM (foreground et background).
//   - Marquer toutes les notifications comme lues quand l'utilisateur ouvre
//     le centre de notifications.
//
// La limite est fixée à 50 notifications — les plus anciennes sont tronquées
// pour ne pas saturer SharedPreferences.

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_models.dart';

class NotificationProvider extends ChangeNotifier {
  // Clé SharedPreferences — préfixée pour éviter les collisions.
  static const _kKey = 'kleanet.notifications.list';
  static const _kMaxItems = 50;

  List<LocalNotification> _notifications = [];

  List<LocalNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Charge la liste persistée depuis SharedPreferences.
  /// Appelé au démarrage depuis main.dart.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => LocalNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      _notifications = list;
      notifyListeners();
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[NotifProvider] load error: $e');
      }
    }
  }

  /// Crée une LocalNotification depuis un RemoteMessage FCM et la persiste.
  /// Appelé par NotificationService à la réception d'un message.
  Future<void> addFromMessage(RemoteMessage message) async {
    final notif = message.notification;
    final title = notif?.title ?? 'Kleanet';
    final body = notif?.body ?? '';
    final type = message.data['type'] as String?;
    final orderId = message.data['order_id'] as String?;

    final item = LocalNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      orderId: orderId,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, item);
    // Tronquer à la limite pour ne pas surcharger le stockage.
    if (_notifications.length > _kMaxItems) {
      _notifications = _notifications.sublist(0, _kMaxItems);
    }
    notifyListeners();
    await _save();
  }

  /// Marque toutes les notifications comme lues — appelé en entrant dans
  /// l'écran NotificationsScreen.
  Future<void> markAllAsRead() async {
    if (unreadCount == 0) return;
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kKey,
        jsonEncode(_notifications.map((n) => n.toJson()).toList()),
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('[NotifProvider] save error: $e');
      }
    }
  }
}
