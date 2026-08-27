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
    // The view is often placed inside a fixed-height slot (e.g. the Home
    // carousel's SizedBox, or the player's video box). A long, wrapped error
    // message can make the column taller than that slot, so we make the content
    // scrollable and only pad-and-center it when there's room — this prevents a
    // "BOTTOM OVERFLOWED" RenderFlex error while still looking centered when the
    // available height is generous.
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _iconFor(failure),
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            // Fill the slot when it's tall enough (so the content stays
            // vertically centered), but let the scroll view grow past it when
            // the message is long instead of overflowing.
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight - 32).clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Center(child: content),
          ),
        );
      },
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
