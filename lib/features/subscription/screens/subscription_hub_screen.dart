// Écran pivot abonnement (Écrans 16 / 16-B du plan).
//
// Deux affichages possibles selon l'état du provider :
//   - Sans abonnement actif → page de vente avec bouton "Voir les plans".
//   - Avec abonnement actif → dashboard avec barres de progression.
//
// Le provider est scoped à la route /subscription — instancié dans le
// builder GoRouter, disposé automatiquement à la sortie.

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
    if (provider.subscriptionError != null && !provider.isSubscribed) {
      return ErrorState(
        message: provider.subscriptionError!,
        onRetry: _refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: provider.isSubscribed
          ? _Dashboard(subscription: provider.subscription!)
          : const _SalesPage(),
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
              Text(
                subscription.planName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
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

