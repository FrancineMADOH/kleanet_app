// Repository FAQ — accès HTTP pour GET /faq/categories et GET /faq/:id.
//
// listCategories() : charge toutes les catégories avec leurs articles imbriqués
//                    en un seul appel (1-call strategy).
// getArticle()     : charge un article individuel — utilisé uniquement en
//                    fallback deep link (navigation directe vers /faq/:id).

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/faq_models.dart';

class FaqRepository {
  FaqRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Charge toutes les catégories FAQ avec leurs articles imbriqués.
  Future<List<FaqCategory>> listCategories() async {
    final response =
        await _apiClient.get<List<dynamic>>(ApiEndpoints.faqCategories);
    return (response.data ?? <dynamic>[])
        .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Charge un article FAQ par son identifiant.
  /// Utilisé en fallback si l'utilisateur arrive sur /faq/:id par deep link.
  Future<FaqArticle> getArticle(String id) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>(ApiEndpoints.faqArticle(id));
    return FaqArticle.fromJson(response.data!);
  }
}
