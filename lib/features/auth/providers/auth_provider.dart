import 'package:flutter/foundation.dart';

import '../../../core/auth/token_storage.dart';

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

  Future<void> bootstrap() async {
    debugPrint('[AuthProvider] bootstrap: reading token...');
    final token = await _tokenStorage.readAccessToken();
    debugPrint('[AuthProvider] bootstrap: token=${token == null ? "null" : "len=${token.length}"}');
    _setStatus(
      token != null && token.isNotEmpty
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
    debugPrint('[AuthProvider] bootstrap: status=$_status');
  }

  void markAuthenticated() => _setStatus(AuthStatus.authenticated);

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
