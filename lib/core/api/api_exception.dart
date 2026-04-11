import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == 0;

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

  factory ApiException.sessionExpired() {
    return const ApiException(
      statusCode: 401,
      code: 'SESSION_EXPIRED',
      message: 'Votre session a expiré. Veuillez vous reconnecter.',
    );
  }

  @override
  String toString() => 'ApiException($statusCode $code): $message';

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
