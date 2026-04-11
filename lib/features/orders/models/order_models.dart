// Modèles Orders — représente les réponses de l'API /orders et
// les payloads de création.
//
// Découpage :
//   - OrderStatus        : énum typée du cycle de vie backend.
//   - OrderLine          : une ligne de commande renvoyée par l'API
//     (inclut unit_price + subtotal calculés server-side).
//   - Order              : la commande complète, telle que retournée
//     par POST /orders et GET /orders/{id}.
//   - CreateOrderLine    : payload envoyé au POST — soit quantity
//     (pièce) soit weight_kg (vrac), jamais les deux.
//   - CreateOrderRequest : payload complet envoyé au POST /orders.
//
// À noter : l'API ne reçoit PAS le prix au POST — le prix total est
// calculé côté Odoo à partir des pricing rules. On ne peut donc afficher
// qu'une ESTIMATION côté client avant confirmation.

/// Statuts possibles d'une commande — doit rester synchro avec l'enum
/// Odoo `laundry.order.state` et la `status` enum de l'OpenAPI.
enum OrderStatus {
  pending,
  received,
  processing,
  readyForPickup,
  delivered,
  cancelled;

  static OrderStatus fromJson(String raw) => switch (raw) {
        'pending' => OrderStatus.pending,
        'received' => OrderStatus.received,
        'processing' => OrderStatus.processing,
        'ready_for_pickup' => OrderStatus.readyForPickup,
        'delivered' => OrderStatus.delivered,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.pending,
      };

  /// Libellé français court pour l'UI (badges / timeline).
  String get label => switch (this) {
        OrderStatus.pending => 'En attente',
        OrderStatus.received => 'Reçue',
        OrderStatus.processing => 'En traitement',
        OrderStatus.readyForPickup => 'Prête',
        OrderStatus.delivered => 'Livrée',
        OrderStatus.cancelled => 'Annulée',
      };
}

/// Ligne de commande telle que renvoyée par l'API (lecture seule).
class OrderLine {
  const OrderLine({
    required this.id,
    required this.quantity,
    required this.weightKg,
    required this.unitPrice,
    required this.subtotal,
    this.garmentTypeId,
    this.garmentTypeName,
    this.materialId,
    this.materialName,
  });

  final int id;
  final int? garmentTypeId;
  final String? garmentTypeName;
  final int? materialId;
  final String? materialName;
  final double quantity;
  final double weightKg;
  final double unitPrice;
  final double subtotal;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        id: (json['id'] as num).toInt(),
        garmentTypeId: (json['garment_type_id'] as num?)?.toInt(),
        garmentTypeName: json['garment_type_name'] as String?,
        materialId: (json['material_id'] as num?)?.toInt(),
        materialName: json['material_name'] as String?,
        quantity: (json['quantity'] as num).toDouble(),
        weightKg: (json['weight_kg'] as num).toDouble(),
        unitPrice: (json['unit_price'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
      );
}

/// Commande complète renvoyée par l'API — sert à la fois pour la
/// confirmation post-POST et pour les écrans de tracking / liste.
class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.status,
    required this.amountTotal,
    required this.currency,
    required this.totalPieces,
    required this.lines,
    this.dateReceived,
    this.dateReady,
    this.notes,
    this.trackingUrl,
  });

  final int id;
  final String reference;
  final OrderStatus status;
  final double amountTotal;
  final String currency;
  final int totalPieces;
  final List<OrderLine> lines;
  final DateTime? dateReceived;
  final DateTime? dateReady;
  final String? notes;
  final String? trackingUrl;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: (json['id'] as num).toInt(),
        reference: json['reference'] as String,
        status: OrderStatus.fromJson(json['status'] as String),
        amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'XAF',
        totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 0,
        dateReceived: _parseDate(json['date_received']),
        dateReady: _parseDate(json['date_ready']),
        notes: json['notes'] as String?,
        trackingUrl: json['tracking_url'] as String?,
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Payload d'une ligne pour POST /orders — on remplit EITHER
/// quantity (mode pièce) OR weightKg (mode kilo), jamais les deux.
class CreateOrderLine {
  const CreateOrderLine({
    required this.garmentTypeId,
    this.materialId,
    this.quantity,
    this.weightKg,
  });

  final int garmentTypeId;
  final int? materialId;
  final double? quantity;
  final double? weightKg;

  Map<String, dynamic> toJson() => {
        'garment_type_id': garmentTypeId,
        if (materialId != null) 'material_id': materialId,
        if (quantity != null) 'quantity': quantity,
        if (weightKg != null) 'weight_kg': weightKg,
      };
}

/// Payload complet pour POST /orders.
class CreateOrderRequest {
  const CreateOrderRequest({
    required this.lines,
    this.notes,
  });

  final List<CreateOrderLine> lines;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'lines': lines.map((l) => l.toJson()).toList(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}
