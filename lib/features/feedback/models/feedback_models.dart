// Modèles de données pour la feature Feedback.
//
// Un seul modèle est nécessaire côté Flutter : FeedbackInput.
// L'API retourne un 201 sans corps utile → pas de modèle de réponse.

/// Payload envoyé au POST /feedback.
///
/// Seuls [orderId] et [rating] sont obligatoires. [comment] et
/// [wouldRecommend] sont optionnels et omis du JSON s'ils ne sont
/// pas renseignés (l'API les traite comme null côté Odoo).
class FeedbackInput {
  const FeedbackInput({
    required this.orderId,
    required this.rating,
    this.comment,
    this.wouldRecommend,
  });

  /// Identifiant Odoo de la commande à noter.
  final int orderId;

  /// Note de 1 à 5 étoiles.
  final int rating;

  /// Commentaire libre — optionnel.
  final String? comment;

  /// L'utilisateur recommanderait-il le service ? — optionnel.
  final bool? wouldRecommend;

  /// Sérialise le payload pour le corps du POST /feedback.
  /// Les champs optionnels ne sont inclus que s'ils ont une valeur
  /// non nulle (et non vide pour le commentaire).
  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'rating': rating,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        if (wouldRecommend != null) 'would_recommend': wouldRecommend,
      };
}
