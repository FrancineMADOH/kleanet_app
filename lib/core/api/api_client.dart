import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

typedef SessionExpiredCallback = void Function();

/// HTTP client for the Kleanet API.
///
/// A 401 response triggers a single auto-refresh using the stored refresh
/// token and the original request is replayed exactly once. If the refresh
/// itself fails, tokens are wiped, [onSessionExpired] fires, and the caller
/// receives an [ApiException] (never a raw [DioException]).
class ApiClient {
  static const _kSkipAuth = 'skipAuth';
  static const _kRetried = '_retried';

  ApiClient({
    required TokenStorage tokenStorage,
    Dio? dio,
    this.onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ?? _buildDio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

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

  Completer<void>? _refreshCompleter;

  Dio get raw => _dio;

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

  Future<Response<T>> _run<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

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

    try {
      await _ensureRefreshed();
    } on ApiException catch (e) {
      return handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          error: e,
          response: error.response,
          type: DioExceptionType.badResponse,
        ),
      );
    }

    try {
      final retried = await _retry(error.requestOptions);
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<void> _ensureRefreshed() async {
    final existing = _refreshCompleter;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<void>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw ApiException.sessionExpired();
      }

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
      await _tokenStorage.clear();
      onSessionExpired?.call();
      completer.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

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
