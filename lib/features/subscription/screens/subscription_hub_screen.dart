// Écran pivot abonnement (Écrans 16 / 16-B du plan).
//
// Trois affichages possibles selon l'état du provider :
//   - Sans abonnement (subscription == null) → page de vente.
//   - Abonnement expiré/annulé/en pause (subscription != null && !isSubscribed)
//     → écran de renouvellement avec contexte du plan précédent.
//   - Abonnement actif → dashboard avec badge statut + barres de progression
//     + bouton "Planifier un pickup".

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';

class SubscriptionHubScreen extends StatefulWidget {
  const SubscriptionHubScreen({super.key});

  @override
  State<SubscriptionHubScreen> createState() => _SubscriptionHubScreenState();
}

class _SubscriptionHubScreenState extends State<SubscriptionHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadSubscription();
    });
  }

  Future<void> _refresh() =>
      context.read<SubscriptionProvider>().loadSubscription();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon abonnement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(SubscriptionProvider provider) {
    if (provider.isLoadingSubscription) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.subscriptionError != null && provider.subscription == null) {
      return ErrorState(
        message: provider.subscriptionError!,
        onRetry: _refresh,
      );
    }

    final sub = provider.subscription;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: switch (sub?.state) {
        // Abonnement actif → dashboard.
        SubscriptionState.active => _Dashboard(subscription: sub!),
        // En attente de validation admin → écran d'attente.
        SubscriptionState.pending => _PendingPage(subscription: sub!),
        // Expiré / annulé / en pause → renouvellement.
        SubscriptionState.paused ||
        SubscriptionState.cancelled =>
          _RenewalPage(subscription: sub!),
        // Jamais eu d'abonnement → page de vente.
        null => const _SalesPage(),
      },
    );
  }
}

// ----------------------------------------------------------------
// Page de vente (sans abonnement)
// ----------------------------------------------------------------

class _SalesPage extends StatelessWidget {
  const _SalesPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        // Illustration / icône de présentation.
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.workspace_premium,
            size: 64,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Lavez plus, payez moins',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Avec un abonnement Kleanet, profitez d\'un tarif réduit au kilo, '
          'de pickups dédiés chaque semaine et d\'une priorité de traitement.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        // Avantages clés — 3 bullets.
        ..._benefits.map((b) => _BenefitRow(icon: b.$1, label: b.$2)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => context.push(Routes.subscriptionPlans),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Voir les plans',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  static const _benefits = [
    (Icons.local_offer_outlined, 'Tarif au kilo négocié, sans surprise'),
    (Icons.calendar_month_outlined, 'Pickups récurrents planifiés à l\'avance'),
    (Icons.bolt_outlined, 'Traitement prioritaire au hub'),
  ];
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent1.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent1, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Dashboard (avec abonnement actif)
// ----------------------------------------------------------------

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.subscription});
  final ActiveSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final usage = subscription.usage;
    // Ratio poids consommé / inclus — clampé à [0,1] pour la barre.
    final weightRatio = subscription.includedWeightKg > 0
        ? (usage.weightUsedKg / subscription.includedWeightKg).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte header : nom du plan + référence + date de fin.
        _PlanHeaderCard(subscription: subscription),
        const SizedBox(height: 16),
        const SubscriptionSectionLabel('Consommation ce mois'),
        const SizedBox(height: 8),
        // Barre poids.
        _UsageBar(
          label: 'Poids',
          used: '${usage.weightUsedKg.toStringAsFixed(1)} kg',
          remaining:
              '${usage.remainingWeightKg.toStringAsFixed(1)} kg restants',
          ratio: weightRatio,
          color: _barColor(weightRatio),
        ),
        const SizedBox(height: 12),
        // Barre pièces.
        _UsageBar(
          label: 'Pièces',
          used: '${(subscription.includedPieces - usage.remainingPieces).toStringAsFixed(0)} pcs',
          remaining: '${usage.remainingPieces.toStringAsFixed(0)} pièces restantes',
          ratio: subscription.includedPieces > 0
              ? ((subscription.includedPieces - usage.remainingPieces) / subscription.includedPieces).clamp(0.0, 1.0)
              : 0.0,
          color: _barColor(subscription.includedPieces > 0
              ? ((subscription.includedPieces - usage.remainingPieces) / subscription.includedPieces).clamp(0.0, 1.0)
              : 0.0),
        ),
        const SizedBox(height: 12),
        // Commandes ce mois.
        _InfoTile(
          icon: Icons.receipt_long,
          label: 'Commandes ce mois',
          value: '${usage.ordersThisPeriod}',
        ),
        const SizedBox(height: 12),
        // Pickups / semaine inclus.
        _InfoTile(
          icon: Icons.directions_bike,
          label: 'Pickups / semaine inclus',
          value: '${subscription.includedPickupsPerWeek}',
        ),
        const SizedBox(height: 16),
        // Note overage.
        _OverageNote(price: subscription.overagePricePerKg),
        const SizedBox(height: 24),
        // Bouton pickup — démarre le flux commande qui enchaîne
        // création + planification pickup (étapes 1 → 2 → 3).
        ElevatedButton.icon(
          onPressed: () => context.push(Routes.newOrder),
          icon: const Icon(Icons.directions_bike),
          label: const Text(
            'Planifier un pickup',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Vert < 70%, orange 70-90%, rouge > 90%.
  Color _barColor(double ratio) {
    if (ratio < 0.7) return AppColors.success;
    if (ratio < 0.9) return AppColors.warning;
    return AppColors.error;
  }
}

class _PlanHeaderCard extends StatelessWidget {
  const _PlanHeaderCard({required this.subscription});
  final ActiveSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subscription.planName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              _StateBadge(state: subscription.state),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subscription.reference,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyUtils.formatXAF(subscription.recurringFee)} ${subscription.billingCycle.label}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionSectionLabel extends StatelessWidget {
  const SubscriptionSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.label,
    required this.used,
    required this.remaining,
    required this.ratio,
    required this.color,
  });
  final String label;
  final String used;
  final String remaining;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                used,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text(
            remaining,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Badge statut (actif / en pause / annulé)
// ----------------------------------------------------------------

/// Pill coloré affiché dans la carte header pour indiquer clairement
/// si l'abonnement est en cours, suspendu ou terminé.
class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (state) {
      SubscriptionState.pending => (
          'En attente',
          AppColors.warning,
          Colors.white,
        ),
      SubscriptionState.active => (
          'Actif',
          AppColors.success,
          Colors.white,
        ),
      SubscriptionState.paused => (
          'En pause',
          AppColors.warning,
          Colors.white,
        ),
      SubscriptionState.cancelled => (
          'Annulé',
          AppColors.error,
          Colors.white,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Page d'attente (abonnement pending — paiement non encore validé)
// ----------------------------------------------------------------

/// Affiché quand le client vient de souscrire mais que l'admin n'a pas
/// encore confirmé la réception du paiement dans Odoo.
class _PendingPage extends StatelessWidget {
  const _PendingPage({required this.subscription});
  final ActiveSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 56,
              color: AppColors.warning,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Abonnement en attente de validation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Votre demande pour le plan "${subscription.planName}" a bien été reçue. '
          'Notre équipe va confirmer votre paiement et activer votre abonnement '
          'dans les plus brefs délais.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        // Rappel du plan souscrit.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _PendingRow(
                icon: Icons.workspace_premium,
                label: 'Plan choisi',
                value: subscription.planName,
              ),
              const Divider(height: 16, color: AppColors.border),
              _PendingRow(
                icon: Icons.payments_outlined,
                label: 'Montant',
                value:
                    '${CurrencyUtils.formatXAF(subscription.recurringFee)} ${subscription.billingCycle.label}',
              ),
              const Divider(height: 16, color: AppColors.border),
              _PendingRow(
                icon: Icons.tag,
                label: 'Référence',
                value: subscription.reference,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Note informative.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vous recevrez une confirmation dès que le paiement sera validé. '
                  'Tirez vers le bas pour rafraîchir.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// Page de renouvellement (abonnement expiré / annulé / en pause)
// ----------------------------------------------------------------

/// Affiché quand le client a déjà eu un abonnement mais qu'il n'est
/// plus actif — lui propose de reprendre avec son ancien plan en tête.
class _RenewalPage extends StatelessWidget {
  const _RenewalPage({required this.subscription});
  final ActiveSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (subscription.state) {
      SubscriptionState.paused => 'suspendu',
      SubscriptionState.cancelled => 'expiré',
      SubscriptionState.active || SubscriptionState.pending => '',
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 56,
              color: AppColors.warning,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Votre abonnement est $stateLabel',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Votre plan "${subscription.planName}" n\'est plus actif. '
          'Renouvelez ou choisissez un nouveau plan pour continuer '
          'à profiter de vos avantages.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        // Rappel de l'ancien plan.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.history, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ancien plan : ${subscription.planName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                CurrencyUtils.formatXAF(subscription.recurringFee),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.push(Routes.subscriptionPlans),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Renouveler mon abonnement',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
class _OverageNote extends StatelessWidget {
  const _OverageNote({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Au-delà du quota : ${CurrencyUtils.formatXAF(price)} / kg',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

