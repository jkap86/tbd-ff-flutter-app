import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/draft_model.dart';
import '../../models/draft_order_model.dart';
import '../../providers/draft_provider.dart';
import '../../providers/auth_provider.dart';

/// A widget that displays the current draft status bar.
/// Shows the current pick, timer, and user's turn indicator.
/// Supports both regular timer mode and chess timer mode.
class DraftStatusBar extends StatefulWidget {
  final DraftProvider draftProvider;
  final AuthProvider authProvider;
  final AnimationController timerAnimationController;

  const DraftStatusBar({
    super.key,
    required this.draftProvider,
    required this.authProvider,
    required this.timerAnimationController,
  });

  @override
  State<DraftStatusBar> createState() => _DraftStatusBarState();
}

class _DraftStatusBarState extends State<DraftStatusBar> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draftProvider.currentDraft!;

    // Check if chess timer mode
    if (widget.draftProvider.isChessTimerMode) {
      return _buildChessTimerStatusBar();
    }

    final timeRemaining = widget.draftProvider.timeRemaining ?? Duration.zero;

    DraftOrder? currentRoster;
    try {
      currentRoster = widget.draftProvider.draftOrder.firstWhere(
        (order) => order.rosterId == draft.currentRosterId,
      );
    } catch (e) {
      currentRoster = null;
    }

    final isUsersTurn = widget.authProvider.user != null &&
        currentRoster != null &&
        currentRoster.userId == widget.authProvider.user!.id;

    final progress = timeRemaining.inSeconds / draft.pickTimeSeconds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUsersTurn
              ? [Colors.green.shade700, Colors.green.shade900]
              : [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.primary,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isUsersTurn)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: widget.timerAnimationController,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (math.sin(widget.timerAnimationController.value * 2 * math.pi) * 0.1),
                      child: const Icon(Icons.alarm, color: Colors.black, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "YOU'RE ON THE CLOCK!",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Round ${draft.currentRound} • Pick ${draft.currentPick}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUsersTurn ? Colors.white : null,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          currentRoster?.displayName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            color: isUsersTurn ? Colors.white70 : null,
                          ),
                        ),
                        if (currentRoster?.isAutodrafting == true) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Autodraft enabled',
                            child: Icon(
                              Icons.auto_mode,
                              color: isUsersTurn ? Colors.white70 : Colors.green,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: timeRemaining.inSeconds < 10
                          ? Colors.red
                          : (isUsersTurn ? Colors.white : null),
                    ),
                  ),
                  Text(
                    'Time Remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: isUsersTurn ? Colors.white70 : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white30,
              valueColor: AlwaysStoppedAnimation<Color>(
                timeRemaining.inSeconds < 10 ? Colors.red : Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessTimerStatusBar() {
    final draft = widget.draftProvider.currentDraft!;

    DraftOrder? currentRoster;
    try {
      currentRoster = widget.draftProvider.draftOrder.firstWhere(
        (order) => order.rosterId == draft.currentRosterId,
      );
    } catch (e) {
      currentRoster = null;
    }

    final isUsersTurn = widget.authProvider.user != null &&
        currentRoster != null &&
        currentRoster.userId == widget.authProvider.user!.id;

    final timeRemaining = currentRoster != null
        ? widget.draftProvider.getRosterTimeRemaining(currentRoster.rosterId)
        : null;

    final isLow = timeRemaining != null && timeRemaining < 300; // < 5 minutes
    final isCritical = timeRemaining != null && timeRemaining < 60; // < 1 minute

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUsersTurn
              ? [Colors.green.shade700, Colors.green.shade900]
              : isCritical
                  ? [Colors.red.shade700, Colors.red.shade900]
                  : isLow
                      ? [Colors.orange.shade700, Colors.orange.shade900]
                      : [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.primary,
                        ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isUsersTurn)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: widget.timerAnimationController,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (math.sin(widget.timerAnimationController.value * 2 * math.pi) * 0.1),
                      child: const Icon(Icons.alarm, color: Colors.black, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "YOU'RE ON THE CLOCK!",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Round ${draft.currentRound} • Pick ${draft.currentPick}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUsersTurn ? Colors.white : Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          currentRoster?.displayName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            color: isUsersTurn ? Colors.white70 : Colors.white70,
                          ),
                        ),
                        if (currentRoster?.isAutodrafting == true) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Autodraft enabled',
                            child: Icon(
                              Icons.auto_mode,
                              color: isUsersTurn ? Colors.white70 : Colors.white70,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_bottom,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatChessTime(timeRemaining ?? 0),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (isCritical)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TIME CRITICAL!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Time Remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUsersTurn ? Colors.white70 : Colors.white70,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatChessTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }
}
