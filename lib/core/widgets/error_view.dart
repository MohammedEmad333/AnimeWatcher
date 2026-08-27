import 'package:flutter/material.dart';

import '../error/failures.dart';

/// A full-screen error placeholder with a retry affordance.
///
/// Used by list/detail screens when a request fails, keeping the "Loading /
/// Success / Error" UI states visually consistent.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.failure,
    this.onRetry,
  });

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(failure),
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(Failure failure) {
    return switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      TimeoutFailure() => Icons.timer_off_outlined,
      _ => Icons.error_outline_rounded,
    };
  }
}
