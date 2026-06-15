// Écran de confirmation de souscription (Écran 18 du plan).
//
// Reçoit un [SubscriptionPlan] soit via le callback [onSuccess] / [onBack]
// (mode embarqué dans l'onglet Abonnement), soit via GoRouter `extra` (route
// autonome). Si quelqu'un navigue directement ici sans `extra`, le redirect
// de la route renvoie sur /subscription.
//
// Comportement :
//   - Affiche le récapitulatif du plan choisi (prix, kg, pièces, pickups).
//   - "Confirmer" → appelle SubscriptionProvider.subscribe(planId).
//   - Succès → appelle onSuccess (mode onglet) ou context.go(Routes.subscription).
//   - Erreur (ex: 409 ALREADY_SUBSCRIBED) → SnackBar d'erreur, reste sur l'écran.
//
// UX améliorée (StatefulWidget) :
//   - Le bouton disparaît dès le premier tap (_submitted = true) ; un message
//     de confirmation inline remplace immédiatement le CTA sans attendre la
//     réponse réseau → l'utilisateur reçoit un feedback dans la même frame.
//   - En cas d'erreur API, _submitted repasse à false : le bouton réapparaît
//     pour permettre une nouvelle tentative, et un SnackBar décrit l'erreur.
//
// Guard : si un abonnement existe déjà au montage, redirige vers le hub via
// onBack pour éviter une double souscription.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/currency_utils.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_provider.dart';
import 'subscription_hub_screen.dart' show SubscriptionSectionLabel;

class SubscribeConfirmScreen extends StatefulWidget {
  const SubscribeConfirmScreen({
    super.key,
    this.plan,
    this.onSuccess,
    this.onBack,
    this.embedded = false,
    this.isChangingPlan = false,
    this.currentPlanName,
  });

  /// Plan sélectionné — nullable en mode embarqué (IndexedStack stable).
  /// Si null, l'écran retourne un SizedBox vide sans rien afficher.
  final SubscriptionPlan? plan;

  /// Appelé après une souscription réussie — le parent revient au hub qui
  /// affiche alors _PendingPage. Fallback GoRouter si null.
  final VoidCallback? onSuccess;

  /// Appelé quand l'utilisateur appuie sur le bouton retour de l'AppBar.
  /// Fourni uniquement en mode embarqué (l'onglet Abonnement de HomeScreen).
  final VoidCallback? onBack;

  /// Quand true : l'écran est monté dans l'IndexedStack de HomeScreen —
  /// pas de Scaffold propre, l'AppBar parent gère titre et navigation.
  final bool embedded;

  /// Quand true : l'utilisateur change son plan actif (pas une première
  /// souscription) — le guard anti-double-souscription est désactivé et
  /// un bandeau d'avertissement remplace/complémente le récapitulatif.
  final bool isChangingPlan;

  /// Nom du plan actuel — affiché dans le bandeau de changement.
  final String? currentPlanName;

  @override
  State<SubscribeConfirmScreen> createState() => _SubscribeConfirmScreenState();
}

class _SubscribeConfirmScreenState extends State<SubscribeConfirmScreen> {
  // Passe à true dès le premier tap sur "Confirmer" — le bouton disparaît
  // immédiatement dans la même frame et est remplacé par le message inline.
  // Repasse à false uniquement si l'appel API échoue, pour réafficher le bouton.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Guard anti-double-souscription — désactivé en mode changement de plan
    // (isChangingPlan = true) où l'abonnement existant est volontaire.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isChangingPlan) return;
      final provider = context.read<SubscriptionProvider>();
      if (provider.subscription != null) {
        widget.onBack?.call();
      }
    });
  }

  @override
  void didUpdateWidget(SubscribeConfirmScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Réinitialiser _submitted quand le plan change — l'IndexedStack conserve
    // l'instance en vie entre les sélections et _submitted = true d'une
    // confirmation précédente masquerait le bouton sur le nouveau plan.
    if (oldWidget.plan?.id != widget.plan?.id) {
      setState(() => _submitted = false);
    }
  }

  Future<void> _confirm() async {
    // 1. Masquer le bouton immédiatement — feedback instantané pour l'utilisateur.
    setState(() => _submitted = true);

    final provider = context.read<SubscriptionProvider>();

    // 2. Appel API en arrière-plan.
    final success = await provider.subscribe(widget.plan!.id);

    if (!mounted) return;

    if (success) {
      // 3. Succès → retour au hub (callback inline prioritaire, GoRouter en fallback).
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        context.go(Routes.subscription);
      }
    } else {
      // 4. Erreur → réafficher le bouton + SnackBar descriptif.
      setState(() => _submitted = false);
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
    // Slot vide dans l'IndexedStack quand aucun plan n'a encore été sélectionné.
    if (widget.plan == null) return const SizedBox.shrink();

    final content = _buildContent();

    // Mode embarqué : pas de Scaffold, le parent (HomeScreen) gère AppBar + nav.
    if (widget.embedded) return content;

    // Mode route autonome : Scaffold complet avec bottom nav.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChangingPlan
            ? 'Confirmer le changement'
            : 'Confirmer l\'abonnement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: widget.onBack != null
            ? BackButton(onPressed: widget.onBack, color: Colors.white)
            : null,
        automaticallyImplyLeading: widget.onBack == null,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      body: content,
    );
  }

  /// Contenu partagé entre mode embarqué et mode autonome.
  Widget _buildContent() {
    final plan = widget.plan!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Bandeau changement de plan — affiché uniquement en mode changement.
              if (widget.isChangingPlan && widget.currentPlanName != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.swap_horiz,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Votre plan "${widget.currentPlanName}" sera remplacé '
                          'dès confirmation de votre paiement.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // En-tête plan.
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium,
                      size: 48, color: AppColors.primary),
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
              const SubscriptionSectionLabel('Ce qui est inclus'),
              const SizedBox(height: 12),
              _SummaryCard(
                rows: [
                  ('Poids inclus',
                      '${plan.includedWeightKg.toStringAsFixed(0)} kg'),
                  ('Pièces incluses',
                      '${plan.includedPieces.toStringAsFixed(0)} pièces'),
                  ('Pickups / semaine', '${plan.includedPickupsPerWeek}'),
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
        // Zone CTA fixée en bas : bouton OU message de confirmation inline.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                _submitted ? _SubmittedConfirmation() : _ConfirmButton(onTap: _confirm),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// CTA : bouton "Confirmer l'abonnement"
// ----------------------------------------------------------------

/// Bouton principal affiché tant que l'utilisateur n'a pas encore tapé.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirmer l\'abonnement',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Message de confirmation inline (affiché après le tap)
// ----------------------------------------------------------------

/// Remplace le bouton immédiatement après le premier tap.
/// Informe l'utilisateur que la demande est bien en cours de traitement
/// sans qu'il ait à attendre la réponse réseau.
class _SubmittedConfirmation extends StatelessWidget {
  const _SubmittedConfirmation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // Fond teinté warning, identique au style _OverageNote du hub.
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône sablier — signal visuel d'attente.
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.hourglass_top_rounded,
              size: 22,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre.
                Text(
                  'Demande envoyée !',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(height: 4),
                // Corps.
                Text(
                  'Notre équipe vous contactera pour confirmer la réception '
                  'du paiement et activer votre abonnement.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    height: 1.4,
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

// ----------------------------------------------------------------
// Récapitulatif du plan (tableau lignes / valeurs)
// ----------------------------------------------------------------

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
