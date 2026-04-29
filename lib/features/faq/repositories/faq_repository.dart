// Repository FAQ — accès HTTP pour GET /faq/ et groupement par catégorie.
//
// L'API retourne une liste plate de FaqItem :
//   { id, question, answer, category: {id, name} | null, sequence }
//
// listCategories() reçoit cette liste plate et la groupe en mémoire en
// List<FaqCategory>, chaque catégorie contenant ses articles triés par sequence.
// Ce groupement est une responsabilité du repository (transformation de données
// réseau → modèle UI) — le provider et les écrans ne voient que FaqCategory[].

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/faq_models.dart';

/// Représentation interne d'un item FAQ tel que renvoyé par l'API (liste plate).
/// Privée au repository — l'UI utilise FaqArticle / FaqCategory.
class _FaqApiItem {
  const _FaqApiItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.sequence,
    this.categoryId,
    this.categoryName,
  });

  final int id;
  final String question;
  final String answer;
  final int sequence;
  final int? categoryId;
  final String? categoryName;

  /// L'API retourne `category: {id, name}` (objet) ou `category: null`.
  factory _FaqApiItem.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>?;
    return _FaqApiItem(
      id: (json['id'] as num).toInt(),
      question: json['question'] as String,
      answer: json['answer'] as String? ?? '',
      sequence: (json['sequence'] as num? ?? 0).toInt(),
      categoryId: cat != null ? (cat['id'] as num).toInt() : null,
      categoryName: cat?['name'] as String?,
    );
  }
}

class FaqRepository {
  FaqRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Charge les articles FAQ depuis l'API et les groupe par catégorie.
  /// Les items sans catégorie sont ignorés.
  Future<List<FaqCategory>> listCategories() async {
    final response =
        await _apiClient.get<List<dynamic>>(ApiEndpoints.faqCategories);
    final items = (response.data ?? <dynamic>[])
        .map((e) => _FaqApiItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return _groupByCategory(items);
  }

  /// Charge un article FAQ individuel par son identifiant.
  /// Utilisé en fallback si l'utilisateur arrive sur /faq/:id par deep link.
  Future<FaqArticle> getArticle(String id) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>(ApiEndpoints.faqArticle(id));
    final item = _FaqApiItem.fromJson(response.data!);
    return FaqArticle(
      id: item.id,
      question: item.question,
      answer: item.answer,
      categoryId: item.categoryId,
    );
  }

  /// Groupe une liste plate de _FaqApiItem par catégorie, triés par sequence.
  static List<FaqCategory> _groupByCategory(List<_FaqApiItem> items) {
    // Deux maps parallèles : noms des catégories + articles par catégorie.
    final Map<int, String> catNames = {};
    final Map<int, List<FaqArticle>> catArticles = {};

    for (final item in items..sort((a, b) => a.sequence.compareTo(b.sequence))) {
      if (item.categoryId == null || item.categoryName == null) continue;
      catNames[item.categoryId!] = item.categoryName!;
      catArticles
          .putIfAbsent(item.categoryId!, () => <FaqArticle>[])
          .add(FaqArticle(
            id: item.id,
            question: item.question,
            answer: item.answer,
            categoryId: item.categoryId,
          ));
    }

    return catArticles.entries
        .map((e) => FaqCategory(
              id: e.key,
              name: catNames[e.key]!,
              articles: e.value,
            ))
        .toList();
  }
}
