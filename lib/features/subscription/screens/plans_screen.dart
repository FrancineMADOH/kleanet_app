// Écran comparaison des plans (Écran 17 du plan).
//
// Charge la liste des plans via SubscriptionProvider.loadPlans() au montage.
// Chaque plan est affiché sous forme de carte avec ses caractéristiques.
// Les plans recommandés remontent en tête (tri fait dans le provider).
// "Choisir" → navigue vers SubscribeConfirmScreen avec le plan en `extra`.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un plan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(SubscriptionProvider provider) {
    if (provider.isLoadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.plansError != null) {
      return ErrorState(
        message: provider.plansError!,
        onRetry: () => context.read<SubscriptionProvider>().loadPlans(),
      );
    }
    if (provider.plans.isEmpty) {
      return const Center(
        child: Text(
          'Aucun plan disponible pour le moment.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PlanCard(plan: provider.plans[i]),
    );
  }
}

// ----------------------------------------------------------------
// Carte plan
// ----------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isRecommended ? AppColors.primary : AppColors.border,
          width: plan.isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badge "Recommandé" sur les plans mis en avant.
          if (plan.isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'Recommandé',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + prix.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (plan.targetLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              plan.targetLabel!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtils.formatXAF(plan.recurringFee),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          plan.billingCycle.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (plan.description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    plan.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                // Caractéristiques incluses.
                _Feature(
                  icon: Icons.scale,
                  label: '${plan.includedWeightKg.toStringAsFixed(0)} kg inclus',
                ),
                const SizedBox(height: 6),
                _Feature(
                  icon: Icons.checkroom,
                  label:
                      '${plan.includedPieces.toStringAsFixed(0)} pièces incluses',
                ),
                const SizedBox(height: 6),
                _Feature(
                  icon: Icons.directions_bike,
                  label:
                      '${plan.includedPickupsPerWeek} pickup${plan.includedPickupsPerWeek > 1 ? 's' : ''} / semaine',
                ),
                const SizedBox(height: 6),
                _Feature(
                  icon: Icons.add_circle_outline,
                  label:
                      'Surplus : ${CurrencyUtils.formatXAF(plan.overagePricePerKg)} / kg',
                  muted: true,
                ),
                const SizedBox(height: 16),
                // Bouton choisir → écran de confirmation.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push(Routes.subscribeConfirm, extra: plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isRecommended
                          ? AppColors.primary
                          : Colors.white,
                      foregroundColor: plan.isRecommended
                          ? Colors.white
                          : AppColors.primary,
                      side: plan.isRecommended
                          ? null
                          : const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Choisir ce plan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label, this.muted = false});
  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.textSecondary : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 15, color: muted ? AppColors.textSecondary : AppColors.accent1),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

