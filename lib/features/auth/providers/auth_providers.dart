import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../data/auth_remote_datasource.dart';
import '../data/auth_repository.dart';
import '../models/auth_user.dart';

final _authDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(_authDataSourceProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// Holds the current authentication state as `AsyncValue<AuthUser?>`:
///  * `loading`  → an auth operation is in flight (or session is restoring).
///  * `data(user)` → signed in.
///  * `data(null)` → signed out.
///  * `error`    → the last operation failed (UI shows a SnackBar).
class AuthController extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _restore();
  }

  final AuthRepository _repository;

  bool get isAuthenticated => state.valueOrNull != null;

  Future<void> _restore() async {
    try {
      final user = await _repository.restoreSession();
      if (mounted) state = AsyncValue.data(user);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e.asFailure, st);
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() => _repository.login(email: email, password: password));
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => _repository.register(name: name, email: email, password: password),
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    if (mounted) state = const AsyncValue.data(null);
  }

  /// Runs an auth action, updating state to loading → data/error.
  /// Returns `true` on success so callers can, e.g., pop a login screen.
  Future<bool> _run(Future<AuthUser> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final user = await action();
      if (mounted) state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e.asFailure, st);
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthUser?>>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

/// Simple boolean convenience selector.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).valueOrNull != null,
);
