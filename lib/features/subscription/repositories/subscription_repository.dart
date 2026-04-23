// Repository Subscription — thin wrapper Dio autour de /subscription/ et
// /catalog/plans.
//
// Trois méthodes :
//   - listPlans()        → GET /catalog/plans
//   - getMySubscription() → GET /subscription/ (null si aucun abonnement actif)
//   - subscribe(planId)  → POST /subscription/ {plan_id}

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/subscription_models.dart';

class SubscriptionRepository {
  SubscriptionRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Charge la liste des plans disponibles dans le catalogue.
  Future<List<SubscriptionPlan>> listPlans() async {
    final response = await _apiClient.get<List<dynamic>>(
      ApiEndpoints.catalogPlans,
    );
    final raw = response.data ?? [];
    return raw
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Charge l'abonnement actif du partenaire authentifié.
  /// Retourne null si aucun abonnement n'existe (l'API retourne {subscription: null}).
  Future<ActiveSubscription?> getMySubscription() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.subscription,
    );
    final raw = response.data?['subscription'];
    if (raw == null) return null;
    return ActiveSubscription.fromJson(raw as Map<String, dynamic>);
  }

  /// Souscrit au plan [planId]. Lance une [ApiException] si l'utilisateur
  /// a déjà un abonnement actif (409 ALREADY_SUBSCRIBED côté API).
  Future<ActiveSubscription> subscribe(int planId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.subscription,
      data: {'plan_id': planId},
    );
    final data = response.data;
    if (data == null) throw Exception('subscribe: réponse vide');
    return ActiveSubscription.fromJson(data);
  }
}
