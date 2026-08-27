import 'package:dio/dio.dart';

import '../../features/auth/data/token_storage.dart';
import '../constants/api_constants.dart';
import '../error/exceptions.dart';
import 'api_interceptors.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

/// Thin, testable wrapper around a configured [Dio] instance.
///
/// Responsibilities:
///  * Central base-URL / timeout / header configuration.
///  * Installs auth (JWT injection), error-mapping and logging interceptors.
///  * Exposes typed `get`/`post` helpers that surface the app's own
///    [Exception] types (see [ErrorInterceptor]) instead of [DioException].
class DioClient {
  DioClient({required TokenStorage tokenStorage, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio
      ..options.baseUrl = ApiConstants.baseUrl
      ..options.connectTimeout = ApiConstants.connectTimeout
      ..options.receiveTimeout = ApiConstants.receiveTimeout
      ..options.responseType = ResponseType.json
      ..options.headers = <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

    // Order matters: Auth injects the header first; Retry re-dispatches
    // transient GET failures (5xx/timeout/429) with backoff before they're
    // mapped — this also makes on-the-fly source scraping more resilient to a
    // flaky upstream; Error maps failures on the way back out; Logging observes
    // everything. Retry is GET-only, so authenticated POST/DELETE writes
    // (favorites/history) are never repeated.
    _dio.interceptors.addAll([
      AuthInterceptor(tokenStorage),
      RetryInterceptor(dio: _dio),
      ErrorInterceptor(),
      LoggingInterceptor(),
    ]);
  }

  final Dio _dio;

  /// Direct access to the underlying [Dio], e.g. for cancellation tokens.
  Dio get raw => _dio;

  /// Performs a GET request and returns the decoded body.
  ///
  /// Throws one of the app's typed exceptions ([NetworkException],
  /// [TimeoutException], [ServerException]) on failure.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Performs a POST request and returns the decoded body.
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Performs a DELETE request and returns the decoded body.
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Extracts the typed exception attached by [ErrorInterceptor]; falls back to
  /// a generic [ServerException] if, for any reason, none is present.
  Exception _unwrap(DioException e) {
    final error = e.error;
    if (error is Exception) return error;
    return ServerException(e.message ?? 'Unexpected error.');
  }
}
