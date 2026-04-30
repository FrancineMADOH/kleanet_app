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
import 'package:url_launcher/url_launcher.dart';

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

          // --- Contact société ---
          const _ContactSection(),

          const SizedBox(height: 16),
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
// Section contact société
// ----------------------------------------------------------------

class _ContactSection extends StatelessWidget {
  const _ContactSection();

  static const _whatsappPhone = '237674011983';
  static const _whatsappText = 'Bonjour, j\'ai une question sur Kleanet';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contactez-nous',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // WhatsApp — tappable
              _ContactTile(
                icon: Icons.chat,
                iconColor: const Color(0xFF25D366),
                label: 'WhatsApp',
                value: '+237 674 011 983',
                onTap: () => _openWhatsApp(context),
                showDivider: true,
              ),
              // Localisation — informative
              const _ContactTile(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.primary,
                label: 'Localisation',
                value: 'Yaoundé, Cameroun',
                showDivider: true,
              ),
              // Tagline — informative
              const _ContactTile(
                icon: Icons.access_time_outlined,
                iconColor: AppColors.accent1,
                label: 'Service',
                value: 'Collecte & livraison à domicile',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final encoded = Uri.encodeComponent(_whatsappText);
    final nativeUri =
        Uri.parse('whatsapp://send?phone=$_whatsappPhone&text=$encoded');
    final webUri =
        Uri.parse('https://wa.me/$_whatsappPhone?text=$encoded');
    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp.')),
      );
    }
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
    this.showDivider = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.open_in_new,
                size: 16, color: AppColors.textSecondary),
        ],
      ),
    );

    return Column(
      children: [
        onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: tile,
              )
            : tile,
        if (showDivider)
          const Divider(height: 1, indent: 50, color: AppColors.border),
      ],
    );
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
