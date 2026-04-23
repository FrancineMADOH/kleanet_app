// Badge coloré pour le statut d'une commande.
//
// Utilisé à deux endroits :
//   - orders_list_screen.dart  → carte de liste
//   - order_detail_screen.dart → en-tête de détail
//
// La palette de couleurs est centralisée ici pour garantir la cohérence
// visuelle entre les deux écrans. Tout changement de couleur s'applique
// automatiquement aux deux.

import 'package:flutter/material.dart';

import '../../features/orders/models/order_models.dart';
import '../theme/app_colors.dart';

/// Pill coloré affichant le libellé court d'un [OrderStatus].
/// La couleur de fond et de texte s'adapte automatiquement au statut.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  final OrderStatus status;

  /// Taille de police — 12 pour le détail, 11 pour la liste (badge plus petit).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static (Color, Color) _palette(OrderStatus s) => switch (s) {
        OrderStatus.pending => (
            AppColors.warning.withValues(alpha: 0.15),
            AppColors.warning,
          ),
        OrderStatus.received => (
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary,
          ),
        OrderStatus.readyForPickup => (
            AppColors.accent1.withValues(alpha: 0.15),
            AppColors.accent1,
          ),
        OrderStatus.delivered => (
            AppColors.success.withValues(alpha: 0.15),
            AppColors.success,
          ),
        OrderStatus.cancelled => (
            AppColors.error.withValues(alpha: 0.1),
            AppColors.error,
          ),
      };
}
