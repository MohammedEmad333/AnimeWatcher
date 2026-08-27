import 'package:equatable/equatable.dart';

/// The authenticated user's public profile.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.name = '',
    this.avatarUrl = '',
  });

  final String id;
  final String email;
  final String name;
  final String avatarUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'].toString(),
      email: (json['email'] ?? '') as String,
      name: (json['name'] ?? json['username'] ?? '') as String,
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'] ?? '') as String,
    );
  }

  @override
  List<Object?> get props => [id, email];
}

/// Result of a successful login / register: the user plus their JWT.
class AuthResult extends Equatable {
  const AuthResult({required this.user, required this.token});

  final AuthUser user;
  final String token;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    // Tolerate `{ token, user }` and `{ access_token, data }` shapes.
    final token =
        (json['token'] ?? json['access_token'] ?? json['jwt'] ?? '') as String;
    final userJson = (json['user'] ?? json['data'] ?? json) as Map;
    return AuthResult(
      user: AuthUser.fromJson(userJson.cast<String, dynamic>()),
      token: token,
    );
  }

  @override
  List<Object?> get props => [user, token];
}
