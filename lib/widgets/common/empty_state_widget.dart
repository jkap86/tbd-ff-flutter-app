import 'package:flutter/material.dart';

/// A reusable empty state widget that displays when no data is available.
///
/// Provides a consistent UX across the app with customizable messaging
/// and optional call-to-action buttons.
class EmptyStateWidget extends StatelessWidget {
  /// The icon to display (default: inbox_outlined)
  final IconData icon;

  /// The main title text
  final String title;

  /// Optional subtitle/description text
  final String? subtitle;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action button callback
  final VoidCallback? onAction;

  /// Icon size (default: 64)
  final double iconSize;

  /// Custom icon color (defaults to theme outline color)
  final Color? iconColor;

  /// Custom title color (defaults to theme outline color)
  final Color? titleColor;

  /// Custom subtitle color (defaults to theme outline color)
  final Color? subtitleColor;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColor = theme.colorScheme.outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? defaultColor,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: titleColor ?? defaultColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: subtitleColor ?? defaultColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
