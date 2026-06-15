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

    // L'API Fastify renvoie toujours un JSON {code, message} ou {error, message}
    // pour les erreurs — on s'accommode des deux variantes.
    if (data is Map<String, dynamic>) {
      final rawCode = data['code'] ?? data['error'];
      if (rawCode is String) code = rawCode;
    }

    // Le message est toujours traduit en français depuis le code métier.
    // On n'affiche jamais le message anglais brut de l'API — le code est
    // stable, le message peut changer ou varier selon la version de l'API.
    return ApiException(
      statusCode: response.statusCode ?? 0,
      code: code,
      message: _frenchMessage(code),
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

  /// Traduit un code d'erreur métier API en message français lisible.
  /// Centraliser ici évite que les messages anglais bruts de l'API
  /// remontent dans les SnackBars et écrans d'erreur.
  static String _frenchMessage(String code) {
    switch (code) {
      // Auth
      case 'INVALID_OTP':
        return 'Code incorrect. Vérifiez et réessayez.';
      case 'EXPIRED_OTP':
        return 'Code expiré. Demandez un nouveau code.';
      case 'MAX_ATTEMPTS_REACHED':
        return 'Trop de tentatives. Attendez 10 minutes avant de réessayer.';
      case 'TOO_MANY_REQUESTS':
        return 'Trop de requêtes. Attendez quelques instants.';
      case 'TOO_SOON':
        return 'Délai trop court. Attendez avant de demander un nouveau code.';
      case 'DUPLICATE_ACCOUNT':
        return 'Ce numéro est déjà associé à un autre compte.';
      case 'INVALID_GOOGLE_TOKEN':
        return 'Connexion Google invalide ou expirée. Réessayez.';
      case 'INVALID_FACEBOOK_TOKEN':
        return 'Connexion Facebook invalide ou expirée. Réessayez.';
      case 'INVALID_REFRESH_TOKEN':
      case 'UNAUTHORIZED':
        return 'Session invalide. Veuillez vous reconnecter.';
      case 'FORBIDDEN':
        return 'Vous n\'avez pas accès à cette ressource.';

      // Commandes
      case 'ORDER_NOT_FOUND':
      case 'INVALID_ORDER_ID':
        return 'Commande introuvable.';
      case 'ORDER_NOT_DELIVERED':
        return 'Cette commande n\'a pas encore été livrée.';
      case 'INVALID_DATE':
        return 'Date ou heure de collecte invalide.';
      case 'INVALID_COORDINATES':
        return 'Coordonnées de livraison invalides.';

      // Abonnements
      case 'ALREADY_SUBSCRIBED':
        return 'Vous avez déjà un abonnement actif. Contactez-nous pour changer de plan.';
      case 'PLAN_NOT_FOUND':
        return 'Ce plan d\'abonnement n\'existe plus.';
      case 'PICKUP_QUOTA_EXCEEDED':
        return 'Quota de pickups atteint pour cette semaine.';

      // Avis
      case 'ALREADY_REVIEWED':
        return 'Vous avez déjà laissé un avis pour cette commande.';

      // Profil
      case 'NOTHING_TO_UPDATE':
        return 'Aucune modification à enregistrer.';

      // Générique
      case 'UNKNOWN':
      default:
        return 'Une erreur est survenue. Réessayez ou contactez-nous si le problème persiste.';
    }
  }
}
