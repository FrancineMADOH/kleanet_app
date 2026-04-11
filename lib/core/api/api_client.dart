// Client HTTP central de l'app Kleanet.
//
// C'est LE fichier critique du module réseau. Toutes les requêtes vers
// l'API Fastify passent par ici, et c'est ici que se joue le flow magique
// de rafraîchissement automatique du JWT quand l'access token expire.
//
// Comportement d'un appel authentifié :
//   1. onRequest : lit le token dans TokenStorage et ajoute "Bearer <token>"
//   2. Si 401 → onError déclenche _ensureRefreshed() :
//        - lit le refresh token
//        - POST /auth/refresh
//        - sauvegarde le nouveau access token
//   3. Rejoue la requête originale UNE SEULE fois (flag _retried)
//   4. Si le refresh échoue → clear() tokens + onSessionExpired()
//      + ApiException(SESSION_EXPIRED) remontée au caller
//
// Les écrans ne voient JAMAIS un DioException : ils reçoivent soit une
// Response, soit une ApiException — c'est ça qui rend l'UI simple à écrire.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

/// Callback invoqué une seule fois quand le refresh token n'est plus
/// valide. Sert à propager l'info à AuthProvider pour déclencher le
/// redirect vers /auth via le router.
typedef SessionExpiredCallback = void Function();

/// HTTP client for the Kleanet API.
///
/// A 401 response triggers a single auto-refresh using the stored refresh
/// token and the original request is replayed exactly once. If the refresh
/// itself fails, tokens are wiped, [onSessionExpired] fires, and the caller
/// receives an [ApiException] (never a raw [DioException]).
class ApiClient {
  // Clés utilisées dans options.extra pour marquer des requêtes spéciales.
  // - _kSkipAuth : ne pas injecter le header Authorization (utilisé par
  //   la requête de refresh elle-même, sinon boucle infinie).
  // - _kRetried : la requête a déjà été rejouée après refresh ; si elle
  //   échoue encore en 401, on abandonne au lieu de re-refresh.
  static const _kSkipAuth = 'skipAuth';
  static const _kRetried = '_retried';

  ApiClient({
    required TokenStorage tokenStorage,
    Dio? dio,
    this.onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ?? _buildDio() {
    // Un seul intercepteur qui gère request (ajout token) ET error (refresh).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  /// Construit l'instance Dio par défaut, pointant vers l'API dev.
  /// La factory est séparée pour permettre aux tests d'injecter un Dio
  /// pré-configuré (ex: avec un adapter mocké).
  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final SessionExpiredCallback? onSessionExpired;

  // Complèter utilisé pour coaléscer les refresh simultanés : si 5 requêtes
  // reviennent en 401 en même temps, on ne veut PAS faire 5 POST /refresh.
  // On fait UN seul refresh et les 4 autres attendent sur le même future.
  Completer<void>? _refreshCompleter;

  /// Accès brut à Dio — pour usages avancés (streams, download, etc.).
  /// À éviter dans les repositories standards (passe par get/post/...).
  Dio get raw => _dio;

  // --- Wrappers HTTP typés ---
  // Ces wrappers ont 2 rôles :
  //   1. Fournir un type de retour générique Response<T>.
  //   2. Convertir les DioException en ApiException via _run().

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _run(() => _dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
        ));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _run(() => _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ));
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _run(() => _dio.patch<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ));
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _run(() => _dio.delete<T>(path, data: data, options: options));
  }

  /// Wrapper qui garantit que toute DioException remontée par Dio est
  /// convertie en ApiException avant d'atteindre l'appelant.
  Future<Response<T>> _run<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Intercepteur : ajoute le header Authorization sauf si la requête
  /// a demandé explicitement de sauter l'auth (cas du refresh lui-même).
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_kSkipAuth] == true) {
      return handler.next(options);
    }
    final token = await _tokenStorage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Intercepteur d'erreur : c'est ici que se joue le flow de refresh.
  ///
  /// On ne tente un refresh QUE si :
  ///   - le status est 401 ;
  ///   - la requête n'est pas déjà un retry (évite les boucles) ;
  ///   - ce n'est pas la requête de refresh elle-même qui échoue.
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = error.response?.statusCode == 401;
    final alreadyRetried = error.requestOptions.extra[_kRetried] == true;
    final isRefreshCall =
        error.requestOptions.path == ApiEndpoints.authRefresh;

    if (!isUnauthorized || alreadyRetried || isRefreshCall) {
      return handler.next(error);
    }

    // Étape 1 : s'assurer qu'un refresh a eu lieu. Soit on le fait,
    // soit on attend le refresh en cours (coalescing).
    try {
      await _ensureRefreshed();
    } on ApiException catch (e) {
      // Refresh échoué → on propage l'erreur en ApiException via
      // le champ .error d'un DioException (Dio va ensuite la remonter
      // dans _run, qui la verra comme ApiException et la relancera).
      return handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          error: e,
          response: error.response,
          type: DioExceptionType.badResponse,
        ),
      );
    }

    // Étape 2 : refresh OK, on rejoue la requête originale avec le flag
    // _retried pour garantir qu'on ne retentera pas un second refresh.
    try {
      final retried = await _retry(error.requestOptions);
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Déclenche un refresh du access token, ou attend le refresh en cours
  /// si un autre 401 l'a déjà démarré. C'est le mécanisme de coalescing :
  /// N requêtes simultanées qui expirent = UN seul POST /auth/refresh.
  Future<void> _ensureRefreshed() async {
    final existing = _refreshCompleter;
    if (existing != null) {
      // Refresh déjà en cours : on attend son résultat au lieu d'en
      // démarrer un deuxième.
      return existing.future;
    }

    final completer = Completer<void>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        // Pas de refresh token en storage → impossible de se réauthentifier.
        throw ApiException.sessionExpired();
      }

      // Important : skipAuth=true pour ne PAS ajouter un Authorization
      // périmé sur la requête de refresh — sinon l'API peut répondre 401
      // sur le refresh lui-même et on retombe dans une boucle.
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': refreshToken},
        options: Options(extra: {_kSkipAuth: true}),
      );

      final newAccess = response.data?['access_token'];
      if (newAccess is! String || newAccess.isEmpty) {
        throw ApiException.sessionExpired();
      }

      await _tokenStorage.saveAccessToken(newAccess);
      completer.complete();
    } on DioException catch (e, stack) {
      // Refresh HTTP a échoué : on log en debug (pour diagnostic), on
      // nettoie tout et on prévient l'app via onSessionExpired.
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] refresh failed: ${e.type} '
          'status=${e.response?.statusCode} message=${e.message}\n$stack',
        );
      }
      await _tokenStorage.clear();
      onSessionExpired?.call();
      final apiError = ApiException.sessionExpired();
      completer.completeError(apiError);
      throw apiError;
    } on ApiException catch (e) {
      // Cas "pas de refresh token" ou "réponse invalide" remonté plus haut.
      await _tokenStorage.clear();
      onSessionExpired?.call();
      completer.completeError(e);
      rethrow;
    } finally {
      // Toujours libérer le slot, que le refresh ait réussi ou non.
      _refreshCompleter = null;
    }
  }

  /// Rejoue la requête originale avec un nouveau access token.
  /// On clone les options en ajoutant _retried=true pour bloquer un
  /// éventuel second refresh si celle-ci échoue encore en 401.
  Future<Response<T>> _retry<T>(RequestOptions options) {
    final newOptions = Options(
      method: options.method,
      headers: Map<String, dynamic>.from(options.headers),
      contentType: options.contentType,
      responseType: options.responseType,
      extra: {...options.extra, _kRetried: true},
    );
    return _dio.request<T>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: newOptions,
    );
  }
}
