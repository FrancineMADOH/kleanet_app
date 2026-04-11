// Provider central du flux d'authentification.
//
// Rôles :
//   1. Machine à état de session (unknown → authenticated/unauthenticated).
//   2. Orchestration du flux OTP (sendOtp, verifyOtp) côté UI.
//   3. Persistance du numéro en cours de vérification + anti-brute-force
//      (5 tentatives → lockout 10min stocké en SharedPreferences).
//
// Pourquoi tout dans UN seul provider ? Parce que les 3 écrans (auth,
// phone, otp) partagent exactement le même état — les splitter forcerait
// à passer le numéro en paramètre de route ou à dupliquer la logique.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_storage.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

/// Statut de session connu par l'app.
/// - [unknown] : tant que bootstrap() n'a pas encore résolu le storage.
///   Le router l'utilise pour pinner l'écran splash.
/// - [authenticated] : un access token valide existe (vérifié via /profile).
/// - [unauthenticated] : pas de token, ou le token a expiré.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Statut du flux OTP en cours — consommé par phone_screen et otp_screen.
enum OtpFlowStatus {
  idle, // rien en cours
  sending, // POST /phone/send en vol
  sent, // OTP envoyé avec succès → otp_screen affiché
  verifying, // POST /phone/verify en vol
  locked, // 5 échecs atteints → attente fin de lockout
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required TokenStorage tokenStorage,
    required AuthRepository authRepository,
  })  : _tokenStorage = tokenStorage,
        _authRepository = authRepository;

  final TokenStorage _tokenStorage;
  final AuthRepository _authRepository;

  // Clés SharedPreferences — préfixées "kleanet.auth." pour éviter les collisions.
  static const _kAttemptsKey = 'kleanet.auth.otp_attempts';
  static const _kLockUntilKey = 'kleanet.auth.otp_lock_until';

  /// Nombre d'essais OTP avant lockout.
  static const maxAttempts = 5;

  /// Durée du lockout après épuisement des essais.
  static const lockDuration = Duration(minutes: 10);

  // --- État session ---
  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;

  // --- État flux OTP ---
  OtpFlowStatus _otpStatus = OtpFlowStatus.idle;
  String? _pendingPhone; // numéro en cours de vérification
  String? _errorMessage; // dernière erreur à afficher à l'UI
  int _attemptsUsed = 0;
  DateTime? _lockedUntil;

  // Getters publics — l'UI consomme toujours via ces getters, jamais les
  // champs directement (pour préserver l'encapsulation).
  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isBootstrapped => _status != AuthStatus.unknown;

  OtpFlowStatus get otpStatus => _otpStatus;
  String? get pendingPhone => _pendingPhone;
  String? get errorMessage => _errorMessage;
  int get attemptsRemaining => maxAttempts - _attemptsUsed;
  DateTime? get lockedUntil => _lockedUntil;

  /// Lit le token et, si présent, confirme la session via /profile.
  /// Si /profile throw (401, réseau, …) → ApiClient gère déjà le refresh,
  /// et en dernier recours on tombe sur unauthenticated. À appeler UNE
  /// fois au démarrage depuis main.dart.
  Future<void> bootstrap() async {
    await _loadLockState();

    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    try {
      _profile = await _authRepository.fetchProfile();
      _setStatus(AuthStatus.authenticated);
    } on Exception catch (e) {
      // 401 → ApiClient a déjà tenté un refresh et/ou wipe les tokens.
      // Tout autre cas (réseau down, 500) → on préfère débloquer l'app
      // en considérant la session inconnue comme "à refaire". On ne
      // catche que Exception : les Error (assertion, type) doivent
      // remonter en dev pour ne pas masquer un bug.
      if (kDebugMode) debugPrint('[AuthProvider] bootstrap check failed: $e');
      await _tokenStorage.clear();
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  /// Demande l'envoi d'un OTP au numéro donné. Transitionne otpStatus vers
  /// `sending` puis `sent`. Les erreurs sont capturées et stockées dans
  /// `errorMessage` pour que l'UI les affiche sans try/catch.
  Future<bool> sendOtp(String phoneE164) async {
    if (_isCurrentlyLocked()) {
      _errorMessage =
          'Trop de tentatives. Réessayez à ${_formatLockEnd()}.';
      _otpStatus = OtpFlowStatus.locked;
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _pendingPhone = phoneE164;
    _otpStatus = OtpFlowStatus.sending;
    notifyListeners();

    try {
      await _authRepository.sendOtp(phoneE164);
      _otpStatus = OtpFlowStatus.sent;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _otpStatus = OtpFlowStatus.idle;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Vérifie le code OTP. En cas de succès : sauvegarde les tokens,
  /// reset le compteur d'essais et bascule le statut session.
  /// En cas d'échec : incrémente le compteur, et déclenche le lockout
  /// au 5e essai raté.
  Future<bool> verifyOtp(String code) async {
    final phone = _pendingPhone;
    if (phone == null) {
      _errorMessage = 'Demandez un nouveau code.';
      notifyListeners();
      return false;
    }
    if (_isCurrentlyLocked()) {
      _otpStatus = OtpFlowStatus.locked;
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _otpStatus = OtpFlowStatus.verifying;
    notifyListeners();

    try {
      final result =
          await _authRepository.verifyOtp(phoneE164: phone, code: code);
      await _tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      await _resetAttempts();
      _pendingPhone = null;
      _otpStatus = OtpFlowStatus.idle;
      // On récupère le profil maintenant — ça évite un splash d'auth
      // vide au prochain boot et ça alimente le header du /home.
      try {
        _profile = await _authRepository.fetchProfile();
      } on Exception catch (e) {
        // Profil non bloquant : la session est OK, l'UI home re-fetchera.
        // On log quand même pour pouvoir diagnostiquer si ça arrive.
        if (kDebugMode) {
          debugPrint('[AuthProvider] post-verify profile fetch failed: $e');
        }
      }
      _setStatus(AuthStatus.authenticated);
      return true;
    } on ApiException catch (_) {
      await _registerFailedAttempt();
      _otpStatus = _isCurrentlyLocked()
          ? OtpFlowStatus.locked
          : OtpFlowStatus.sent;
      if (_isCurrentlyLocked()) {
        _errorMessage =
            'Trop de tentatives. Réessayez à ${_formatLockEnd()}.';
      } else {
        final remaining = attemptsRemaining;
        _errorMessage =
            'Code incorrect — $remaining essai${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''}.';
      }
      notifyListeners();
      return false;
    }
  }

  /// Réinitialise complètement le flux OTP — appelé quand l'utilisateur
  /// tape "Retour" depuis l'écran OTP ou change de numéro.
  void cancelOtpFlow() {
    _pendingPhone = null;
    _otpStatus = OtpFlowStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Déconnexion : efface les tokens locaux et bascule en `unauthenticated`.
  /// Note : ne révoque pas le refresh token côté backend — on le fera dans
  /// l'écran profil (où l'on a l'UX pour attendre la fin de l'appel).
  Future<void> signOut() async {
    await _tokenStorage.clear();
    _profile = null;
    _pendingPhone = null;
    _otpStatus = OtpFlowStatus.idle;
    _errorMessage = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  // --- Gestion du lockout persistant ---

  Future<void> _loadLockState() async {
    final prefs = await SharedPreferences.getInstance();
    _attemptsUsed = prefs.getInt(_kAttemptsKey) ?? 0;
    final ts = prefs.getInt(_kLockUntilKey);
    if (ts != null) {
      final lock = DateTime.fromMillisecondsSinceEpoch(ts);
      if (lock.isAfter(DateTime.now())) {
        _lockedUntil = lock;
      } else {
        // Le lockout est expiré → nettoyage.
        await prefs.remove(_kLockUntilKey);
        await prefs.remove(_kAttemptsKey);
        _attemptsUsed = 0;
      }
    }
  }

  Future<void> _registerFailedAttempt() async {
    _attemptsUsed += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAttemptsKey, _attemptsUsed);
    if (_attemptsUsed >= maxAttempts) {
      _lockedUntil = DateTime.now().add(lockDuration);
      await prefs.setInt(
        _kLockUntilKey,
        _lockedUntil!.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _resetAttempts() async {
    _attemptsUsed = 0;
    _lockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAttemptsKey);
    await prefs.remove(_kLockUntilKey);
  }

  bool _isCurrentlyLocked() {
    final lock = _lockedUntil;
    if (lock == null) return false;
    if (lock.isBefore(DateTime.now())) {
      _lockedUntil = null;
      _attemptsUsed = 0;
      return false;
    }
    return true;
  }

  String _formatLockEnd() {
    final lock = _lockedUntil;
    if (lock == null) return '';
    final h = lock.hour.toString().padLeft(2, '0');
    final m = lock.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _setStatus(AuthStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }
}
