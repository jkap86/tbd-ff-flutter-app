import 'package:flutter/material.dart';

/// A reusable error state widget for displaying errors with optional retry functionality.
///
/// Features:
/// - Customizable error icon
/// - Customizable error message
/// - Optional retry button
/// - Customizable colors and styling
/// - Consistent error UI across the app
class ErrorStateWidget extends StatelessWidget {
  /// The error message to display. If null, shows a generic error message.
  final String? message;

  /// Optional subtitle or additional error details
  final String? subtitle;

  /// Icon to display. Defaults to error_outline.
  final IconData icon;

  /// Size of the error icon. Defaults to 64.
  final double iconSize;

  /// Color of the error icon. Defaults to Colors.red.
  final Color? iconColor;

  /// Callback for retry action. If null, no retry button is shown.
  final VoidCallback? onRetry;

  /// Custom retry button text. Defaults to 'Retry'.
  final String retryButtonText;

  /// Additional actions to show below the retry button
  final List<Widget>? additionalActions;

  /// Whether to show the widget in a compact form (smaller padding, smaller text)
  final bool compact;

  const ErrorStateWidget({
    super.key,
    this.message,
    this.subtitle,
    this.icon = Icons.error_outline,
    this.iconSize = 64,
    this.iconColor,
    this.onRetry,
    this.retryButtonText = 'Retry',
    this.additionalActions,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Colors.red;
    final effectiveMessage = message ?? 'An error occurred';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16.0 : 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? iconSize * 0.75 : iconSize,
              color: effectiveIconColor,
            ),
            SizedBox(height: compact ? 12 : 16),
            Text(
              effectiveMessage,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: compact ? 6 : 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: compact ? 12 : 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(retryButtonText),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 20 : 24,
                    vertical: compact ? 10 : 12,
                  ),
                ),
              ),
            ],
            if (additionalActions != null && additionalActions!.isNotEmpty) ...[
              SizedBox(height: compact ? 8 : 12),
              ...additionalActions!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Convenience constructors for common error scenarios

extension ErrorStateWidgetExtensions on ErrorStateWidget {
  /// Creates an error widget for network/connection errors
  static Widget network({
    String? message,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorStateWidget(
      message: message ?? 'Unable to connect to the server',
      subtitle: 'Please check your internet connection and try again',
      icon: Icons.cloud_off,
      iconColor: Colors.orange,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Creates an error widget for timeout errors
  static Widget timeout({
    String? message,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorStateWidget(
      message: message ?? 'Request timed out',
      subtitle: 'The server took too long to respond',
      icon: Icons.access_time,
      iconColor: Colors.orange,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Creates an error widget for not found errors
  static Widget notFound({
    String? message,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorStateWidget(
      message: message ?? 'Not found',
      subtitle: 'The requested resource could not be found',
      icon: Icons.search_off,
      iconColor: Colors.grey,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Creates an error widget for permission/authentication errors
  static Widget unauthorized({
    String? message,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorStateWidget(
      message: message ?? 'Unauthorized',
      subtitle: 'You do not have permission to access this resource',
      icon: Icons.lock_outline,
      iconColor: Colors.red,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Creates an error widget for server errors
  static Widget serverError({
    String? message,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorStateWidget(
      message: message ?? 'Server error',
      subtitle: 'Something went wrong on our end. Please try again later.',
      icon: Icons.dns_outlined,
      iconColor: Colors.red,
      onRetry: onRetry,
      compact: compact,
    );
  }
}
