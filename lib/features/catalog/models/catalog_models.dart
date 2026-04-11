// Modèles du catalogue Kleanet (types de vêtements + règles de prix).
//
// Le backend expose UN seul endpoint `/catalog/services` qui retourne
// un snapshot complet : {garment_types, pricing_rules, cached_at}.
// Pas d'endpoint séparé pour les matières — l'info matière est portée
// directement par les pricing rules (champ `material_name`).
//
// Ces modèles sont aussi sérialisés en JSON pour le cache persistant
// (SharedPreferences), d'où les toJson()/fromJson() symétriques.

/// Mode de tarification d'une règle.
/// - [perKg] : facturation au poids (vrac — ex: "Linge mixte 1000 XAF/kg")
/// - [perPiece] : facturation à la pièce (ex: "Chemise coton 1200 XAF/pièce")
enum PricingMode {
  perKg,
  perPiece;

  String toJson() => switch (this) {
        PricingMode.perKg => 'per_kg',
        PricingMode.perPiece => 'per_piece',
      };

  static PricingMode fromJson(String raw) => switch (raw) {
        'per_kg' => PricingMode.perKg,
        'per_piece' => PricingMode.perPiece,
        _ => throw FormatException('Unknown pricing mode: $raw'),
      };

  /// Libellé court pour affichage — "kg" ou "pièce".
  String get unitLabel => switch (this) {
        PricingMode.perKg => 'kg',
        PricingMode.perPiece => 'pièce',
      };
}

/// Type de vêtement (Chemise, Pantalon, Robe, Couette, …).
/// Ne contient PAS de prix — il faut joindre avec une [PricingRule]
/// (par `name` car le backend ne fournit pas de FK en clair).
class GarmentType {
  const GarmentType({
    required this.id,
    required this.name,
    required this.isSpecialItem,
    this.defaultMaterial,
  });

  final int id;
  final String name;
  final String? defaultMaterial;

  /// `true` pour les articles hors-vrac qui sortent des tarifs au kilo
  /// (couette, costume, robe de mariée, …) et passent toujours "à la pièce".
  final bool isSpecialItem;

  factory GarmentType.fromJson(Map<String, dynamic> json) => GarmentType(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        defaultMaterial: json['default_material'] as String?,
        isSpecialItem: json['is_special_item'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (defaultMaterial != null) 'default_material': defaultMaterial,
        'is_special_item': isSpecialItem,
      };
}

/// Règle de prix — peut cibler un type de vêtement et/ou une matière.
/// L'API renvoie les liens par NOM (pas par ID) : c'est une contrainte
/// du backend et ça limite les renommages côté Odoo, mais c'est ce qui
/// est exposé.
class PricingRule {
  const PricingRule({
    required this.id,
    required this.mode,
    required this.price,
    required this.currency,
    this.materialName,
    this.garmentTypeName,
  });

  final int id;
  final PricingMode mode;
  final String? materialName;
  final String? garmentTypeName;
  final double price;
  final String currency;

  factory PricingRule.fromJson(Map<String, dynamic> json) => PricingRule(
        id: (json['id'] as num).toInt(),
        mode: PricingMode.fromJson(json['mode'] as String),
        materialName: json['material_name'] as String?,
        garmentTypeName: json['garment_type_name'] as String?,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.toJson(),
        if (materialName != null) 'material_name': materialName,
        if (garmentTypeName != null) 'garment_type_name': garmentTypeName,
        'price': price,
        'currency': currency,
      };
}

/// Snapshot complet du catalogue : ce qui est stocké en cache et
/// diffusé par le provider à tous les écrans.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.garmentTypes,
    required this.pricingRules,
    required this.fetchedAt,
  });

  final List<GarmentType> garmentTypes;
  final List<PricingRule> pricingRules;

  /// Moment local où le snapshot a été récupéré (pas le `cached_at`
  /// backend — on veut mesurer la fraîcheur côté client).
  final DateTime fetchedAt;

  /// Retourne `true` si le snapshot dépasse l'âge [ttl] et doit être
  /// rafraîchi. Un snapshot "stale" reste utilisable (mode hors-ligne)
  /// mais le provider lance un refetch en parallèle.
  bool isStale(Duration ttl) =>
      DateTime.now().difference(fetchedAt) > ttl;

  factory CatalogSnapshot.fromApiJson(Map<String, dynamic> json) {
    final garments = (json['garment_types'] as List<dynamic>)
        .map((e) => GarmentType.fromJson(e as Map<String, dynamic>))
        .toList();
    final rules = (json['pricing_rules'] as List<dynamic>)
        .map((e) => PricingRule.fromJson(e as Map<String, dynamic>))
        .toList();
    return CatalogSnapshot(
      garmentTypes: garments,
      pricingRules: rules,
      fetchedAt: DateTime.now(),
    );
  }

  /// Sérialisation pour le cache SharedPreferences. Le `fetchedAt` est
  /// stocké en ISO 8601 pour rester lisible si on inspecte les prefs.
  Map<String, dynamic> toCacheJson() => {
        'garment_types': garmentTypes.map((g) => g.toJson()).toList(),
        'pricing_rules': pricingRules.map((p) => p.toJson()).toList(),
        'fetched_at': fetchedAt.toIso8601String(),
      };

  factory CatalogSnapshot.fromCacheJson(Map<String, dynamic> json) {
    return CatalogSnapshot(
      garmentTypes: (json['garment_types'] as List<dynamic>)
          .map((e) => GarmentType.fromJson(e as Map<String, dynamic>))
          .toList(),
      pricingRules: (json['pricing_rules'] as List<dynamic>)
          .map((e) => PricingRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }
}
