// Repository Auth — couche d'accès HTTP pour les endpoints /auth et /profile.
//
// Le repository est la SEULE couche autorisée à appeler ApiClient pour le
// module auth. Le provider consomme uniquement des méthodes typées d'ici.
// Règle d'or : pas de UI, pas de ChangeNotifier — juste des Future<>.
//
// Pour la conversion JSON → modèle, on délègue au helper partagé
// `parseOrThrow` (core/api/response_parser.dart) qui garantit que toute
// erreur de parsing devient une `ApiException(BAD_RESPONSE)` au lieu
// de laisser un TypeError remonter dans l'UI.

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/response_parser.dart';
import '../models/auth_models.dart';

class AuthRepository {
  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Demande l'envoi d'un OTP SMS au numéro donné (format E.164).
  /// L'API répond `{message}` — on ignore le message, le succès HTTP suffit.
  Future<void> sendOtp(String phoneE164) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.authPhoneSend,
      data: {'phone': phoneE164},
    );
  }

  /// Vérifie le code OTP saisi et récupère les tokens de session.
  /// À appeler uniquement après un `sendOtp` réussi pour le même numéro.
  Future<VerifyOtpResult> verifyOtp({
    required String phoneE164,
    required String code,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.authPhoneVerify,
      data: {'phone': phoneE164, 'code': code},
    );
    return parseOrThrow(
      response.data,
      VerifyOtpResult.fromJson,
      'verify response',
    );
  }

  /// Lit le profil du user courant. Utilisé par le splash pour valider
  /// que le token stocké est bien encore vivant côté backend — si l'appel
  /// lève une ApiException (401), le session check a échoué.
  Future<UserProfile> fetchProfile() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.profile);
    return parseOrThrow(
      response.data,
      UserProfile.fromJson,
      'profile response',
    );
  }

  /// Met à jour le nom et/ou l'email du client via PATCH /profile/.
  /// Retourne le profil mis à jour — utilisé par AuthProvider pour
  /// rafraîchir _profile sans refaire un fetchProfile() séparé.
  Future<UserProfile> updateProfile({
    required String name,
    String? email,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: {
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return parseOrThrow(
      response.data,
      UserProfile.fromJson,
      'update profile response',
    );
  }

  /// Envoie le FCM token au backend pour activer les push notifications.
  /// Fire-and-forget : les erreurs sont loggées mais n'interrompent pas
  /// le flux de login. Appelé après verifyOtp() et après bootstrap().
  Future<void> updateFcmToken(String token) async {
    await _apiClient.patch<void>(
      ApiEndpoints.profile,
      data: {'fcm_token': token},
    );
  }

  /// Révoque le refresh token côté backend (optionnel — on peut logout
  /// localement sans attendre cet appel, mais c'est plus propre).
  Future<void> logout(String refreshToken) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.authLogout,
      data: {'refresh_token': refreshToken},
    );
  }
}
