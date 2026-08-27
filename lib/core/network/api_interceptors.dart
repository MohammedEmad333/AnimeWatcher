import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../error/exceptions.dart';

/// Logs every request/response/error during development.
///
/// Kept intentionally lightweight; swap for `PrettyDioLogger` if desired. All
/// output goes through `dart:developer` so it can be filtered in DevTools and
/// is stripped from release logs by the platform.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      '→ ${options.method} ${options.uri}',
      name: 'Dio',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      name: 'Dio',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '✗ ${err.type} ${err.requestOptions.uri} — ${err.message}',
      name: 'Dio',
      error: err,
    );
    super.onError(err, handler);
  }
}

/// Converts raw [DioException]s into the app's typed [Exception]s.
///
/// By centralizing this mapping in an interceptor, every datasource can simply
/// `try/catch` on our own exception types instead of inspecting Dio internals.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Exception mapped = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const TimeoutException(),
      DioExceptionType.connectionError =>
        const NetworkException(),
      DioExceptionType.badResponse => ServerException(
          _messageForStatus(err.response?.statusCode, err.response?.data),
          statusCode: err.response?.statusCode,
        ),
      DioExceptionType.cancel =>
        const NetworkException('Request was cancelled.'),
      DioExceptionType.badCertificate =>
        const NetworkException('Invalid server certificate.'),
      DioExceptionType.unknown => _isNoConnection(err)
          ? const NetworkException()
          : const ServerException('Unexpected network error.'),
      // Covers any future/added DioExceptionType values (e.g. transformTimeout).
      _ => const ServerException('Unexpected network error.'),
    };

    // Re-emit the original DioException but attach our typed error so callers
    // can read it from `DioException.error`.
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapped,
      ),
    );
  }

  bool _isNoConnection(DioException err) {
    final message = err.error?.toString().toLowerCase() ?? '';
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable');
  }

  /// Produces a friendly message based on the HTTP status code, preferring a
  /// server-supplied `message` field when present.
  String _messageForStatus(int? status, Object? data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return switch (status ?? 0) {
      400 => 'Bad request.',
      401 => 'You are not authorized.',
      403 => 'Access to this resource is forbidden.',
      404 => 'The requested content was not found.',
      429 => 'Too many requests. Please slow down.',
      >= 500 => 'The server is having trouble. Please try again later.',
      _ => 'Unexpected server error.',
    };
  }
}
