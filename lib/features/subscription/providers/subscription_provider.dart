// Provider Subscription — orchestre les 3 appels API de l'onglet abonnement.
//
// Rôles :
//   1. Charge l'abonnement actif (loadSubscription) → détermine si l'user
//      voit le dashboard ou la page de vente.
//   2. Charge les plans disponibles (loadPlans) → alimenté l'écran de comparaison.
//   3. Déclenche la souscription (subscribe) → POST /subscription/ + mise à jour
//      de l'état local sans rechargement réseau.
//
// Séparation des états de chargement :
//   isLoadingSubscription / isLoadingPlans / isSubscribing sont indépendants
//   pour ne pas bloquer l'UI entière si seul un appel est en cours.

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../models/subscription_models.dart';
import '../repositories/subscription_repository.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({required SubscriptionRepository repository})
      : _repository = repository;

  final SubscriptionRepository _repository;

  // --- État abonnement ---
  ActiveSubscription? _subscription;
  bool _isLoadingSubscription = false;
  String? _subscriptionError;

  // --- État plans ---
  List<SubscriptionPlan> _plans = [];
  bool _isLoadingPlans = false;
  String? _plansError;

  // --- État souscription en cours ---
  bool _isSubscribing = false;
  String? _subscribeError;

  // --- Getters ---
  ActiveSubscription? get subscription => _subscription;
  bool get isSubscribed =>
      _subscription != null && _subscription!.state == SubscriptionState.active;

  bool get isLoadingSubscription => _isLoadingSubscription;
  String? get subscriptionError => _subscriptionError;

  List<SubscriptionPlan> get plans => _plans;
  bool get isLoadingPlans => _isLoadingPlans;
  String? get plansError => _plansError;

  bool get isSubscribing => _isSubscribing;
  String? get subscribeError => _subscribeError;

  /// Charge l'abonnement actif. Appelé au montage du hub.
  Future<void> loadSubscription() async {
    _isLoadingSubscription = true;
    _subscriptionError = null;
    notifyListeners();

    try {
      _subscription = await _repository.getMySubscription();
    } on ApiException catch (e) {
      _subscriptionError = e.message;
    } on Exception catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[SubscriptionProvider] loadSubscription error: $e\n$stack');
      }
      _subscriptionError = 'Impossible de charger votre abonnement.';
    } finally {
      _isLoadingSubscription = false;
      notifyListeners();
    }
  }

  /// Charge la liste des plans disponibles. Appelé depuis PlansScreen.
  Future<void> loadPlans() async {
    _isLoadingPlans = true;
    _plansError = null;
    notifyListeners();

    try {
      _plans = await _repository.listPlans();
      // Les plans recommandés remontent en tête de liste.
      _plans.sort((a, b) {
        if (a.isRecommended == b.isRecommended) return 0;
        return a.isRecommended ? -1 : 1;
      });
    } on ApiException catch (e) {
      _plansError = e.message;
    } on Exception catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[SubscriptionProvider] loadPlans error: $e\n$stack');
      }
      _plansError = 'Impossible de charger les plans.';
    } finally {
      _isLoadingPlans = false;
      notifyListeners();
    }
  }

  /// Souscrit au plan [planId]. Retourne true si succès, false si erreur.
  /// En cas de 409 ALREADY_SUBSCRIBED, [subscribeError] est renseigné.
  Future<bool> subscribe(int planId) async {
    _isSubscribing = true;
    _subscribeError = null;
    notifyListeners();

    try {
      _subscription = await _repository.subscribe(planId);
      return true;
    } on ApiException catch (e) {
      _subscribeError = e.message;
      return false;
    } on Exception catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[SubscriptionProvider] subscribe error: $e\n$stack');
      }
      _subscribeError = 'Erreur lors de la souscription.';
      return false;
    } finally {
      _isSubscribing = false;
      notifyListeners();
    }
  }
}
