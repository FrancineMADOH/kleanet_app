// Provider du détail d'une commande (écran tracking).
//
// Ce provider est instancié PAR commande — on crée une nouvelle
// instance à chaque navigation vers /order/:id via un
// ChangeNotifierProvider factory dans le GoRoute. Ça évite de
// gérer un cache partagé pour l'instant (ORDERS-01 introduira une
// map si on en a besoin).
//
// Trois états exposés à l'écran :
//   - isLoading : fetch en cours (premier load ou refresh manuel).
//   - order     : la commande courante (peut être non-null pendant un
//                 refresh — on affiche les anciennes données pendant
//                 qu'on re-fetch, UX plus fluide).
//   - errorMessage : message d'erreur à afficher si rien en cache.

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../models/order_models.dart';
import '../repositories/order_repository.dart';

class OrderDetailProvider extends ChangeNotifier {
  OrderDetailProvider({
    required OrderRepository repository,
    required this.orderId,
  }) : _repository = repository;

  final OrderRepository _repository;
  final int orderId;

  Order? _order;
  bool _isLoading = false;
  String? _errorMessage;

  Order? get order => _order;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _order != null;

  /// Charge (ou recharge) la commande. Idempotent : appels concurrents
  /// sont ignorés pendant qu'un fetch est en vol.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _order = await _repository.getOrderById(orderId);
    } on ApiException catch (e) {
      // Si on n'a aucune donnée en cache, on affiche l'erreur. Sinon
      // on garde l'ancien snapshot affiché et on log discrètement.
      if (_order == null) {
        _errorMessage = e.message;
      } else {
        if (kDebugMode) {
          debugPrint('[OrderDetail] refresh failed, keeping cache: ${e.message}');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
