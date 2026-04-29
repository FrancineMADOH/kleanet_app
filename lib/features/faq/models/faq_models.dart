// Modèles FAQ — catégories et articles retournés par GET /faq/categories.
//
// Structure : une FaqCategory contient une liste d'articles imbriqués.
// Un seul appel API suffit pour charger l'intégralité de la FAQ.

/// Catégorie FAQ regroupant plusieurs articles.
class FaqCategory {
  const FaqCategory({
    required this.id,
    required this.name,
    required this.articles,
  });

  final int id;
  final String name;
  final List<FaqArticle> articles;

  factory FaqCategory.fromJson(Map<String, dynamic> json) => FaqCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        // Si le champ 'articles' est absent ou null, on retourne une liste vide.
        articles: (json['articles'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => FaqArticle.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Article FAQ — la réponse est du contenu HTML provenant d'Odoo.
class FaqArticle {
  const FaqArticle({
    required this.id,
    required this.question,
    required this.answer,
    this.categoryId,
  });

  final int id;

  /// Question affichée dans la liste et en titre de l'écran article.
  final String question;

  /// Réponse complète en HTML (champ `answer` Odoo).
  final String answer;

  /// Identifiant de la catégorie parente — null si non renvoyé par l'API.
  final int? categoryId;

  factory FaqArticle.fromJson(Map<String, dynamic> json) => FaqArticle(
        id: (json['id'] as num).toInt(),
        question: json['question'] as String,
        answer: json['answer'] as String? ?? '',
        categoryId: (json['category_id'] as num?)?.toInt(),
      );
}
