import 'package:flutter/material.dart';

import '../error/failures.dart';

/// Helpers for surfacing user-friendly feedback consistently across the app.
class AppSnackBar {
  const AppSnackBar._();

  /// Shows an error [SnackBar] built from a [Failure], with an optional retry
  /// action.
  static void showFailure(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    _show(
      context,
      message: failure.message,
      icon: Icons.error_outline,
      iconColor: Theme.of(context).colorScheme.error,
      onRetry: onRetry,
    );
  }

  /// Shows an informational / success [SnackBar].
  static void showMessage(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: Theme.of(context).colorScheme.secondary,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onRetry,
  }) {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        action: onRetry == null
            ? null
            : SnackBarAction(label: 'RETRY', onPressed: onRetry),
      ),
    );
  }
}
