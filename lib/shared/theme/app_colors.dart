// Palette de couleurs de la marque Kleanet.
//
// Source unique pour toutes les couleurs utilisées dans l'application.
// Si tu ajoutes une couleur, ajoute-la ici plutôt qu'en dur dans un widget —
// ça simplifie les changements de charte et garantit la cohérence visuelle.

import 'package:flutter/material.dart';

class AppColors {
  // Constructeur privé : la classe n'a vocation qu'à exposer des constantes.
  AppColors._();

  // --- Couleurs principales ---
  static const primary = Color(0xFF1E3A5F); // Bleu nuit (marque)
  static const accent1 = Color(0xFF06B6D4); // Cyan (accent froid)
  static const accent2 = Color(0xFF4F46E5); // Violet (accent secondaire)

  // --- Couleurs de feedback (statuts) ---
  static const success = Color(0xFF10B981); // Vert — commande livrée, paiement OK
  static const warning = Color(0xFFF59E0B); // Orange — action requise
  static const error = Color(0xFFEF4444);   // Rouge — erreur bloquante

  // --- Fonds neutres ---
  static const background = Color(0xFFFFFFFF); // Fond d'écran standard
  static const surface = Color(0xFFF8FAFC);    // Fond des cartes / sections

  // --- Textes ---
  static const textPrimary = Color(0xFF1F2937);   // Titres, contenu principal
  static const textSecondary = Color(0xFF6B7280); // Descriptions, libellés

  // --- Bordures & séparateurs ---
  static const border = Color(0xFFE2E8F0); // Bordures cartes, lignes timelines

  /// Dégradé de marque utilisé sur le splash, les écrans d'auth, les CTA
  /// premium. Orientation top-left → bottom-right pour que le logo ressorte
  /// sur le fond clair en haut et plonge dans le cyan en bas.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent1],
  );
}
