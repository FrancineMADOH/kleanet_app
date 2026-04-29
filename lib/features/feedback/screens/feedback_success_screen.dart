// Écran de confirmation après soumission d'un feedback — SUPPORT-02.
//
// Affiché via context.go(Routes.feedbackSuccess) depuis FeedbackFormScreen
// quand FeedbackProvider.submitted passe à true.
// Utilise go() (pas push()) pour remplacer le formulaire dans le stack et
// bloquer le retour arrière vers un formulaire déjà soumis.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';

/// Confirmation visuelle après un feedback soumis avec succès.
/// Le bouton "Voir mes commandes" renvoie sur /orders (liste des commandes).
class FeedbackSuccessScreen extends StatelessWidget {
  const FeedbackSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merci !'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // On masque le bouton retour — l'utilisateur ne doit pas revenir
        // sur le formulaire déjà soumis.
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: AppColors.success,
              ),
              const SizedBox(height: 24),
              const Text(
                'Merci pour votre avis !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre retour nous aide à améliorer Kleanet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(Routes.orders),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Voir mes commandes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
