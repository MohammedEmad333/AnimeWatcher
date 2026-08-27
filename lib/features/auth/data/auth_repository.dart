import '../../../core/error/failures.dart';
import '../models/auth_user.dart';
import 'auth_remote_datasource.dart';
import 'token_storage.dart';

/// Coordinates authentication and the secure JWT lifecycle (Cloud Sync).
///
/// On successful [login] / [register] the returned JWT is persisted via
/// [TokenStorage], which the Dio auth interceptor then injects into subsequent
/// requests. [logout] always clears the local token, even if the network call
/// to invalidate the server session fails.
class AuthRepository {
  const AuthRepository(this._remote, this._tokenStorage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  /// Whether a token is currently stored (synchronous, cache-based).
  bool get isAuthenticated => _tokenStorage.hasToken;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    return _guard(() async {
      final result = await _remote.login(email: email, password: password);
      await _tokenStorage.saveToken(result.token);
      return result.user;
    });
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _guard(() async {
      final result = await _remote.register(
        name: name,
        email: email,
        password: password,
      );
      await _tokenStorage.saveToken(result.token);
      return result.user;
    });
  }

  /// Restores the session on app start: returns the current user if a valid
  /// token exists, otherwise `null`.
  Future<AuthUser?> restoreSession() async {
    if (!_tokenStorage.hasToken) return null;
    try {
      return await _remote.getCurrentUser();
    } on Failure {
      // Token invalid/expired — treat as signed out.
      await _tokenStorage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _remote.logout();
    } catch (_) {
      // Ignore server-side failures; local logout must always succeed.
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
