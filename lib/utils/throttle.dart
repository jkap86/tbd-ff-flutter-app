import 'dart:async';

/// A utility class for throttling function calls.
///
/// Throttling ensures a function is called at most once in a specified
/// time period, regardless of how many times it's invoked.
///
/// Common use case: Scroll events, resize handlers, repeated button clicks.
///
/// Example:
/// ```dart
/// final _throttler = Throttler(delay: Duration(milliseconds: 500));
///
/// ElevatedButton(
///   onPressed: () {
///     _throttler(() {
///       _submitForm();
///     });
///   },
///   child: Text('Submit'),
/// )
/// ```
class Throttler {
  /// The minimum time between function executions
  final Duration delay;

  /// Internal timer for tracking the throttle period
  Timer? _timer;

  /// Flag indicating if the throttler is currently in cooldown
  bool _isRunning = false;

  /// Creates a Throttler with the specified delay
  Throttler({required this.delay});

  /// Throttles the given action.
  ///
  /// Executes immediately if not in cooldown, otherwise ignores the call.
  void call(void Function() action) {
    if (_isRunning) return;

    _isRunning = true;
    action();

    _timer = Timer(delay, () {
      _isRunning = false;
    });
  }

  /// Cancels the throttle cooldown
  void cancel() {
    _timer?.cancel();
    _isRunning = false;
  }

  /// Disposes of the throttler and cancels any pending cooldown.
  ///
  /// Should be called in the widget's dispose() method.
  void dispose() {
    _timer?.cancel();
  }
}
