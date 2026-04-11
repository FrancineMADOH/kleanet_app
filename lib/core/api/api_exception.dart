// Type d'exception standardisé pour toutes les erreurs de l'API Kleanet.
//
// L'objectif : les écrans ne doivent JAMAIS voir un DioException ou un
// SocketException. Ils attrapent uniquement des ApiException, avec un
// `code` stable (ex: "ORDER_NOT_FOUND") et un `message` déjà lisible.
// C'est ApiClient qui convertit toutes les erreurs Dio vers ce type.

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  /// Code HTTP. Vaut 0 pour les erreurs réseau (pas de réponse du serveur).
  final int statusCode;

  /// Code métier stable (ex: "SESSION_EXPIRED", "ORDER_NOT_FOUND",
  /// "TOO_SOON"). À utiliser pour brancher de la logique UI — jamais
  /// `message`, qui peut être traduit.
  final String code;

  /// Message lisible, affichable tel quel dans une SnackBar ou une alerte.
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == 0;

  /// Convertit une DioException en ApiException.
  ///
  /// - Si pas de réponse (timeout, pas de réseau, certificat…) → code 0,
  ///   message réseau en français.
  /// - Si le serveur a répondu avec un body JSON contenant {code, message},
  ///   on les remonte tels quels.
  /// - Sinon on retombe sur "UNKNOWN" / "Une erreur est survenue.".
  factory ApiException.fromDioError(DioException error) {
    final response = error.response;
    if (response == null) {
      return ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: _networkMessage(error.type),
      );
    }

    final data = response.data;
    String code = 'UNKNOWN';
    String message = 'Une erreur est survenue.';

    // L'API Fastify renvoie toujours un JSON {code, message} ou {error, message}
    // pour les erreurs — on s'accommode des deux variantes.
    if (data is Map<String, dynamic>) {
      final rawCode = data['code'] ?? data['error'];
      if (rawCode is String) code = rawCode;
      final rawMessage = data['message'];
      if (rawMessage is String) message = rawMessage;
    }

    return ApiException(
      statusCode: response.statusCode ?? 0,
      code: code,
      message: message,
    );
  }

  /// Exception spéciale "session expirée" utilisée par ApiClient quand le
  /// refresh token ne marche plus. Les écrans peuvent la reconnaître via
  /// `e.code == 'SESSION_EXPIRED'`.
  factory ApiException.sessionExpired() {
    return const ApiException(
      statusCode: 401,
      code: 'SESSION_EXPIRED',
      message: 'Votre session a expiré. Veuillez vous reconnecter.',
    );
  }

  @override
  String toString() => 'ApiException($statusCode $code): $message';

  // Traduit les DioExceptionType "pas de réponse" en messages FR lisibles.
  static String _networkMessage(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le serveur met trop de temps à répondre.';
      case DioExceptionType.connectionError:
        return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
      case DioExceptionType.cancel:
        return 'Requête annulée.';
      case DioExceptionType.badCertificate:
        return 'Certificat serveur invalide.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Erreur réseau inattendue.';
    }
  }
}
