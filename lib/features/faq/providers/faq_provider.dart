// Provider FAQ — état de l'écran catégories + recherche locale.
//
// load()      : charge les catégories depuis le repository.
// setSearch() : filtre local sur tous les articles (question + answer),
//               pas d'appel réseau supplémentaire.

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../models/faq_models.dart';
import '../repositories/faq_repository.dart';

class FaqProvider extends ChangeNotifier {
  FaqProvider({required FaqRepository repository}) : _repo = repository;

  final FaqRepository _repo;

  List<FaqCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<FaqCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  /// Liste plate de tous les articles filtrés par [_searchQuery].
  /// La recherche porte sur la question et la réponse (case-insensitive).
  List<FaqArticle> get filteredArticles {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return _categories
        .expand((cat) => cat.articles)
        .where((art) =>
            art.question.toLowerCase().contains(query) ||
            art.answer.toLowerCase().contains(query))
        .toList();
  }

  /// Charge les catégories depuis l'API. Réinitialise l'erreur à chaque appel.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _categories = await _repo.listCategories();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Erreur de connexion. Veuillez réessayer.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Met à jour la requête de recherche et notifie les widgets.
  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}
