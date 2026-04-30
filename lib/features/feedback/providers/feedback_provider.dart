// Provider Feedback — état du formulaire de notation d'une commande.
//
// Cycle de vie attendu :
//   1. L'utilisateur sélectionne une note (1-5) via setRating()
//   2. Il remplit optionnellement un commentaire via setComment()
//   3. Il indique optionnellement s'il recommande via setWouldRecommend()
//   4. Il valide via submit() — canSubmit doit être true
//   5. Sur succès : _submitted = true → l'écran navigue vers /feedback/success
//   6. Sur erreur : _error est renseigné → l'écran affiche le message

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../models/feedback_models.dart';
import '../repositories/feedback_repository.dart';
import '../services/feedback_storage.dart';

/// Gère l'état du formulaire de feedback.
///
/// Instancié factory-scopé sur la route /feedback/:orderId (voir app_router.dart)
/// → libéré automatiquement à la fermeture de l'écran.
class FeedbackProvider extends ChangeNotifier {
  // --- État du formulaire ---

  /// Note sélectionnée (1–5). null = pas encore noté.
  int? _rating;

  /// Texte du commentaire libre.
  String _comment = '';

  /// Indique si l'utilisateur recommanderait le service.
  bool? _wouldRecommend;

  // --- État de soumission ---

  /// true pendant le POST /feedback.
  bool _isSubmitting = false;

  /// Message d'erreur à afficher, null si pas d'erreur.
  String? _error;

  /// true après un POST réussi — signal pour naviguer vers l'écran succès.
  bool _submitted = false;

  // --- Getters publics ---

  int? get rating => _rating;
  String get comment => _comment;
  bool? get wouldRecommend => _wouldRecommend;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  bool get submitted => _submitted;

  /// Le formulaire ne peut être soumis que si une note est sélectionnée
  /// et qu'aucun envoi n'est en cours.
  bool get canSubmit => _rating != null && !_isSubmitting;

  // --- Mutateurs du formulaire ---

  /// Met à jour la note et efface l'erreur précédente.
  void setRating(int r) {
    _rating = r;
    _error = null;
    notifyListeners();
  }

  /// Met à jour le commentaire libre.
  void setComment(String c) {
    _comment = c;
    notifyListeners();
  }

  /// Met à jour l'indicateur de recommandation.
  void setWouldRecommend(bool v) {
    _wouldRecommend = v;
    notifyListeners();
  }

  // --- Soumission ---

  /// Envoie le feedback via [repo] pour la commande [orderId].
  ///
  /// Gère les cas d'erreur :
  ///   - 409 → message explicite "déjà noté"
  ///   - autres ApiException → message API (déjà traduit par le backend)
  ///   - erreurs imprévues → message générique
  ///
  /// Le bloc `finally` garantit que [_isSubmitting] est toujours remis
  /// à false, même en cas d'exception, pour éviter de bloquer l'UI.
  Future<void> submit(FeedbackRepository repo, int orderId) async {
    if (!canSubmit) return;
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await repo.submit(FeedbackInput(
        orderId: orderId,
        rating: _rating!,
        comment: _comment.trim().isEmpty ? null : _comment.trim(),
        wouldRecommend: _wouldRecommend,
      ));
      _submitted = true;
      // Persistance locale : le bouton disparaît immédiatement sans attendre
      // que l'API expose has_feedback: true (upgrade Odoo + API requis).
      await FeedbackStorage.markSubmitted(orderId);
    } on ApiException catch (e) {
      // 409 = commande déjà notée — message clair pour l'utilisateur.
      _error = e.statusCode == 409
          ? 'Vous avez déjà noté cette commande.'
          : e.message;
    } catch (e) {
      _error = 'Une erreur est survenue. Veuillez réessayer.';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
