// Barre de navigation persistante — réutilisée sur les écrans pushés
// (FAQ, détail commande, etc.) pour maintenir la cohérence de navigation.
//
// Le [currentIndex] indique l'onglet actif :
//   0 — Accueil, 1 — Commandes, 2 — Abonnement, 3 — Profil
//
// Comportement sur tap :
//   - Même onglet que le courant : contexte de retour via pop() si possible.
//   - Autre onglet : navigation directe vers la route racine de l'onglet.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.currentIndex});

  /// Indice de l'onglet mis en évidence (0 à 3).
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, index),
      selectedItemColor: AppColors.accent1,
      unselectedItemColor: AppColors.textSecondary,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Commandes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.workspace_premium_outlined),
          activeIcon: Icon(Icons.workspace_premium),
          label: 'Abonnement',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(Routes.home);
      case 1:
        context.go(Routes.orders);
      case 2:
        context.go(Routes.subscription);
      case 3:
        // Dépile vers l'écran parent (HomeScreen onglet Profil) si possible,
        // sinon remplace la stack par HomeScreen (onglet Accueil par défaut).
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.home);
        }
    }
  }
}
