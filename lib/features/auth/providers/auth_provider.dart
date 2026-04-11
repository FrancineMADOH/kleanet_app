import 'package:flutter/foundation.dart';

import '../../../core/auth/token_storage.dart';

/// Statut de session connu par l'app.
/// - [unknown] : tant que bootstrap() n'a pas encore lu le storage.
///   Le router l'utilise pour pinner l'écran splash.
/// - [authenticated] : un access token existe en storage.
/// - [unauthenticated] : pas de token, l'utilisateur doit passer par /auth.

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Session state machine consumed by the router's auth guard.
///
/// Lifecycle: `unknown` on construction → resolves to `authenticated` or
/// `unauthenticated` after [bootstrap] reads the persisted access token.
/// The router pins the splash screen while the status is `unknown`, so any
/// code path that leaves the provider in that state stalls the app —
/// always transition out of `unknown` before returning from startup.
///
/// [signOut] is wired as the `ApiClient.onSessionExpired` hook: a failed
/// refresh clears tokens and flips the status, causing the router to
/// redirect to `/auth` automatically via `refreshListenable`.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required TokenStorage tokenStorage})
      : _tokenStorage = tokenStorage;

  final TokenStorage _tokenStorage;
  AuthStatus _status = AuthStatus.unknown;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isBootstrapped => _status != AuthStatus.unknown;

  /// Lit le token d'accès persisté et résout le statut. À appeler UNE SEULE
  /// fois au démarrage (depuis main.dart). Si cette méthode throw, main.dart
  /// retombe sur signOut() — le provider ne doit jamais rester en `unknown`.
  Future<void> bootstrap() async {
    final token = await _tokenStorage.readAccessToken();
    _setStatus(
      token != null && token.isNotEmpty
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
    if (kDebugMode) {
      debugPrint('[AuthProvider] bootstrap resolved → $_status');
    }
  }

  /// Marque la session comme authentifiée après un login OTP/OAuth réussi.
  /// Les tokens doivent avoir été sauvegardés dans TokenStorage AVANT cet appel.
  void markAuthenticated() => _setStatus(AuthStatus.authenticated);

  /// Déconnexion : efface les tokens et bascule en `unauthenticated`.
  /// Déclenché manuellement (bouton logout) ou automatiquement par ApiClient
  /// via le callback `onSessionExpired` quand le refresh token n'est plus valide.
  Future<void> signOut() async {
    await _tokenStorage.clear();
    _setStatus(AuthStatus.unauthenticated);
  }

  void _setStatus(AuthStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }
}
