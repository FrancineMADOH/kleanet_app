// Provider de la liste des commandes.
//
// Rôles :
//   1. Charge la liste via OrderRepository.listOrders().
//   2. Expose un filtre actif (OrderStatus?) que l'UI modifie via setFilter().
//   3. Gère les états loading / data / error de façon standard.
//
// Cycle de vie :
//   - Instancié dans le builder de la route /orders (ChangeNotifierProvider
//     factory), donc scoped à l'écran — pas de fuite mémoire entre sessions.
//   - load() est appelé au premier affichage (via initState post-frame).
//   - setFilter() relance automatiquement load() avec le nouveau filtre.

import 'package:flutter/foundation.dart' show ChangeNotifier, kDebugMode, debugPrint;

import '../../../core/api/api_exception.dart';
import '../models/order_models.dart';
import '../repositories/order_repository.dart';

class OrdersListProvider extends ChangeNotifier {
  OrdersListProvider({required OrderRepository repository})
      : _repository = repository;

  final OrderRepository _repository;

  // --- État ---
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  OrderStatus? _activeFilter; // null = toutes les commandes

  // --- Getters ---
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  OrderStatus? get activeFilter => _activeFilter;

  /// Vrai si la liste est vide ET qu'aucun chargement n'est en cours —
  /// permet de distinguer "pas encore chargé" de "chargé mais 0 commandes".
  bool get isEmpty => !_isLoading && _orders.isEmpty;

  /// Charge (ou recharge) la liste avec le filtre courant.
  /// Idempotent : peut être appelé plusieurs fois (pull-to-refresh inclus).
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _repository.listOrders(filter: _activeFilter);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } on Exception catch (e, stack) {
      // Erreur réseau inattendue non wrappée en ApiException.
      if (kDebugMode) {
        debugPrint('[OrdersListProvider] load error: $e\n$stack');
      }
      _errorMessage = 'Impossible de charger vos commandes.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change le filtre actif et relance immédiatement un chargement.
  /// Si le filtre est identique, on ne relance rien (évite un appel réseau
  /// inutile quand l'utilisateur tape deux fois sur le même chip).
  Future<void> setFilter(OrderStatus? status) async {
    if (_activeFilter == status) return;
    _activeFilter = status;
    await load();
  }
}
