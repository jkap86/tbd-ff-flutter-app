/// Design system constants for consistent spacing, sizing, and typography
/// throughout the application.
///
/// This file follows an 8px base unit system for consistent visual rhythm
/// and alignment across all UI components.

/// Spacing constants based on an 8px grid system.
///
/// The 8px base unit ensures consistent spacing throughout the app and
/// maintains visual harmony. All spacing values are multiples or divisions
/// of the base 8px unit.
///
/// Usage:
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(Spacing.md),
///   child: ...
/// )
/// ```
class Spacing {
  Spacing._(); // Private constructor to prevent instantiation

  /// Extra small spacing: 4px (0.5 × base unit)
  /// Use for: Minimal gaps, tight groupings
  static const double xs = 4.0;

  /// Small spacing: 8px (1 × base unit)
  /// Use for: Compact layouts, dense lists
  static const double sm = 8.0;

  /// Medium spacing: 12px (1.5 × base unit)
  /// Use for: Related content, form field gaps
  static const double md = 12.0;

  /// Large spacing: 16px (2 × base unit)
  /// Use for: Standard component padding, section gaps
  static const double lg = 16.0;

  /// Extra large spacing: 24px (3 × base unit)
  /// Use for: Major sections, prominent separations
  static const double xl = 24.0;

  /// Extra extra large spacing: 32px (4 × base unit)
  /// Use for: Screen margins, major layout divisions
  static const double xxl = 32.0;
}

/// Touch target size constants following Material Design guidelines.
///
/// These ensure interactive elements are large enough for comfortable
/// touch interaction across different device sizes and user capabilities.
///
/// Reference: Material Design Accessibility Guidelines
class TouchTargets {
  TouchTargets._(); // Private constructor to prevent instantiation

  /// Minimum touch target size: 48px
  /// The absolute minimum size for any interactive element
  static const double minimum = 48.0;

  /// Recommended touch target size: 56px
  /// Provides better accessibility and easier interaction
  static const double recommended = 56.0;
}

/// Border radius constants for consistent rounded corners.
///
/// These values create a cohesive visual language for card corners,
/// button shapes, and other UI elements with rounded edges.
class AppBorderRadius {
  AppBorderRadius._(); // Private constructor to prevent instantiation

  /// Small border radius: 4px
  /// Use for: Subtle rounding, chips, small buttons
  static const double sm = 4.0;

  /// Medium border radius: 8px (1 × base unit)
  /// Use for: Standard buttons, cards, input fields
  static const double md = 8.0;

  /// Large border radius: 12px
  /// Use for: Prominent cards, modal dialogs
  static const double lg = 12.0;

  /// Extra large border radius: 16px (2 × base unit)
  /// Use for: Hero cards, feature panels
  static const double xl = 16.0;
}

/// Font size constants for consistent typography hierarchy.
///
/// These sizes establish a clear information hierarchy and ensure
/// readability across different screen sizes and contexts.
class FontSizes {
  FontSizes._(); // Private constructor to prevent instantiation

  /// Small font size: 11px
  /// Use for: Captions, helper text, legal copy
  static const double small = 11.0;

  /// Body font size: 14px
  /// Use for: Primary content, main body text
  static const double body = 14.0;

  /// Subtitle font size: 13px
  /// Use for: Secondary information, list subtitles
  static const double subtitle = 13.0;

  /// Title font size: 18px
  /// Use for: Card titles, section headers
  static const double title = 18.0;

  /// Heading font size: 24px (3 × base unit)
  /// Use for: Screen titles, major headings
  static const double heading = 24.0;
}
