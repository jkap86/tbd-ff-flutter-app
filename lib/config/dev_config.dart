import 'package:flutter/foundation.dart';

/// Development configuration to control feature flags
class DevConfig {
  /// Whether to enable Firebase features (push notifications, etc.)
  /// Disabled in debug mode for local testing to avoid platform issues
  static bool get enableFirebase => !kDebugMode && !kIsWeb;

  /// Whether we're in local development mode
  static bool get isLocalDevelopment => kDebugMode;

  /// Whether to use mock services instead of real ones
  static bool get useMockServices => false;

  /// Debug logging configuration
  static bool get enableDebugLogging => kDebugMode;

  /// Whether to show development tools/options in UI
  static bool get showDevTools => kDebugMode;
}