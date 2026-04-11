// Formatage monétaire pour l'app Kleanet.
//
// Devise unique : XAF (franc CFA d'Afrique centrale). Pas de décimales
// par convention locale — on ne facture jamais au centime. Séparateur
// de milliers : espace fine ("1 200 XAF"), plus lisible que la virgule
// ou le point pour un affichage français.

class CurrencyUtils {
  CurrencyUtils._();

  /// Formate un montant en XAF avec séparateur de milliers.
  /// Ex: `formatXAF(1200)` → `"1 200 XAF"`, `formatXAF(0)` → `"0 XAF"`.
  ///
  /// Arrondit à l'entier le plus proche — on ne veut jamais afficher
  /// "1200,5 XAF" à l'utilisateur même si une règle de prix stocke des
  /// décimales côté backend.
  static String formatXAF(num amount) {
    final rounded = amount.round();
    final str = rounded.toString();

    // Insère un espace tous les 3 chiffres depuis la droite.
    // Ex: "1200000" → "1 200 000".
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final fromRight = str.length - i;
      if (i > 0 && fromRight % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }

    return '${buffer.toString()} XAF';
  }
}
