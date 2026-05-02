// Écran d'atterrissage "non connecté" — premier écran que voit un user
// sans session active.
//
// Contenu : logo, slogan, 1 bouton principal "Continuer avec mon téléphone"
// qui pousse vers /auth/phone, et 2 boutons OAuth désactivés (stubs pour
// AUTH-02). Pas de logique métier ici — juste de la navigation.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

// Hauteur commune des 3 CTA d'auth — on la factorise pour garantir que
// "phone", "google" et "facebook" aient exactement la même taille visuelle.
const double _kAuthButtonHeight = 52;

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Image.asset(
                  'assets/images/logo/logo_kleanet_with_tag.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bienvenue sur Kleanet',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayLarge.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Laverie à domicile à Yaoundé',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(flex: 3),
                // Bouton principal — déclenche le flow OTP téléphone.
                SizedBox(
                  width: double.infinity,
                  height: _kAuthButtonHeight,
                  child: ElevatedButton(
                    onPressed: () => context.push(Routes.authPhone),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Continuer avec mon téléphone'),
                  ),
                ),
                const SizedBox(height: 12),
                // Stubs OAuth — seront câblés en AUTH-02 (vrais SDK + logos).
                _OAuthButton(
                  label: 'Continuer avec Google',
                  onPressed: () => _showComingSoon(context),
                ),
                const SizedBox(height: 12),
                _OAuthButton(
                  label: 'Continuer avec Facebook',
                  onPressed: () => _showComingSoon(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'En continuant, vous acceptez nos conditions d\'utilisation.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OAuth arrive en AUTH-02 — utilisez le téléphone.'),
      ),
    );
  }
}

/// Bouton OAuth secondaire — même hauteur et même forme que le bouton
/// principal, mais en style "outlined blanc" sur le gradient. Pas d'icône
/// pour l'instant : elles seront ajoutées en AUTH-02 avec les vrais logos
/// brand Google/Facebook (assets PNG/SVG), ce qui garantira une vraie
/// cohérence visuelle au lieu d'un mix Material icons hétérogène.
class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _kAuthButtonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
