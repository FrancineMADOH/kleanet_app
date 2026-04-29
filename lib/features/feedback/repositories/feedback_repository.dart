// Repository Feedback — accès HTTP pour POST /feedback.
//
// Un seul appel : submit() envoie la note + commentaire + recommandation
// pour une commande livrée. L'API retourne 201 sans corps.
//
// Exceptions possibles remontées au provider :
//   ApiException(409) — commande déjà notée
//   ApiException(0)   — pas de réseau
//   ApiException(401) — session expirée (gérée en amont par ApiClient)

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/feedback_models.dart';

/// Accès HTTP à l'endpoint de feedback.
class FeedbackRepository {
  FeedbackRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Soumet un feedback pour une commande livrée.
  ///
  /// Lance [ApiException] avec statusCode 409 si la commande a déjà
  /// été notée — l'appelant (FeedbackProvider) est responsable de
  /// présenter un message lisible à l'utilisateur.
  Future<void> submit(FeedbackInput input) async {
    await _apiClient.post<void>(
      ApiEndpoints.feedback,
      data: input.toJson(),
    );
  }
}
