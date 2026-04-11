// Assemblage du ThemeData Kleanet.
//
// C'est ce thème que MaterialApp consomme pour habiller tous les widgets
// Material (AppBar, ElevatedButton, Scaffold, etc.). Pour obtenir une couleur
// ou un style depuis un widget, utilise `Theme.of(context).colorScheme.*`
// au lieu d'importer directement AppColors — ça reste testable.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  /// Thème clair par défaut. L'app est en light-only pour l'instant ;
  /// si on ajoute du dark, créer une seconde méthode `dark()`.
  static ThemeData light() {
    // Définition du ColorScheme à partir de notre palette. Les champs
    // onPrimary/onSecondary/onSurface pilotent la couleur du texte/icône
    // placé *sur* chaque couleur de fond — essentiel pour le contraste.
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent1,
      tertiary: AppColors.accent2,
      error: AppColors.error,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextStyles.textTheme,

      // AppBar épurée : blanche, texte foncé, sans ombre, titre centré.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),

      // Bouton principal : primary, texte blanc, coins arrondis 12px,
      // padding confortable pour les doigts (tap target ≥ 44dp).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: AppTextStyles.headlineMedium.copyWith(fontSize: 16),
        ),
      ),
    );
  }
}
