// Provider du catalogue — exposé à toute l'app via MultiProvider.
//
// Stratégie "cache-first, refresh-in-background" :
//   1. load() lit d'abord le cache local.
//   2. Si le cache est frais (< TTL) → émet immédiatement, PAS de fetch.
//   3. Si le cache est absent ou stale → émet le cache quand même
//      (UX instantanée), puis fetch en arrière-plan pour rafraîchir.
//   4. Si le fetch échoue et qu'on a du cache → on garde le cache
//      (mode hors-ligne) et on log l'erreur sans déranger l'UI.
//   5. Si le fetch échoue ET qu'il n'y a pas de cache → errorMessage
//      peuplé, l'UI affiche un empty state avec bouton "Réessayer".

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/utils/currency_utils.dart';
import '../models/catalog_models.dart';
import '../repositories/catalog_cache.dart';
import '../repositories/catalog_repository.dart';

class CatalogProvider extends ChangeNotifier {
  CatalogProvider({
    required CatalogRepository repository,
    required CatalogCache cache,
  })  : _repository = repository,
        _cache = cache;

  final CatalogRepository _repository;
  final CatalogCache _cache;

  /// Durée de vie du cache avant qu'un refetch automatique ne soit
  /// déclenché au prochain `load()`. Le plan dev parle d'1h — on reste
  /// là-dessus, le catalogue change rarement.
  static const cacheTtl = Duration(hours: 1);

  CatalogSnapshot? _snapshot;
  bool _isLoading = false;
  String? _errorMessage;

  List<GarmentType> get garmentTypes => _snapshot?.garmentTypes ?? const [];
  List<PricingRule> get pricingRules => _snapshot?.pricingRules ?? const [];
  DateTime? get fetchedAt => _snapshot?.fetchedAt;
  bool get isLoading => _isLoading;
  bool get isEmpty => garmentTypes.isEmpty;
  String? get errorMessage => _errorMessage;

  /// Charge le catalogue. À appeler au démarrage (fire-and-forget dans
  /// main.dart) ET à chaque pull-to-refresh (avec `forceRefresh: true`).
  ///
  /// La méthode est idempotente : deux appels concurrents ne lancent
  /// pas deux fetch, le second observe juste `_isLoading` et sort.
  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading) return;

    // Étape 1 : peupler immédiatement depuis le cache si on ne l'a pas
    // encore fait (évite un écran vide au premier build).
    if (_snapshot == null) {
      final cached = await _cache.read();
      if (cached != null) {
        _snapshot = cached;
        notifyListeners();
      }
    }

    // Étape 2 : décider s'il faut fetch.
    final needsFetch = forceRefresh ||
        _snapshot == null ||
        _snapshot!.isStale(cacheTtl);
    if (!needsFetch) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fresh = await _repository.fetchCatalog();
      _snapshot = fresh;
      await _cache.write(fresh);
    } on ApiException catch (e) {
      // Si on a déjà du cache, on le garde (mode offline) — sinon on
      // remonte le message pour l'empty state.
      if (_snapshot == null) {
        _errorMessage = e.message;
      } else {
        if (kDebugMode) {
          debugPrint('[CatalogProvider] refresh failed, keeping cache: ${e.message}');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cherche la règle de prix applicable à un type de vêtement donné.
  /// Logique de match (par nom, car le backend ne fournit pas d'ID FK) :
  ///   1. Si `material` est fourni → cherche une rule avec material_name
  ///      ET garment_type_name correspondants (exact match matière).
  ///   2. Sans matière → préférer la rule générique (materialName == null)
  ///      associée au type, pour éviter de retomber sur une règle matière-
  ///      spécifique par accident (ex: "Pantalon Denim 800" au lieu de
  ///      "Pantalon standard 700").
  ///   3. Fallback type : première rule qui matche garment_type_name, quelle
  ///      que soit la matière.
  ///   4. Fallback global : rule sans type ni matière (tarif "au kilo" global).
  ///
  /// Retourne `null` si aucune règle ne matche — l'UI doit afficher
  /// "prix sur demande" ou cacher l'article.
  PricingRule? findPriceFor(GarmentType type, {String? material}) {
    final mat = material ?? type.defaultMaterial;

    // Étape 1 — exact match matière + type.
    if (mat != null) {
      final exact = pricingRules.firstWhereOrNull(
        (r) => r.garmentTypeName == type.name && r.materialName == mat,
      );
      if (exact != null) return exact;
    }

    // Étape 2 — règle générique pour ce type (sans matière spécifique).
    // Prioritaire sur les règles matière-spécifiques quand aucune matière
    // n'est connue, sinon firstWhereOrNull retournerait la première règle
    // dans l'ordre Odoo — qui peut être une règle Denim ou autre.
    final generic = pricingRules.firstWhereOrNull(
      (r) => r.garmentTypeName == type.name && r.materialName == null,
    );
    if (generic != null) return generic;

    // Étape 3 — n'importe quelle rule pour ce type (fallback matière).
    final byType = pricingRules.firstWhereOrNull(
      (r) => r.garmentTypeName == type.name,
    );
    if (byType != null) return byType;

    // Étape 4 — rule globale sans type ni matière.
    return pricingRules.firstWhereOrNull(
      (r) => r.garmentTypeName == null && r.materialName == null,
    );
  }

  /// Format prêt à afficher pour un type de vêtement.
  /// Ex: `"1 200 XAF/pièce"` ou `"Prix sur demande"`.
  String formattedPriceFor(GarmentType type, {String? material}) {
    final rule = findPriceFor(type, material: material);
    if (rule == null) return 'Prix sur demande';
    return '${CurrencyUtils.formatXAF(rule.price)}/${rule.mode.unitLabel}';
  }

  /// Vide toutes les données en mémoire + le cache disque.
  /// Appelé au logout — évite qu'un user voie les dernières données
  /// d'un autre user s'ils partagent l'appareil.
  Future<void> clear() async {
    _snapshot = null;
    _errorMessage = null;
    _isLoading = false;
    await _cache.clear();
    notifyListeners();
  }
}

// Petit helper car Dart n'a pas de firstWhereOrNull en core — évite
// d'ajouter la dep `collection` juste pour ça.
extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
