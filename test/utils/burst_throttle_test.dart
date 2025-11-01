import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/utils/burst_throttle.dart';

void main() {
  group('BurstThrottler', () {
    late BurstThrottler throttler;

    tearDown(() {
      throttler.dispose();
    });

    group('Basic burst functionality', () {
      test('should allow burst of exactly maxActions within window', () {
        throttler = BurstThrottler(maxActions: 3, window: Duration(seconds: 1));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
      });

      test('should block additional actions beyond maxActions', () {
        throttler = BurstThrottler(maxActions: 3, window: Duration(seconds: 1));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);
        expect(throttler.canProceed(), false);
      });

      test('should allow single action with maxActions = 1', () {
        throttler = BurstThrottler(maxActions: 1, window: Duration(seconds: 1));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);
      });

      test('should allow large burst with high maxActions', () {
        throttler = BurstThrottler(maxActions: 10, window: Duration(seconds: 1));

        for (int i = 0; i < 10; i++) {
          expect(throttler.canProceed(), true);
        }
        expect(throttler.canProceed(), false);
      });
    });

    group('Window expiration and reset', () {
      test('should reset after window expires', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);
      });

      test('should partially reset timestamps after window expires', () async {
        throttler = BurstThrottler(maxActions: 3, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Should allow more actions now
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
      });

      test('should allow new actions when old timestamps expire', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // First timestamp expired, should allow new action
        expect(throttler.canProceed(), true);
      });
    });

    group('Timestamp cleanup', () {
      test('should remove timestamps outside the window', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);
        await Future.delayed(Duration(milliseconds: 50));
        expect(throttler.canProceed(), true);

        // Both timestamps are still within window
        expect(throttler.canProceed(), false);

        // Wait for first timestamp to expire
        await Future.delayed(Duration(milliseconds: 100));

        // Now canProceed should clean up and allow new actions
        expect(throttler.canProceed(), true);
      });

      test('should cleanup timer fire after window duration', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);

        // Wait for cleanup timer to fire
        await Future.delayed(Duration(milliseconds: 150));

        // Timestamps should be cleaned up
        expect(throttler.canProceed(), true);
      });

      test('should reschedule cleanup timer on new action', () async {
        throttler = BurstThrottler(maxActions: 3, window: Duration(milliseconds: 150));

        expect(throttler.canProceed(), true);

        // Wait for some time but less than cleanup timer
        await Future.delayed(Duration(milliseconds: 100));

        // Add another action, which should reschedule cleanup timer
        expect(throttler.canProceed(), true);

        // Wait for original cleanup time to pass (100 + 100 = 200)
        // But new cleanup timer should be scheduled for +150ms from second action
        await Future.delayed(Duration(milliseconds: 100));

        // Should still have timestamp from first action
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);
      });
    });

    group('Timer cancellation on dispose', () {
      test('should cancel cleanup timer on dispose', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);

        // Dispose immediately after actions
        throttler.dispose();

        // Wait for original cleanup timer
        await Future.delayed(Duration(milliseconds: 150));

        // Create new throttler to test (disposed one shouldn't be used)
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));
        expect(throttler.canProceed(), true);
      });

      test('should not throw when disposing multiple times', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        expect(() {
          throttler.dispose();
          throttler.dispose();
          throttler.dispose();
        }, returnsNormally);
      });

      test('should cancel pending cleanup timer', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 200));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);

        // Dispose before cleanup timer fires
        throttler.dispose();

        // Wait longer than original window
        await Future.delayed(Duration(milliseconds: 250));

        // Should not throw - dispose prevents any further operations
      });
    });

    group('Edge cases at window boundaries', () {
      test('should handle action at exact window boundary', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        expect(throttler.canProceed(), true);

        // Wait exactly window duration
        await Future.delayed(Duration(milliseconds: 100));

        // Should be able to proceed after exact window
        expect(throttler.canProceed(), true);
      });

      test('should handle rapid successive actions', () {
        throttler = BurstThrottler(maxActions: 5, window: Duration(seconds: 1));

        for (int i = 0; i < 5; i++) {
          expect(throttler.canProceed(), true);
        }

        for (int i = 0; i < 5; i++) {
          expect(throttler.canProceed(), false);
        }
      });

      test('should handle very small window duration', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 10));

        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);

        await Future.delayed(Duration(milliseconds: 15));

        expect(throttler.canProceed(), true);
      });

      test('should handle very large maxActions', () {
        throttler = BurstThrottler(maxActions: 1000, window: Duration(seconds: 1));

        for (int i = 0; i < 1000; i++) {
          expect(throttler.canProceed(), true);
        }

        expect(throttler.canProceed(), false);
      });
    });

    group('canProceed() method behavior', () {
      test('should return true when within burst limit', () {
        throttler = BurstThrottler(maxActions: 3, window: Duration(seconds: 1));

        expect(throttler.canProceed(), isTrue);
        expect(throttler.canProceed(), isTrue);
        expect(throttler.canProceed(), isTrue);
      });

      test('should return false when exceeding burst limit', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        throttler.canProceed();
        throttler.canProceed();

        expect(throttler.canProceed(), isFalse);
      });

      test('should add timestamp when canProceed returns true', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        throttler.canProceed();
        throttler.canProceed();

        // Third call should fail, meaning two timestamps were added
        expect(throttler.canProceed(), isFalse);
      });

      test('should not add timestamp when canProceed returns false', () async {
        throttler = BurstThrottler(maxActions: 1, window: Duration(milliseconds: 100));

        throttler.canProceed();
        expect(throttler.canProceed(), false);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Should allow new action (proving second call didn't add timestamp)
        expect(throttler.canProceed(), true);
      });

      test('should clean up old timestamps before checking', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        throttler.canProceed();

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Call canProceed which should clean up first timestamp
        throttler.canProceed();

        // Should still be able to proceed once more (second timestamp never added)
        expect(throttler.canProceed(), true);
      });
    });

    group('call() method with callbacks', () {
      test('should execute action when not throttled', () {
        throttler = BurstThrottler(maxActions: 3, window: Duration(seconds: 1));

        bool actionExecuted = false;
        throttler.call(() {
          actionExecuted = true;
        });

        expect(actionExecuted, true);
      });

      test('should not execute action when throttled', () {
        throttler = BurstThrottler(maxActions: 1, window: Duration(seconds: 1));

        throttler.call(() {});

        bool actionExecuted = false;
        throttler.call(() {
          actionExecuted = true;
        });

        expect(actionExecuted, false);
      });

      test('should execute onThrottled callback when throttled', () {
        throttler = BurstThrottler(maxActions: 1, window: Duration(seconds: 1));

        throttler.call(() {});

        bool onThrottledCalled = false;
        throttler.call(
          () {},
          onThrottled: () {
            onThrottledCalled = true;
          },
        );

        expect(onThrottledCalled, true);
      });

      test('should not execute onThrottled when action succeeds', () {
        throttler = BurstThrottler(maxActions: 3, window: Duration(seconds: 1));

        bool onThrottledCalled = false;
        throttler.call(
          () {},
          onThrottled: () {
            onThrottledCalled = true;
          },
        );

        expect(onThrottledCalled, false);
      });

      test('should handle multiple throttled calls', () {
        throttler = BurstThrottler(maxActions: 1, window: Duration(seconds: 1));

        throttler.call(() {});

        int throttledCount = 0;
        for (int i = 0; i < 5; i++) {
          throttler.call(
            () {},
            onThrottled: () {
              throttledCount++;
            },
          );
        }

        expect(throttledCount, 5);
      });

      test('should execute action even if onThrottled is provided', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        bool actionExecuted = false;
        bool onThrottledCalled = false;

        throttler.call(
          () {
            actionExecuted = true;
          },
          onThrottled: () {
            onThrottledCalled = true;
          },
        );

        expect(actionExecuted, true);
        expect(onThrottledCalled, false);
      });

      test('should work with complex action callback', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        int value = 0;
        throttler.call(() {
          value += 10;
        });

        throttler.call(() {
          value *= 2;
        });

        expect(value, 20);
      });

      test('should handle null onThrottled callback gracefully', () {
        throttler = BurstThrottler(maxActions: 1, window: Duration(seconds: 1));

        throttler.call(() {});

        expect(() {
          throttler.call(
            () {},
            onThrottled: null,
          );
        }, returnsNormally);
      });

      test('should respect burst limit with call() method', () async {
        throttler = BurstThrottler(maxActions: 3, window: Duration(milliseconds: 100));

        int executedCount = 0;
        int throttledCount = 0;

        for (int i = 0; i < 6; i++) {
          throttler.call(
            () {
              executedCount++;
            },
            onThrottled: () {
              throttledCount++;
            },
          );
        }

        expect(executedCount, 3);
        expect(throttledCount, 3);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Should allow new actions
        throttler.call(
          () {
            executedCount++;
          },
          onThrottled: () {
            throttledCount++;
          },
        );

        expect(executedCount, 4);
        expect(throttledCount, 3);
      });
    });

    group('Reset functionality', () {
      test('should reset timestamps on reset()', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        throttler.canProceed();
        throttler.canProceed();
        expect(throttler.canProceed(), false);

        throttler.reset();

        // After reset, should allow actions again
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);
      });

      test('should cancel cleanup timer on reset()', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        throttler.canProceed();
        throttler.canProceed();

        throttler.reset();

        // Wait for original cleanup timer
        await Future.delayed(Duration(milliseconds: 150));

        // Should allow actions (cleanup timer was cancelled and reset)
        expect(throttler.canProceed(), true);
      });

      test('should allow reuse after reset()', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        throttler.canProceed();
        throttler.canProceed();

        throttler.reset();

        throttler.canProceed();
        throttler.canProceed();

        expect(throttler.canProceed(), false);
      });

      test('should handle multiple resets', () {
        throttler = BurstThrottler(maxActions: 1, window: Duration(seconds: 1));

        throttler.canProceed();
        throttler.reset();
        throttler.canProceed();
        throttler.reset();
        throttler.canProceed();

        expect(throttler.canProceed(), false);
      });
    });

    group('Integration scenarios', () {
      test('should simulate chat burst throttle (3 messages in 3 seconds)', () async {
        throttler =
            BurstThrottler(maxActions: 3, window: Duration(seconds: 3));

        // Send 3 messages rapidly
        bool msg1 = throttler.canProceed();
        bool msg2 = throttler.canProceed();
        bool msg3 = throttler.canProceed();
        bool msg4 = throttler.canProceed();

        expect(msg1, true);
        expect(msg2, true);
        expect(msg3, true);
        expect(msg4, false);

        // Wait less than 3 seconds
        await Future.delayed(Duration(seconds: 1));
        expect(throttler.canProceed(), false);

        // Wait for full window to expire
        await Future.delayed(Duration(seconds: 3));
        expect(throttler.canProceed(), true);
      });

      test('should support streaming actions with callbacks', () {
        throttler = BurstThrottler(maxActions: 2, window: Duration(seconds: 1));

        List<String> events = [];

        throttler.call(
          () => events.add('action1'),
          onThrottled: () => events.add('throttled1'),
        );

        throttler.call(
          () => events.add('action2'),
          onThrottled: () => events.add('throttled2'),
        );

        throttler.call(
          () => events.add('action3'),
          onThrottled: () => events.add('throttled3'),
        );

        throttler.call(
          () => events.add('action4'),
          onThrottled: () => events.add('throttled4'),
        );

        expect(events, ['action1', 'action2', 'throttled3', 'throttled4']);
      });

      test('should handle pattern of bursts and resets', () async {
        throttler = BurstThrottler(maxActions: 2, window: Duration(milliseconds: 100));

        // First burst
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);

        // Reset and burst again
        throttler.reset();
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Should allow new actions
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), true);
        expect(throttler.canProceed(), false);
      });
    });
  });
}
