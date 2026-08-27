/// Low-level exceptions thrown by the data layer (datasources).
///
/// These are caught by repositories and converted into [Failure]s so that the
/// presentation layer never has to deal with raw exceptions.
library;

/// Thrown when the server responds with a non-2xx status code.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown on connectivity problems: no internet, connection refused, DNS, etc.
class NetworkException implements Exception {
  const NetworkException([this.message = 'No internet connection.']);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown when a request exceeds its configured timeout.
class TimeoutException implements Exception {
  const TimeoutException([this.message = 'The request timed out.']);

  final String message;

  @override
  String toString() => 'TimeoutException: $message';
}

/// Thrown when the local database (Hive) cannot be read from or written to.
class CacheException implements Exception {
  const CacheException([this.message = 'Local storage error.']);

  final String message;

  @override
  String toString() => 'CacheException: $message';
}
