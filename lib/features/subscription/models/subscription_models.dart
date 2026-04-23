// Modèles Subscription — représente les réponses de :
//   GET  /catalog/plans        → List<SubscriptionPlan>
//   GET  /subscription/        → ActiveSubscription? (null si pas d'abonnement)
//   POST /subscription/        → ActiveSubscription (après souscription)
//
// Découpage :
//   - SubscriptionPlan     : un plan du catalogue (tarif + limites incluses)
//   - SubscriptionUsage    : consommation de la période en cours
//   - ActiveSubscription   : abonnement en cours du client

/// Cycle de facturation — mensuel ou hebdomadaire.
enum BillingCycle {
  monthly,
  weekly;

  static BillingCycle fromJson(String raw) => switch (raw) {
        'monthly' => BillingCycle.monthly,
        'weekly' => BillingCycle.weekly,
        _ => BillingCycle.monthly,
      };

  String get label => switch (this) {
        BillingCycle.monthly => 'par mois',
        BillingCycle.weekly => 'par semaine',
      };
}

/// Statut d'un abonnement actif.
enum SubscriptionState {
  active,
  paused,
  cancelled;

  static SubscriptionState fromJson(String raw) => switch (raw) {
        'active' => SubscriptionState.active,
        'paused' => SubscriptionState.paused,
        'cancelled' => SubscriptionState.cancelled,
        _ => SubscriptionState.active,
      };
}

/// Un plan proposé dans le catalogue — affiché sur l'écran de comparaison.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.segment,
    required this.billingCycle,
    required this.includedWeightKg,
    required this.includedPieces,
    required this.includedPickupsPerWeek,
    required this.recurringFee,
    required this.overagePricePerKg,
    required this.currency,
    required this.isRecommended,
    this.description,
    this.targetLabel,
  });

  final int id;
  final String name;
  final String segment; // 'residential' | 'business'
  final BillingCycle billingCycle;
  final double includedWeightKg;
  final double includedPieces;
  final int includedPickupsPerWeek;
  final double recurringFee;
  final double overagePricePerKg;
  final String currency;
  final bool isRecommended;
  final String? description;
  final String? targetLabel;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        segment: json['segment'] as String,
        billingCycle: BillingCycle.fromJson(json['billing_cycle'] as String),
        includedWeightKg: (json['included_weight_kg'] as num).toDouble(),
        includedPieces: (json['included_pieces'] as num).toDouble(),
        includedPickupsPerWeek:
            (json['included_pickups_per_week'] as num).toInt(),
        recurringFee: (json['recurring_fee'] as num).toDouble(),
        overagePricePerKg: (json['overage_price_per_kg'] as num).toDouble(),
        currency: json['currency'] as String,
        isRecommended: json['is_recommended'] as bool,
        description: json['description'] as String?,
        targetLabel: json['target_label'] as String?,
      );
}

/// Consommation de l'abonnement sur la période en cours.
class SubscriptionUsage {
  const SubscriptionUsage({
    required this.ordersThisPeriod,
    required this.weightUsedKg,
    required this.remainingWeightKg,
  });

  final int ordersThisPeriod;
  final double weightUsedKg;
  final double remainingWeightKg;

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) =>
      SubscriptionUsage(
        ordersThisPeriod: (json['orders_this_period'] as num).toInt(),
        weightUsedKg: (json['weight_used_kg'] as num).toDouble(),
        remainingWeightKg: (json['remaining_weight_kg'] as num).toDouble(),
      );
}

/// Abonnement actif du client — renvoyé par GET /subscription/ et
/// POST /subscription/. Contient les limites du plan + la consommation courante.
class ActiveSubscription {
  const ActiveSubscription({
    required this.id,
    required this.reference,
    required this.planName,
    required this.billingCycle,
    required this.includedWeightKg,
    required this.includedPieces,
    required this.includedPickupsPerWeek,
    required this.recurringFee,
    required this.overagePricePerKg,
    required this.currency,
    required this.startDate,
    required this.state,
    required this.usage,
    this.endDate,
  });

  final int id;
  final String reference;
  final String planName;
  final BillingCycle billingCycle;
  final double includedWeightKg;
  final double includedPieces;
  final int includedPickupsPerWeek;
  final double recurringFee;
  final double overagePricePerKg;
  final String currency;
  final String startDate;
  final String? endDate;
  final SubscriptionState state;
  final SubscriptionUsage usage;

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) =>
      ActiveSubscription(
        id: (json['id'] as num).toInt(),
        reference: json['reference'] as String,
        planName: json['plan_name'] as String,
        billingCycle: BillingCycle.fromJson(json['billing_cycle'] as String),
        includedWeightKg: (json['included_weight_kg'] as num).toDouble(),
        includedPieces: (json['included_pieces'] as num).toDouble(),
        includedPickupsPerWeek:
            (json['included_pickups_per_week'] as num).toInt(),
        recurringFee: (json['recurring_fee'] as num).toDouble(),
        overagePricePerKg: (json['overage_price_per_kg'] as num).toDouble(),
        currency: json['currency'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String?,
        state: SubscriptionState.fromJson(json['state'] as String),
        usage: SubscriptionUsage.fromJson(
            json['usage'] as Map<String, dynamic>),
      );
}
