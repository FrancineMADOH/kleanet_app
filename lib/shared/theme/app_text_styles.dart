// Styles typographiques de Kleanet.
//
// On utilise la police Inter via le package google_fonts. Les styles exposés
// ici sont les "briques" utilisées dans toute l'app : préfère-les à des
// TextStyle construits à la main pour rester cohérent.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  /// TextTheme complet basé sur Inter, utilisé par ThemeData pour tous les
  /// Text() par défaut. Les couleurs sont forcées sur la palette Kleanet
  /// (sinon google_fonts applique du noir pur).
  static TextTheme textTheme = GoogleFonts.interTextTheme().apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  /// Titre d'accueil / page principale (32sp bold).
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// Titre de section / sous-titre (22sp semi-bold).
  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  /// Texte courant — descriptions, libellés secondaires (14sp regular).
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );
}
