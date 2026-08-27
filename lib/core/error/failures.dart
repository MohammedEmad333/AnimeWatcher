import 'package:equatable/equatable.dart';

import 'exceptions.dart';

/// User-facing, presentation-safe representation of an error.
///
/// Repositories translate raw [Exception]s into [Failure]s. The UI then renders
/// [Failure.message] in a SnackBar / Dialog / error view without ever touching
/// networking internals.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// A short, human-friendly message safe to show to the user.
  final String message;

  @override
  List<Object?> get props => [message];

  /// Maps a low-level [Exception] into the appropriate [Failure] subtype.
  factory Failure.fromException(Object error) {
    return switch (error) {
      NetworkException e => NetworkFailure(e.message),
      TimeoutException e => TimeoutFailure(e.message),
      ServerException e => ServerFailure(e.message, statusCode: e.statusCode),
      CacheException e => CacheFailure(e.message),
      _ => const UnknownFailure(),
    };
  }
}

/// Connectivity issues (offline, DNS, connection refused).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// A request that took too long to complete.
class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out. Try again.']);
}

/// A non-2xx response from the backend.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// A local database (Hive) error.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not access local storage.']);
}

/// Anything not otherwise classified.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong. Please try again.']);
}

/// Convenience for turning an arbitrary error object (e.g. the error captured
/// by Riverpod's `AsyncValue.error`) into a [Failure] for display.
extension AsFailure on Object {
  Failure get asFailure =>
      this is Failure ? this as Failure : Failure.fromException(this);
}
