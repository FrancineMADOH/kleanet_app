// Écran comparaison des plans (Écran 17 du plan).
//
// Charge la liste des plans via SubscriptionProvider.loadPlans() au montage.
// Chaque plan est affiché sous forme de carte avec ses caractéristiques.
// Les plans recommandés remontent en tête (tri fait dans le provider).
// "Choisir" → appelle onPlanSelected (mode embarqué) ou GoRouter (mode route).
//
// Callbacks :
//   onPlanSelected(plan) — le parent passe au sous-état confirm avec le plan choisi.
//   onBack             — le parent revient au hub sans GoRouter pop.
//
// Guard : si un abonnement existe déjà (pending/active/paused/cancelled),
// on redirige immédiatement vers le hub via onBack pour empêcher une double
// souscription (la vérification définitive reste côté API avec 409).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    this.onPlanSelected,
    this.onBack,
    this.embedded = false,
    this.isChangingPlan = false,
    this.currentPlanName,
  });

  /// Appelé quand l'utilisateur clique "Choisir ce plan" — le plan est transmis
  /// au parent (HomeScreen) qui gère la transition vers SubscribeConfirmScreen.
  final void Function(SubscriptionPlan plan)? onPlanSelected;

  /// Appelé quand l'utilisateur appuie sur le bouton retour de l'AppBar.
  /// Fourni uniquement en mode embarqué (l'onglet Abonnement de HomeScreen).
  final VoidCallback? onBack;

  /// Quand true : pas de Scaffold propre — l'AppBar de HomeScreen gère la nav.
  final bool embedded;

  /// Quand true : l'utilisateur change son plan actif — le guard est assoupli
  /// et le plan actuel est mis en évidence dans la liste.
  final bool isChangingPlan;

  /// Nom du plan actif — utilisé pour afficher le badge "Plan actuel".
  final String? currentPlanName;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<SubscriptionProvider>();
      // Guard : bloque l'accès aux plans si abonnement existant,
      // SAUF en mode changement de plan (isChangingPlan = true).
      if (provider.subscription != null && !widget.isChangingPlan) {
        widget.onBack?.call();
        return;
      }
      // Chargement lazy en mode standalone uniquement — en mode embarqué,
      // HomeScreen déclenche loadPlans() avant de basculer sur cet onglet.
      if (!widget.embedded &&
          provider.plans.isEmpty &&
          !provider.isLoadingPlans) {
        provider.loadPlans();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    // Mode embarqué : retourne le contenu directement, sans Scaffold.
    // L'AppBar et la BottomNavBar de HomeScreen gèrent la navigation.
    if (widget.embedded) return _buildBody(provider);

    // Mode route autonome : Scaffold complet avec bottom nav.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChangingPlan ? 'Changer de plan' : 'Choisir un plan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: widget.onBack != null
            ? BackButton(onPressed: widget.onBack, color: Colors.white)
            : null,
        automaticallyImplyLeading: widget.onBack == null,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: provider.plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PlanCard(
        plan: provider.plans[i],
        onPlanSelected: widget.onPlanSelected,
        // Badge "Plan actuel" si le nom correspond au plan de l'abonné.
        isCurrentPlan: widget.currentPlanName != null &&
            provider.plans[i].name == widget.currentPlanName,
      ),
    );
  }
}

// ----------------------------------------------------------------
// Carte plan
// ----------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    this.onPlanSelected,
    this.isCurrentPlan = false,
  });
  final SubscriptionPlan plan;
  // Callback transmis par PlansScreen pour déclencher la transition vers confirm.
  final void Function(SubscriptionPlan plan)? onPlanSelected;
  // Quand true : badge "Plan actuel" (cyan) à la place ou en plus de "Recommandé".
  final bool isCurrentPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan
              ? AppColors.accent1
              : plan.isRecommended
                  ? AppColors.primary
                  : AppColors.border,
          width: (isCurrentPlan || plan.isRecommended) ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badge "Plan actuel" (cyan) prioritaire sur "Recommandé" (bleu nuit).
          if (isCurrentPlan)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'Plan actuel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          else if (plan.isRecommended)
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
                // Bouton choisir → transition vers SubscribeConfirmScreen via callback.
                // onPlanSelected fourni par PlansScreen (transmis depuis HomeScreen).
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPlanSelected != null
                        ? () => onPlanSelected!(plan)
                        : null,
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

