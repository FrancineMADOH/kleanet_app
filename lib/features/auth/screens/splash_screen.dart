// Écran de démarrage affiché pendant la résolution du statut d'auth.
//
// Le router GoRouter "pinne" cet écran tant que AuthProvider est en
// AuthStatus.unknown (avant que bootstrap() ait lu le storage). Dès que
// le statut est résolu, le routeur redirige automatiquement vers /home
// ou /auth — ce widget ne contient donc AUCUNE logique de navigation.
// Son seul rôle : afficher la marque + un spinner pendant ~100ms.

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Splash statique affichant le logo Kleanet sur fond gradient.
/// Voir `app_router.dart` pour la logique qui déclenche sa sortie.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo/logo_complet.png',
                  width: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  'Laverie à domicile à Yaoundé',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
