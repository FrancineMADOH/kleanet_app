// Stockage sécurisé des tokens JWT côté device.
//
// On ne stocke JAMAIS les tokens dans SharedPreferences (non chiffrés) :
// on passe toujours par flutter_secure_storage, qui utilise le Keystore
// Android et la Keychain iOS. Le flag `encryptedSharedPreferences: true`
// force l'utilisation d'EncryptedSharedPreferences sur Android (sinon
// fallback insécurisé sur certaines versions anciennes).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  /// Crée un stockage. Le paramètre `storage` permet d'injecter une
  /// implémentation factice pour les tests unitaires (pas besoin de
  /// Keystore en environnement de test).
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // Clés de stockage — préfixées "kleanet." pour isoler de potentielles
  // autres apps partageant le keystore.
  static const _accessKey = 'kleanet.access_token';
  static const _refreshKey = 'kleanet.refresh_token';

  final FlutterSecureStorage _storage;

  /// Lecture du token d'accès (courte durée, ~30 min).
  /// Retourne null si absent ou jamais écrit.
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  /// Lecture du token de rafraîchissement (longue durée, ~30 jours).
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  /// Écrit les deux tokens en une seule opération — à appeler après une
  /// réponse OTP/OAuth réussie.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// Écrit uniquement le token d'accès — utilisé après un refresh
  /// (le refresh token n'est pas rotaté par notre API).
  Future<void> saveAccessToken(String accessToken) {
    return _storage.write(key: _accessKey, value: accessToken);
  }

  /// Efface les deux tokens. Appelé au logout, ou automatiquement
  /// par ApiClient quand le refresh échoue (session expirée).
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
