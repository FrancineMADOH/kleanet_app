// Widget d'état erreur réutilisable — icône nuage + message + bouton retry.
//
// Utilisé dans tous les écrans qui chargent des données depuis l'API :
//   - OrdersListScreen, SubscriptionHubScreen, PlansScreen, …
//
// Le widget est scrollable (Center dans un ListView) pour que
// RefreshIndicator puisse se déclencher même en état d'erreur.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Affiche une icône de déconnexion, un [message] d'erreur centré, et un
/// bouton "Réessayer" qui déclenche [onRetry].
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
