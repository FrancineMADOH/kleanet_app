// Repository Orders — thin wrapper Dio autour de /orders et /appointments.
//
// Trois méthodes lectures + une mutation + un rendez-vous :
//   - listOrders({filter})           → GET /orders?status=&limit=50
//   - createOrder(request)           → POST /orders
//   - getOrderById(id)               → GET /orders/{id}
//   - schedulePickup(orderId, when)  → POST /appointments (type=pickup)
//
// Pourquoi deux appels (createOrder + schedulePickup) ? Le backend sépare
// "commande" et "rendez-vous pickup" — l'API /orders ne prend PAS de date
// de collecte. On enchaîne les deux depuis le provider.

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/response_parser.dart';
import '../models/order_models.dart';

class OrderRepository {
  OrderRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Récupère la liste des commandes du partenaire authentifié.
  /// [filter] : si fourni, filtre sur un statut précis (query param `status`).
  /// On demande 50 résultats max — suffisant pour V1 sans pagination scroll.
  Future<List<Order>> listOrders({OrderStatus? filter}) async {
    final response = await _apiClient.get<List<dynamic>>(
      ApiEndpoints.orders,
      queryParameters: {
        'limit': 50,
        if (filter != null) 'status': filter.apiValue,
      },
    );
    final raw = response.data ?? [];
    return raw
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crée une nouvelle commande. Le prix total n'est PAS à envoyer —
  /// Odoo le recalcule server-side depuis les pricing rules.
  Future<Order> createOrder(CreateOrderRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.orders,
      data: request.toJson(),
    );
    return parseOrThrow(response.data, Order.fromJson, 'create order response');
  }

  /// Récupère le détail d'une commande. Utilisé par l'écran de tracking
  /// (GET /orders/{id}) — renvoie le même shape que createOrder.
  Future<Order> getOrderById(int id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.orderById(id.toString()),
    );
    return parseOrThrow(response.data, Order.fromJson, 'order detail response');
  }

  /// Programme un rendez-vous pickup pour [orderId] au moment [scheduledFrom].
  /// Contrainte backend : [scheduledFrom] doit être au moins 2h dans le futur.
  Future<void> schedulePickup({
    required int orderId,
    required DateTime scheduledFrom,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.appointments,
      data: {
        'type': 'pickup',
        'scheduled_from': scheduledFrom.toUtc().toIso8601String(),
        'order_ids': [orderId],
      },
    );
  }
}
