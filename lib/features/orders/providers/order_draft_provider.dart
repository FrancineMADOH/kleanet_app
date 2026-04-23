// Provider du brouillon de commande (flux Nouvelle commande).
//
// Portée : vit tant que l'utilisateur est dans le flux /order/new/*.
// Dès que la commande est confirmée OU que l'utilisateur sort du flux
// (back depuis /order/new), reset() doit être appelé.
//
// Rôle :
//   1. Accumuler les lignes (GarmentType → quantité ou poids).
//   2. Stocker le créneau pickup choisi.
//   3. Stocker les notes libres (adresse, instructions).
//   4. Calculer une ESTIMATION de prix côté client (le vrai total est
//      recalculé par Odoo après POST).
//   5. Soumettre la commande → createOrder → schedulePickup → renvoyer
//      l'Order complet à l'écran de confirmation.
//
// C'est un ChangeNotifier simple (pas de machine à états complexe) car
// le flux est linéaire et court. Pour l'anti-double-submit on utilise
// juste un bool isSubmitting.

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../catalog/models/catalog_models.dart';
import '../../catalog/providers/catalog_provider.dart';
import '../models/order_models.dart';
import '../repositories/order_repository.dart';

/// Une ligne du brouillon — indexée par id de garment type en interne.
/// On stocke quantity OU weightKg selon le mode de pricing applicable.
class DraftLine {
  DraftLine({
    required this.garmentType,
    required this.mode,
    this.quantity = 0,
    this.weightKg = 0,
  });

  final GarmentType garmentType;
  final PricingMode mode;
  double quantity;
  double weightKg;

  /// Pour l'affichage + le calcul d'estimation : retourne la valeur
  /// non-nulle (quantity en mode pièce, weightKg en mode kilo).
  double get effectiveAmount =>
      mode == PricingMode.perPiece ? quantity : weightKg;

  bool get isEmpty => effectiveAmount <= 0;
}

class OrderDraftProvider extends ChangeNotifier {
  OrderDraftProvider({
    required OrderRepository repository,
    required CatalogProvider catalogProvider,
  })  : _repository = repository,
        _catalogProvider = catalogProvider;

  final OrderRepository _repository;
  final CatalogProvider _catalogProvider;

  // État du brouillon — clé = garment type id.
  final Map<int, DraftLine> _lines = {};
  DateTime? _pickupAt;
  String _notes = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  List<DraftLine> get lines =>
      _lines.values.where((l) => !l.isEmpty).toList();
  int get lineCount => lines.length;
  DateTime? get pickupAt => _pickupAt;
  String get notes => _notes;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  /// Minimum autorisé par le backend pour un pickup — 2h dans le futur.
  /// On ajoute 5min de marge pour couvrir la latence réseau.
  DateTime get minimumPickupTime =>
      DateTime.now().add(const Duration(hours: 2, minutes: 5));

  /// Estimation du total en XAF calculée côté client. À afficher avec
  /// une mention "estimation" car Odoo peut appliquer des arrondis ou
  /// des règles promo qu'on ne connait pas ici.
  double get estimatedTotal {
    double total = 0;
    for (final line in lines) {
      final rule = _catalogProvider.findPriceFor(
        line.garmentType,
        material: line.garmentType.defaultMaterial,
      );
      if (rule == null) continue;
      total += rule.price * line.effectiveAmount;
    }
    return total;
  }

  bool get hasLines => lines.isNotEmpty;
  bool get canSubmit => hasLines && _pickupAt != null && !_isSubmitting;

  /// Incrémente la quantité d'un article. Crée la ligne si nécessaire.
  /// En mode pièce → +1 pièce, en mode kilo → +0.5 kg.
  void addItem(GarmentType type) {
    final existing = _lines[type.id];
    final mode = _resolveMode(type);
    if (existing == null) {
      _lines[type.id] = DraftLine(
        garmentType: type,
        mode: mode,
        quantity: mode == PricingMode.perPiece ? 1 : 0,
        weightKg: mode == PricingMode.perKg ? 0.5 : 0,
      );
    } else {
      if (mode == PricingMode.perPiece) {
        existing.quantity += 1;
      } else {
        existing.weightKg += 0.5;
      }
    }
    notifyListeners();
  }

  /// Décrémente — si on tombe à 0, on supprime la ligne entièrement.
  void removeItem(GarmentType type) {
    final existing = _lines[type.id];
    if (existing == null) return;
    if (existing.mode == PricingMode.perPiece) {
      existing.quantity -= 1;
    } else {
      existing.weightKg -= 0.5;
    }
    if (existing.isEmpty) _lines.remove(type.id);
    notifyListeners();
  }

  /// Retourne la quantité actuelle (pièce ou kg) pour un type donné,
  /// 0 si pas encore dans le brouillon.
  double quantityFor(GarmentType type) =>
      _lines[type.id]?.effectiveAmount ?? 0;

  void setPickupAt(DateTime when) {
    _pickupAt = when;
    notifyListeners();
  }

  void setNotes(String value) {
    _notes = value;
    // Pas de notifyListeners : c'est un TextField contrôlé, il n'a pas
    // besoin qu'on relance un rebuild à chaque frappe.
  }

  /// Soumet la commande au backend. Enchaîne :
  ///   1. POST /orders           → récupère l'id de la commande.
  ///   2. POST /appointments     → programme le pickup au créneau choisi.
  /// [subscriptionId] : si le client a un abonnement actif, passer son id
  /// pour lier la commande ET le rendez-vous à l'abonnement dans Odoo.
  /// Si le POST appointments échoue, la commande existe déjà côté Odoo —
  /// on retourne quand même l'Order et on log l'erreur. L'utilisateur
  /// pourra re-programmer depuis l'écran détail plus tard.
  Future<Order?> submit({int? subscriptionId}) async {
    if (!canSubmit) return null;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = CreateOrderRequest(
        lines: lines
            .map((l) => CreateOrderLine(
                  garmentTypeId: l.garmentType.id,
                  quantity: l.mode == PricingMode.perPiece ? l.quantity : null,
                  weightKg: l.mode == PricingMode.perKg ? l.weightKg : null,
                ))
            .toList(),
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        subscriptionId: subscriptionId,
      );

      final order = await _repository.createOrder(request);

      try {
        await _repository.schedulePickup(
          orderId: order.id,
          scheduledFrom: _pickupAt!,
          subscriptionId: subscriptionId,
        );
      } on ApiException catch (e) {
        // La commande est créée, mais le pickup a échoué. On ne bloque
        // pas l'utilisateur — on l'emmène sur l'écran confirmé et on
        // log pour diag.
        if (kDebugMode) {
          debugPrint('[OrderDraft] schedulePickup failed: ${e.message}');
        }
      }
      return order;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Reset complet — à appeler après confirmation ET quand l'utilisateur
  /// quitte le flux sans valider (back depuis /order/new/garments).
  void reset() {
    _lines.clear();
    _pickupAt = null;
    _notes = '';
    _errorMessage = null;
    _isSubmitting = false;
    notifyListeners();
  }

  /// Détermine le mode de tarification applicable à un type :
  /// perPiece si c'est un article spécial OU si la rule matchée est
  /// elle-même en perPiece, sinon perKg.
  PricingMode _resolveMode(GarmentType type) {
    if (type.isSpecialItem) return PricingMode.perPiece;
    final rule = _catalogProvider.findPriceFor(type);
    return rule?.mode ?? PricingMode.perPiece;
  }
}
