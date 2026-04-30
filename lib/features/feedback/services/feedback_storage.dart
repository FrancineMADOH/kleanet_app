// Persistance locale des feedbacks soumis — filet de sécurité côté client.
//
// Stocke les orderId pour lesquels un avis a été soumis dans SharedPreferences.
// Utilisé par OrderDetailProvider pour masquer le bouton "Laisser un avis"
// immédiatement après soumission, même avant que l'API expose has_feedback: true.
//
// Dès que le backend renvoie has_feedback: true dans GET /orders/{id},
// ce check devient redondant — il reste inoffensif.

import 'package:shared_preferences/shared_preferences.dart';

class FeedbackStorage {
  FeedbackStorage._();

  static const _key = 'submitted_feedback_order_ids';

  /// Enregistre [orderId] comme "déjà noté" en local.
  static Future<void> markSubmitted(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    final asString = orderId.toString();
    if (!ids.contains(asString)) {
      ids.add(asString);
      await prefs.setStringList(_key, ids);
    }
  }

  /// Retourne true si un feedback a déjà été soumis localement pour [orderId].
  static Future<bool> hasSubmitted(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    return ids.contains(orderId.toString());
  }
}
