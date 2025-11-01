import 'dart:async';

/// A throttler that allows bursts of actions within a time window.
///
/// For example, allows 3 messages in 3 seconds instead of strict 1 per second.
/// This feels more natural for chat interactions.
class BurstThrottler {
  final int maxActions;
  final Duration window;

  final List<DateTime> _timestamps = [];
  Timer? _cleanupTimer;

  BurstThrottler({
    required this.maxActions,
    required this.window,
  });

  /// Returns true if the action can proceed, false if throttled
  bool canProceed() {
    final now = DateTime.now();

    // Remove timestamps outside the window
    _timestamps.removeWhere((timestamp) =>
      now.difference(timestamp) > window
    );

    // Check if we can proceed
    if (_timestamps.length < maxActions) {
      _timestamps.add(now);

      // Schedule cleanup to remove old timestamps
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer(window, () {
        final cleanupTime = DateTime.now();
        _timestamps.removeWhere((timestamp) =>
          cleanupTime.difference(timestamp) > window
        );
      });

      return true;
    }

    return false;
  }

  /// Executes the action if not throttled
  void call(void Function() action, {void Function()? onThrottled}) {
    if (canProceed()) {
      action();
    } else {
      onThrottled?.call();
    }
  }

  /// Resets the throttle history
  void reset() {
    _timestamps.clear();
    _cleanupTimer?.cancel();
  }

  /// Disposes of the throttler
  void dispose() {
    _cleanupTimer?.cancel();
  }
}