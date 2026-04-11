// Étape 3/3 — récapitulatif avant envoi.
//
// Affiche toutes les lignes + le créneau + les notes + le total estimé.
// Au clic "Confirmer" on appelle draft.submit() et on navigue vers
// l'écran confirmé avec l'ID de la commande passé en extra state.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../providers/order_draft_provider.dart';

class NewOrderSummaryScreen extends StatelessWidget {
  const NewOrderSummaryScreen({super.key});

  Future<void> _confirm(BuildContext context) async {
    final draft = context.read<OrderDraftProvider>();
    final order = await draft.submit();
    if (!context.mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.errorMessage ?? 'Impossible d\'envoyer la commande.',
          ),
        ),
      );
      return;
    }
    // Succès : on passe la commande en extra et on bascule sur la
    // confirmation. La route est "replace" pour éviter que le bouton
    // back ramène sur le récap (ce serait un double-submit en puissance).
    context.go(Routes.newOrderDone, extra: order);
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OrderDraftProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Récapitulatif'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Articles (${draft.lineCount})'),
          ...draft.lines.map((l) => _LineRow(line: l)),
          const SizedBox(height: 16),
          _SectionTitle('Collecte'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule, color: AppColors.primary),
              title: Text(
                draft.pickupAt == null
                    ? 'Non défini'
                    : _formatPickup(draft.pickupAt!),
              ),
              subtitle: draft.notes.isEmpty
                  ? const Text('Pas d\'instructions')
                  : Text(draft.notes),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle('Total estimé'),
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Montant à régler à la livraison',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatXAF(draft.estimatedTotal),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le total définitif sera confirmé après réception de vos articles.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  draft.canSubmit ? () => _confirm(context) : null,
              child: draft.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Confirmer la commande'),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatPickup(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final h = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$d à $h';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final DraftLine line;
  @override
  Widget build(BuildContext context) {
    final amount = line.effectiveAmount;
    final unit = line.mode.unitLabel;
    final qtyLabel = amount == amount.roundToDouble()
        ? '${amount.toInt()} $unit'
        : '${amount.toStringAsFixed(1)} $unit';
    return Card(
      child: ListTile(
        title: Text(line.garmentType.name),
        subtitle: Text(qtyLabel),
      ),
    );
  }
}
