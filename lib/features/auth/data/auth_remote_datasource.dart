import '../../../core/constants/api_constants.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/auth_user.dart';

/// Remote datasource for authentication endpoints.
///
/// `login` / `register` opt out of the auth interceptor via
/// [AuthInterceptor.skipAuth] because no token exists yet; `logout` and
/// `getCurrentUser` are authenticated.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final DioClient _client;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
      options: AuthInterceptor.skipAuth(),
    );
    // Backend envelope is `{ success, data: { token, user } }`; unwrap `data`
    // then let AuthResult.fromJson read the `token` + `user` inside.
    return AuthResult.fromJson(_unwrap(data));
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      ApiConstants.register,
      data: {'name': name, 'email': email, 'password': password},
      options: AuthInterceptor.skipAuth(),
    );
    return AuthResult.fromJson(_unwrap(data));
  }

  /// Tells the backend to invalidate the current session. Best-effort: the
  /// local token is cleared regardless (see repository).
  Future<void> logout() async {
    await _client.post(ApiConstants.logout);
  }

  Future<AuthUser> getCurrentUser() async {
    final data = await _client.get(ApiConstants.currentUser);
    return AuthUser.fromJson(_unwrap(data));
  }

  /// Unwraps the standard `{ success, data: {...} }` response envelope to the
  /// inner object (tolerating a bare object if `data` is absent).
  Map<String, dynamic> _unwrap(dynamic data) {
    final raw = data is Map && data['data'] != null ? data['data'] : data;
    return raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
  }
}
