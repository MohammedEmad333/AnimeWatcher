import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';
import '../network/dio_client.dart';

/// Shared, already-initialized [TokenStorage].
///
/// Overridden in `main` with the instance whose cache was preloaded during
/// bootstrap, so the auth interceptor can inject the JWT synchronously from the
/// very first request.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => throw UnimplementedError(
    'tokenStorageProvider must be overridden in main() with a preloaded '
    'TokenStorage instance.',
  ),
);

/// Singleton [DioClient] shared by every remote datasource. Depends on
/// [tokenStorageProvider] so the JWT interceptor is wired in.
final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(tokenStorage: ref.watch(tokenStorageProvider)),
);
