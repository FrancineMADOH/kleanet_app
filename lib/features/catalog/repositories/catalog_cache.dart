// Cache persistant du catalogue (SharedPreferences).
//
// Objectif : permettre à l'app de démarrer offline et d'afficher le
// catalogue immédiatement sans attendre le /catalog/services. Le
// CatalogProvider décide quand utiliser ce cache et quand le rafraîchir
// — ce fichier ne fait QUE lire/écrire/nettoyer.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog_models.dart';

class CatalogCache {
  /// Clé SharedPreferences — préfixe "kleanet.catalog." pour isoler.
  static const _kSnapshotKey = 'kleanet.catalog.snapshot';

  /// Lit le snapshot du disque. Retourne `null` si :
  ///   - aucun cache n'a jamais été écrit
  ///   - le JSON est corrompu (on ne veut pas crasher l'app sur un
  ///     format obsolète — on ignore silencieusement et on laisse le
  ///     provider refetch).
  Future<CatalogSnapshot?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSnapshotKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CatalogSnapshot.fromCacheJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('[CatalogCache] read failed: $e');
      return null;
    }
  }

  /// Sauvegarde un snapshot en écrasant le précédent.
  /// On NE propage PAS les erreurs d'écriture — un cache raté ne doit
  /// jamais empêcher l'UI de fonctionner avec les données fraîches.
  Future<void> write(CatalogSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kSnapshotKey,
        jsonEncode(snapshot.toCacheJson()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CatalogCache] write failed: $e');
    }
  }

  /// Efface le cache — à appeler au logout pour ne pas mélanger les
  /// données catalogue d'un user avec un autre (le catalogue est public
  /// aujourd'hui, mais pourrait devenir user-scoped plus tard).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSnapshotKey);
  }
}
