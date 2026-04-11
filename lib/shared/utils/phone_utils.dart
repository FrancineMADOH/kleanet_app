// Normalisation et validation des numéros de téléphone au format E.164.
//
// L'API Kleanet exige des numéros E.164 (`+2376XXXXXXXX`). L'utilisateur
// peut saisir son numéro de 5 façons différentes ("699000000", "06 99 00",
// "+237 699...") — c'est ici qu'on ramène tout ça à une seule forme canonique.

/// Helpers pour manipuler les numéros camerounais.
/// Préfixe pays par défaut : Cameroun (+237). Si l'app s'ouvre à d'autres
/// pays plus tard, passer le pays en paramètre au lieu de la constante.
class PhoneUtils {
  PhoneUtils._();

  /// Indicatif Cameroun — par défaut sur tous les inputs sans préfixe.
  static const defaultCountryCode = '+237';

  /// Longueur d'un numéro local camerounais (9 chiffres après le +237).
  static const _cmLocalLength = 9;

  /// Normalise un input utilisateur vers le format E.164.
  ///
  /// Règles :
  ///   - Supprime espaces, tirets, parenthèses, points.
  ///   - Si le numéro commence par `+` → on ne touche pas à l'indicatif.
  ///   - Si le numéro commence par `00` → on remplace par `+`.
  ///   - Si le numéro fait 9 chiffres et commence par 6 → on préfixe +237.
  ///   - Si le numéro fait 10 chiffres et commence par 06 → on retire le 0
  ///     et on préfixe +237 (cas habituel "06 99 00 00 00").
  ///
  /// Retourne `null` si l'input ne peut pas être transformé en E.164 valide.
  static String? normalize(String raw) {
    final trimmed = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (trimmed.isEmpty) return null;

    String withPlus;
    if (trimmed.startsWith('+')) {
      withPlus = trimmed;
    } else if (trimmed.startsWith('00')) {
      withPlus = '+${trimmed.substring(2)}';
    } else if (trimmed.length == _cmLocalLength && trimmed.startsWith('6')) {
      withPlus = '$defaultCountryCode$trimmed';
    } else if (trimmed.length == _cmLocalLength + 1 &&
        trimmed.startsWith('06')) {
      withPlus = '$defaultCountryCode${trimmed.substring(1)}';
    } else {
      return null;
    }

    // Validation finale : +, puis 8 à 15 chiffres (pattern E.164 générique).
    final e164 = RegExp(r'^\+[1-9]\d{7,14}$');
    return e164.hasMatch(withPlus) ? withPlus : null;
  }

  /// Vérifie qu'une chaîne est déjà au format E.164 valide.
  static bool isValidE164(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }

  /// Format d'affichage lisible : "+237 6 99 00 00 00".
  /// Utilisé UNIQUEMENT pour l'affichage — jamais à envoyer à l'API.
  static String formatDisplay(String e164) {
    if (!e164.startsWith('+237') || e164.length != 13) return e164;
    final local = e164.substring(4);
    // Groupe par 2 après le premier chiffre : "6 XX XX XX XX".
    return '+237 ${local[0]} ${local.substring(1, 3)} '
        '${local.substring(3, 5)} ${local.substring(5, 7)} '
        '${local.substring(7, 9)}';
  }
}
