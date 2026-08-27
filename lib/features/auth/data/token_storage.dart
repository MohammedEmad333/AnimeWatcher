import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely persists the user's JWT using platform keystores
/// (Keychain on iOS, EncryptedSharedPreferences on Android).
///
/// Keeps an in-memory copy of the token so the Dio auth interceptor can inject
/// it **synchronously** on every request without awaiting a disk read. Call
/// [init] once at startup to preload the cache.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _tokenKey = 'jwt_token';

  final FlutterSecureStorage _storage;

  String? _cachedToken;

  /// The token currently held in memory, or `null` if unauthenticated.
  String? get cachedToken => _cachedToken;

  /// Whether a token is present (a cheap, synchronous auth check).
  bool get hasToken => _cachedToken != null && _cachedToken!.isNotEmpty;

  /// Preloads the token from secure storage into the in-memory cache.
  Future<void> init() async {
    _cachedToken = await _storage.read(key: _tokenKey);
  }

  /// Persists [token] and updates the in-memory cache.
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Reads the token from disk (also refreshing the cache).
  Future<String?> readToken() async {
    return _cachedToken ??= await _storage.read(key: _tokenKey);
  }

  /// Clears the token from both memory and disk (logout / 401).
  Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }
}
