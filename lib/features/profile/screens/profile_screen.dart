// Écran Profil — onglet 3 de HomeScreen (Écran 19 du plan).
//
// Monté dans l'IndexedStack de HomeScreen : PAS de Scaffold propre,
// le Scaffold parent fournit l'AppBar "Profil" et la bottom nav.
//
// Sections :
//   1. Avatar initiales + nom + téléphone masqué + email
//   2. Tuiles de navigation : Modifier le profil | Mes rendez-vous
//   3. Bouton Se déconnecter (rouge) — déplacé depuis l'AppBar Accueil

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    // Capture les providers avant les awaits pour éviter l'usage du context
    // après un gap asynchrone (lint warning "don't use BuildContext across gaps").
    final auth = context.read<AuthProvider>();
    final catalog = context.read<CatalogProvider>();
    await auth.signOut();
    await catalog.clear();
    // Le router bascule automatiquement vers /auth via le redirect listener.
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Section avatar + infos utilisateur ---
          _AvatarSection(profile: profile),
          const SizedBox(height: 32),

          // --- Navigation profil ---
          _NavTile(
            icon: Icons.edit_outlined,
            label: 'Modifier mon profil',
            onTap: () => context.push(Routes.profileEdit),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.calendar_month_outlined,
            label: 'Mes rendez-vous',
            onTap: () => context.push(Routes.profileAppointments),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.help_outline,
            label: 'Aide / FAQ',
            onTap: () => context.push(Routes.faq),
          ),

          const SizedBox(height: 32),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // --- Déconnexion ---
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Section avatar + informations du compte
// ----------------------------------------------------------------

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final name = profile?.name ?? '';
    final initials = _initials(name);

    return Row(
      children: [
        // Cercle initiales.
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primary,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isNotEmpty ? name : 'Mon compte',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (profile?.phone != null) ...[
                const SizedBox(height: 4),
                Text(
                  _maskPhone(profile!.phone!),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (profile?.email != null) ...[
                const SizedBox(height: 2),
                Text(
                  profile!.email!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Extrait 1 ou 2 initiales depuis le nom complet.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Masque tout sauf les 5 premiers caractères du numéro E.164.
  /// Ex: +237612345678 → "+2376 XX XXX XXX"
  static String _maskPhone(String phone) {
    if (phone.length < 8) return phone;
    return '${phone.substring(0, 5)} XX XXX XXX';
  }
}

// ----------------------------------------------------------------
// Tuile de navigation (Modifier / Rendez-vous)
// ----------------------------------------------------------------

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
