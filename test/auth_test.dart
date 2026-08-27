import 'package:anime_watcher/core/network/auth_interceptor.dart';
import 'package:anime_watcher/features/auth/models/auth_user.dart';
import 'package:anime_watcher/shared/models/content_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthResult.fromJson', () {
    test('parses { token, user } shape', () {
      final result = AuthResult.fromJson({
        'token': 'abc.123',
        'user': {'id': 7, 'email': 'a@b.com', 'name': 'Aya'},
      });
      expect(result.token, 'abc.123');
      expect(result.user.id, '7');
      expect(result.user.email, 'a@b.com');
      expect(result.user.name, 'Aya');
    });

    test('parses { access_token, data } shape', () {
      final result = AuthResult.fromJson({
        'access_token': 'xyz',
        'data': {'id': '1', 'email': 'x@y.z'},
      });
      expect(result.token, 'xyz');
      expect(result.user.id, '1');
    });
  });

  group('AuthInterceptor.skipAuth', () {
    test('marks the request as not requiring auth', () {
      final options = AuthInterceptor.skipAuth();
      expect(options.extra?[AuthInterceptor.requiresAuthKey], isFalse);
    });
  });

  group('ContentLanguage', () {
    test('exposes API codes for the toggle', () {
      expect(ContentLanguage.arabic.code, 'ar');
      expect(ContentLanguage.english.code, 'en');
    });
  });
}
