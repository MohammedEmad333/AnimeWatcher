import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Optional predicate for retry cases beyond the default status/transport set
/// (e.g. a host that returns a transient 404 on a known-good endpoint).
typedef RetryWhen = bool Function(DioException error);

/// Retries transient request failures with exponential backoff + jitter.
///
/// Handles the failures that are worth trying again — connection/timeout errors
/// and the retryable HTTP statuses (`408/425/429/5xx`) — while deliberately
/// leaving genuine client errors (`400/401/403/404/…`) to fail fast. A
/// per-instance [RetryWhen] can opt specific extra cases back in.
///
/// Safety:
///  * Only idempotent methods are retried by default (`GET`), so a POST/DELETE
///    that may have already been applied server-side is never repeated.
///  * Cancelled requests are never retried.
///  * The attempt counter lives in `RequestOptions.extra`, so re-dispatching
///    through the same [Dio] (which re-runs this interceptor) can't loop.
///
/// Install it BEFORE the error-mapping interceptor so retries happen on the raw
/// [DioException]; only once the budget is spent does the mapped error surface.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 400),
    Duration maxDelay = const Duration(seconds: 8),
    Set<int> retryStatuses = const {408, 425, 429, 500, 502, 503, 504},
    Set<String> retryMethods = const {'GET'},
    RetryWhen? retryWhen,
  })  : _dio = dio,
        _maxRetries = maxRetries,
        _baseDelay = baseDelay,
        _maxDelay = maxDelay,
        _retryStatuses = retryStatuses,
        _retryMethods = retryMethods,
        _retryWhen = retryWhen;

  final Dio _dio;
  final int _maxRetries;
  final Duration _baseDelay;
  final Duration _maxDelay;
  final Set<int> _retryStatuses;
  final Set<String> _retryMethods;
  final RetryWhen? _retryWhen;

  static const String _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    final bool giveUp = attempt >= _maxRetries ||
        CancelToken.isCancel(err) ||
        !_retryMethods.contains(options.method.toUpperCase()) ||
        !_isRetryable(err);
    if (giveUp) {
      return handler.next(err);
    }

    await Future<void>.delayed(_delayFor(err, attempt));

    // If the caller cancelled while we were backing off, don't re-dispatch.
    if (options.cancelToken?.isCancelled ?? false) {
      return handler.next(err);
    }

    options.extra[_attemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        if (_retryStatuses.contains(status)) return true;
        return _retryWhen?.call(err) ?? false;
      default:
        return _retryWhen?.call(err) ?? false;
    }
  }

  /// Backoff for the given attempt: `Retry-After` when the server sends it
  /// (429/503), otherwise exponential (`base * 2^attempt`) capped at [_maxDelay]
  /// with full jitter to avoid synchronized retries against a recovering host.
  Duration _delayFor(DioException err, int attempt) {
    final retryAfter = _retryAfter(err.response);
    if (retryAfter != null) {
      return retryAfter > _maxDelay ? _maxDelay : retryAfter;
    }

    final exponential = _baseDelay * (1 << attempt); // 400ms, 800ms, 1600ms, …
    final capped = exponential > _maxDelay ? _maxDelay : exponential;
    final jitter = Duration(milliseconds: Random().nextInt(200));
    return capped + jitter;
  }

  /// Parses a numeric `Retry-After` header (seconds). The HTTP-date form is
  /// intentionally ignored to keep this platform-independent; exponential
  /// backoff covers that case.
  Duration? _retryAfter(Response<dynamic>? response) {
    final header = response?.headers.value('retry-after');
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    return seconds != null && seconds >= 0 ? Duration(seconds: seconds) : null;
  }
}
