// Timeline verticale du statut d'une commande.
//
// Affiche les 4 étapes du cycle de vie client en colonne :
//   received → processing → ready_for_pickup → delivered
//
// Note : le backend expose aussi `pending` (commande créée mais pas
// encore ramassée). Pour l'UX on le fusionne avec `received` — tant
// que le linge n'est pas collecté, on considère la commande "à venir".
// Si `currentStatus == pending`, on affiche l'étape `received` comme
// courante (pas encore cochée).
//
// Le rendu adapte chaque étape selon sa position par rapport au
// statut courant :
//   - étape passée   : cercle plein vert + label en primary
//   - étape courante : cercle plein primary + halo + label bold
//   - étape future   : cercle vide gris + label secondary
//
// Le statut `cancelled` est un cas spécial — on affiche la timeline
// barrée en rouge avec un badge "Annulée" en tête.

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../models/order_models.dart';

/// Ordre canonique des étapes — l'index dans cette liste définit
/// la position dans la timeline. `pending` et `cancelled` n'y figurent pas.
const _timelineSteps = <OrderStatus>[
  OrderStatus.received,
  OrderStatus.processing,
  OrderStatus.readyForPickup,
  OrderStatus.delivered,
];

class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    this.dateReceived,
    this.dateReady,
  });

  final OrderStatus currentStatus;
  final DateTime? dateReceived;
  final DateTime? dateReady;

  @override
  Widget build(BuildContext context) {
    if (currentStatus == OrderStatus.cancelled) {
      return _CancelledBanner();
    }

    // `pending` est fusionné avec `received` pour l'affichage : on
    // considère que la commande est "en attente de ramassage" sur
    // l'étape Reçue (index 0, non cochée).
    final effectiveStatus = currentStatus == OrderStatus.pending
        ? OrderStatus.received
        : currentStatus;
    final currentIndex = _timelineSteps.indexOf(effectiveStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_timelineSteps.length, (i) {
        final step = _timelineSteps[i];
        final state = i < currentIndex
            ? _StepState.past
            : (i == currentIndex ? _StepState.current : _StepState.future);
        return _TimelineRow(
          step: step,
          state: state,
          isFirst: i == 0,
          isLast: i == _timelineSteps.length - 1,
          timestamp: _timestampFor(step),
        );
      }),
    );
  }

  /// Associe un timestamp aux étapes pour lesquelles l'API nous donne
  /// une date. Les autres restent sans date — l'utilisateur verra
  /// juste le label sans ligne supplémentaire.
  DateTime? _timestampFor(OrderStatus step) {
    switch (step) {
      case OrderStatus.received:
        return dateReceived;
      case OrderStatus.readyForPickup:
        return dateReady;
      default:
        return null;
    }
  }
}

enum _StepState { past, current, future }

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.state,
    required this.isFirst,
    required this.isLast,
    required this.timestamp,
  });

  final OrderStatus step;
  final _StepState state;
  final bool isFirst;
  final bool isLast;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(state);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colonne gauche : cercle + lignes verticales de connexion.
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Ligne du haut (vide pour le premier item).
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : (state == _StepState.future
                            ? AppColors.border
                            : AppColors.success),
                  ),
                ),
                _StepDot(state: state),
                // Ligne du bas (vide pour le dernier item).
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (state == _StepState.past
                            ? AppColors.success
                            : AppColors.border),
                  ),
                ),
              ],
            ),
          ),
          // Colonne droite : label + timestamp.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: state == _StepState.current
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: colors.label,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(timestamp!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TimelineColors _colorsFor(_StepState state) => switch (state) {
        _StepState.past => const _TimelineColors(
            dot: AppColors.success,
            label: AppColors.textPrimary,
          ),
        _StepState.current => const _TimelineColors(
            dot: AppColors.primary,
            label: AppColors.primary,
          ),
        _StepState.future => const _TimelineColors(
            dot: AppColors.border,
            label: AppColors.textSecondary,
          ),
      };

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final d = '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
    final h = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$d à $h';
  }
}

class _TimelineColors {
  const _TimelineColors({required this.dot, required this.label});
  final Color dot;
  final Color label;
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.state});
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    // L'étape courante reçoit un halo semi-transparent pour attirer
    // l'œil. Les autres sont des cercles pleins ou vides simples.
    if (state == _StepState.current) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    final filled = state == _StepState.past;
    return Container(
      width: 18,
      height: 18,
      decoration: ShapeDecoration(
        color: filled ? AppColors.success : Colors.white,
        shape: CircleBorder(
          side: BorderSide(
            color: filled ? AppColors.success : AppColors.border,
            width: 2,
          ),
        ),
      ),
      child: filled
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel, color: AppColors.error),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Commande annulée',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
