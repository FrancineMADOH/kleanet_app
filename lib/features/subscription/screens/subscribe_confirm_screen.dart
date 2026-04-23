// Écran de confirmation de souscription (Écran 18 du plan).
//
// Reçoit un [SubscriptionPlan] via GoRouter `extra`. Si quelqu'un navigue
// directement ici sans `extra`, le redirect de la route renvoie sur /subscription.
//
// Comportement :
//   - Affiche le récapitulatif du plan choisi (prix, kg, pièces, pickups).
//   - "Confirmer" → appelle SubscriptionProvider.subscribe(planId).
//   - Succès → pop + retour au hub (qui affiche maintenant le dashboard).
//   - Erreur (ex: 409 ALREADY_SUBSCRIBED) → SnackBar d'erreur, reste sur l'écran.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';
import 'subscription_hub_screen.dart' show SubscriptionSectionLabel;

class SubscribeConfirmScreen extends StatelessWidget {
  const SubscribeConfirmScreen({super.key, required this.plan});

  final SubscriptionPlan plan;

  Future<void> _confirm(BuildContext context) async {
    final provider = context.read<SubscriptionProvider>();
    final success = await provider.subscribe(plan.id);

    if (!context.mounted) return;

    if (success) {
      // Pop de cet écran ET de PlansScreen → retour au hub avec dashboard.
      context.go(Routes.subscription);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.subscribeError ?? 'Erreur de souscription.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmer l\'abonnement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // En-tête plan.
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  plan.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${CurrencyUtils.formatXAF(plan.recurringFee)} ${plan.billingCycle.label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                // Récapitulatif des inclusions.
                const SubscriptionSectionLabel('Ce qui est inclus'),
                const SizedBox(height: 12),
                _SummaryCard(
                  rows: [
                    ('Poids inclus',
                        '${plan.includedWeightKg.toStringAsFixed(0)} kg'),
                    ('Pièces incluses',
                        '${plan.includedPieces.toStringAsFixed(0)} pièces'),
                    ('Pickups / semaine',
                        '${plan.includedPickupsPerWeek}'),
                    ('Surplus au-delà du quota',
                        '${CurrencyUtils.formatXAF(plan.overagePricePerKg)} / kg'),
                  ],
                ),
                const SizedBox(height: 24),
                // Note paiement.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Le paiement s\'effectue à la livraison (cash ou MoMo). '
                          'Aucun prélèvement automatique.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bouton de confirmation fixé en bas.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      provider.isSubscribing ? null : () => _confirm(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: provider.isSubscribing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirmer l\'abonnement',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows.indexed.map((entry) {
          final (i, row) = entry;
          return Column(
            children: [
              if (i > 0)
                const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
