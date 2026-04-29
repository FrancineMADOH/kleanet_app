// Écran de formulaire de feedback — notation d'une commande livrée.
//
// Monté via GoRouter `/feedback/:orderId` avec un ChangeNotifierProvider
// factory qui instancie FeedbackProvider. L'écran est un StatefulWidget
// pour accéder au BuildContext dans _submit après un await.
//
// Flux utilisateur :
//   1. Sélectionner une note (1-5 étoiles) — obligatoire
//   2. Indiquer si on recommande Kleanet — optionnel
//   3. Rédiger un commentaire libre — optionnel
//   4. Valider → POST /feedback → navigation vers /feedback/success

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../providers/feedback_provider.dart';
import '../repositories/feedback_repository.dart';

/// Formulaire de notation pour une commande livrée.
///
/// [orderId] est l'identifiant Odoo de la commande.
/// [orderReference] est la référence lisible (ex: "LAU/2026/00001") —
/// affichée en sous-titre pour que l'utilisateur sache quelle commande
/// il note. Peut être null si non disponible (deep link).
class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({
    super.key,
    required this.orderId,
    this.orderReference,
  });

  /// Identifiant Odoo de la commande à noter.
  final int orderId;

  /// Référence lisible de la commande — affichage seulement, peut être null.
  final String? orderReference;

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  /// Envoie le feedback via le provider puis navigue vers l'écran succès.
  ///
  /// Le guard `!mounted` est indispensable ici : un await est effectué
  /// à l'intérieur, et le widget peut avoir été détruit pendant ce temps.
  Future<void> _submit() async {
    final provider = context.read<FeedbackProvider>();
    final repo = FeedbackRepository(apiClient: context.read<ApiClient>());
    await provider.submit(repo, widget.orderId);
    if (!mounted) return;
    if (provider.submitted) {
      context.go(Routes.feedbackSuccess);
    }
  }

  /// Retourne le libellé associé à une note de 1 à 5.
  static String _ratingLabel(int r) => switch (r) {
        1 => 'Mauvaise',
        2 => 'Passable',
        3 => 'Correcte',
        4 => 'Bonne',
        _ => 'Excellent !',
      };

  @override
  Widget build(BuildContext context) {
    // context.watch écoute les changements du provider pour reconstruire l'UI
    // (état des étoiles, spinner, message d'erreur, etc.)
    final provider = context.watch<FeedbackProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laisser un avis'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Référence de commande (si disponible) ---
            if (widget.orderReference != null) ...[
              Text(
                widget.orderReference!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // --- Section étoiles ---
            const Text(
              'Votre note *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                // index va de 0 à 4, on compare avec (index + 1) pour 1 à 5
                final starValue = index + 1;
                final isFilled =
                    provider.rating != null && starValue <= provider.rating!;
                return IconButton(
                  onPressed: () =>
                      context.read<FeedbackProvider>().setRating(starValue),
                  icon: Icon(
                    isFilled ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: 36,
                  ),
                  // Padding minimal pour que les 5 étoiles tiennent sur une ligne
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                );
              }),
            ),
            const SizedBox(height: 4),
            // Label dynamique sous les étoiles — n'apparaît qu'après un choix
            if (provider.rating != null) ...[
              Center(
                child: Text(
                  _ratingLabel(provider.rating!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent1,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // --- Section recommandation ---
            const Text(
              'Recommanderiez-vous Kleanet ?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RecommendButton(
                    label: '👍 Oui',
                    value: true,
                    selected: provider.wouldRecommend == true,
                    onTap: () => context
                        .read<FeedbackProvider>()
                        .setWouldRecommend(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RecommendButton(
                    label: '👎 Non',
                    value: false,
                    selected: provider.wouldRecommend == false,
                    onTap: () => context
                        .read<FeedbackProvider>()
                        .setWouldRecommend(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Commentaire optionnel ---
            const Text(
              'Commentaire (optionnel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              maxLength: 500,
              onChanged: (v) =>
                  context.read<FeedbackProvider>().setComment(v),
              decoration: const InputDecoration(
                hintText: 'Partagez votre expérience…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // --- Bouton soumettre ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Désactivé si la note n'a pas encore été sélectionnée
                // ou si une soumission est déjà en cours.
                onPressed: provider.canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: provider.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Envoyer mon avis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            // --- Message d'erreur ---
            if (provider.error != null) ...[
              const SizedBox(height: 12),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton de sélection "Oui / Non" pour la recommandation.
///
/// Affiche un style plein (fond primary, texte blanc) si [selected] est true,
/// ou un style vide (fond blanc, bordure grise) sinon.
class _RecommendButton extends StatelessWidget {
  const _RecommendButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  /// Texte affiché dans le bouton (ex: "👍 Oui").
  final String label;

  /// Valeur booléenne associée à ce bouton (non utilisée directement
  /// dans le widget, portée pour clarté dans l'appelant).
  final bool value;

  /// true si ce bouton est actuellement sélectionné.
  final bool selected;

  /// Callback déclenché lors d'un tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          // Style sélectionné : fond primary ; non sélectionné : fond blanc
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
