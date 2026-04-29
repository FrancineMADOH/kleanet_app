// Écran édition profil (Écran 20 du plan).
//
// Route pushée depuis ProfileScreen (/profile/edit) — possède son propre
// Scaffold + AppBar avec bouton retour automatique.
//
// Champs éditables : Nom complet, Email (optionnel).
// Le téléphone est l'identifiant d'authentification → affiché en lecture seule.
//
// Flux :
//   1. Pré-remplit les champs depuis AuthProvider.profile dans initState.
//   2. "Enregistrer" → AuthProvider.updateProfile(name, email).
//   3. Succès → context.pop() + SnackBar de confirmation.
//   4. Erreur → SnackBar avec le message d'erreur, bouton réactivé.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pré-remplit les champs avec les données actuelles du profil.
    final profile = context.read<AuthProvider>().profile;
    _nameController.text = profile?.name ?? '';
    _emailController.text = profile?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final success = await provider.updateProfile(
      name: _nameController.text.trim(),
      email: email.isEmpty ? null : email,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.updateProfileError ?? 'Erreur de mise à jour.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isUpdatingProfile;
    final phone = context.read<AuthProvider>().profile?.phone ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Champ Nom.
            const Text(
              'Nom complet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(hint: 'Ex : Francine Madoh'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null,
            ),
            const SizedBox(height: 20),

            // Champ Email.
            const Text(
              'Email (optionnel)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(hint: 'exemple@email.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // optionnel
                final emailReg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                return emailReg.hasMatch(v.trim())
                    ? null
                    : 'Format email invalide.';
              },
            ),
            const SizedBox(height: 20),

            // Téléphone — lecture seule (identifiant auth, non modifiable).
            const Text(
              'Téléphone',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: phone,
              readOnly: true,
              decoration: _inputDecoration(hint: '+237XXXXXXXXX').copyWith(
                filled: true,
                fillColor: AppColors.surface,
                suffixIcon: const Tooltip(
                  message: 'Le numéro de téléphone est votre identifiant et ne peut pas être modifié.',
                  child: Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                ),
              ),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),

            // Bouton enregistrer.
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
