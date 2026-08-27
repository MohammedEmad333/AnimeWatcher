import 'package:dio/dio.dart';

import '../../features/auth/data/token_storage.dart';

/// Injects the stored JWT as a `Bearer` token on outgoing requests.
///
/// By default every request is authenticated when a token is available. A
/// request can opt out (e.g. `login` / `register`, which have no token yet) by
/// setting `Options(extra: {AuthInterceptor.requiresAuthKey: false})` — see
/// [skipAuth].
///
/// On a `401 Unauthorized` response the stored token is cleared, so the app can
/// detect the session has expired and prompt the user to sign in again.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final TokenStorage _tokenStorage;

  /// Key used in `Options.extra` to mark a request as not requiring auth.
  static const String requiresAuthKey = 'requiresAuth';

  /// Convenience [Options] for public endpoints that must not carry a token.
  static Options skipAuth([Options? base]) {
    final options = base ?? Options();
    return options.copyWith(
      extra: {...?options.extra, requiresAuthKey: false},
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requiresAuth = options.extra[requiresAuthKey] != false;
    final token = _tokenStorage.cachedToken;

    if (requiresAuth && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Session expired or token invalid — drop it so the UI can re-auth.
      // Fire-and-forget; clearing is idempotent.
      _tokenStorage.clear();
    }
    handler.next(err);
  }
}
