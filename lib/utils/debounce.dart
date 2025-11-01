import 'dart:async';

/// A utility class for debouncing function calls.
///
/// Debouncing delays the execution of a function until after a specified
/// delay has elapsed since the last time it was invoked.
///
/// Common use case: Search input that triggers API calls.
///
/// Example:
/// ```dart
/// final _debouncer = Debouncer(delay: Duration(milliseconds: 300));
///
/// TextField(
///   onChanged: (value) {
///     _debouncer(() {
///       _performSearch(value);
///     });
///   },
/// )
/// ```
class Debouncer {
  /// The delay duration before executing the action
  final Duration delay;

  /// Internal timer for managing the delay
  Timer? _timer;

  /// Creates a Debouncer with the specified delay
  Debouncer({required this.delay});

  /// Debounces the given action.
  ///
  /// Cancels any pending action and schedules a new one after [delay].
  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending debounced action
  void cancel() {
    _timer?.cancel();
  }

  /// Disposes of the debouncer and cancels any pending actions.
  ///
  /// Should be called in the widget's dispose() method.
  void dispose() {
    _timer?.cancel();
  }
}
