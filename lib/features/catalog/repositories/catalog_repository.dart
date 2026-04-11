// Repository Catalog — accès HTTP au endpoint /catalog/services.
//
// Endpoint public (no auth requise) → on peut l'appeler pendant que
// AuthProvider.bootstrap() est encore en cours. Ça accélère le démarrage
// pour un user déjà connecté : catalog et profil sont fetch en parallèle.

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/response_parser.dart';
import '../models/catalog_models.dart';

class CatalogRepository {
  CatalogRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Récupère le catalogue complet (types + règles de prix).
  /// Convertit toute erreur de parsing en ApiException(BAD_RESPONSE).
  Future<CatalogSnapshot> fetchCatalog() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.catalogServices,
    );
    return parseOrThrow(
      response.data,
      CatalogSnapshot.fromApiJson,
      'catalog response',
    );
  }
}
