import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../providers/auth_provider.dart';
import '../models/draft_derby_model.dart';

class DraftDerbyScreen extends StatelessWidget {
  final int draftId;

  const DraftDerbyScreen({
    Key? key,
    required this.draftId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token ?? '';

    return ChangeNotifierProvider(
      create: (_) => DraftProvider()..loadDerby(token: token, draftId: draftId),
      child: const DraftDerbyContent(),
    );
  }
}

class DraftDerbyContent extends StatelessWidget {
  const DraftDerbyContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final draftProvider = Provider.of<DraftProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final derby = draftProvider.currentDerby;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft Slot Selection Derby'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: derby == null
          ? const Center(child: CircularProgressIndicator())
          : _buildDerbyContent(context, draftProvider, authProvider, derby),
    );
  }

  Widget _buildDerbyContent(
    BuildContext context,
    DraftProvider draftProvider,
    AuthProvider authProvider,
    DraftDerbyWithDetails derby,
  ) {
    // Get user's roster ID from draft orders
    final userId = authProvider.user?.id;
    final userRosterId = draftProvider.draftOrder
        ?.firstWhere(
          (order) => order.userId == userId,
          orElse: () => draftProvider.draftOrder!.first,
        )
        .rosterId;

    final isMyTurn = derby.derby.currentTurnRosterId == userRosterId;
    final hasSelected = derby.hasRosterSelected(userRosterId ?? 0);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          _buildStatusCard(context, derby, isMyTurn, hasSelected),
          const SizedBox(height: 16),

          // Timer (if active)
          if (isMyTurn && draftProvider.isDerbyActive)
            _buildTimerCard(context, draftProvider),

          // Selection Order
          const SizedBox(height: 16),
          _buildSelectionOrderCard(context, derby, userRosterId),

          const SizedBox(height: 16),

          // Available Positions Grid
          if (isMyTurn && !hasSelected)
            Expanded(
              child: _buildPositionGrid(
                context,
                draftProvider,
                authProvider,
                derby,
                userRosterId,
              ),
            ),

          // Already selected message
          if (hasSelected) _buildAlreadySelectedCard(context, derby, userRosterId),

          // Waiting for turn message
          if (!isMyTurn && !hasSelected) _buildWaitingCard(context),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    DraftDerbyWithDetails derby,
    bool isMyTurn,
    bool hasSelected,
  ) {
    String statusText;
    Color statusColor;

    if (hasSelected) {
      statusText = 'You have selected your draft position';
      statusColor = Colors.green;
    } else if (isMyTurn) {
      statusText = 'Your turn to select!';
      statusColor = Colors.orange;
    } else if (derby.derby.isPending) {
      statusText = 'Derby has not started yet';
      statusColor = Colors.grey;
    } else if (derby.derby.isCompleted) {
      statusText = 'Derby is complete';
      statusColor = Colors.blue;
    } else {
      statusText = 'Waiting for your turn...';
      statusColor = Colors.grey;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              hasSelected ? Icons.check_circle : Icons.info,
              color: statusColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard(BuildContext context, DraftProvider draftProvider) {
    final timeRemaining = draftProvider.derbyTimeRemaining;
    if (timeRemaining == null) return const SizedBox.shrink();

    final minutes = timeRemaining.inMinutes;
    final seconds = timeRemaining.inSeconds % 60;

    return Card(
      color: timeRemaining.inSeconds < 30
          ? Colors.red.withOpacity(0.1)
          : Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, size: 32),
            const SizedBox(width: 12),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOrderCard(
    BuildContext context,
    DraftDerbyWithDetails derby,
    int? userRosterId,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selection Order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...derby.derby.selectionOrder.asMap().entries.map((entry) {
              final index = entry.key;
              final rosterId = entry.value;
              final isCurrentTurn = derby.derby.currentTurnRosterId == rosterId;
              final hasSelected = derby.hasRosterSelected(rosterId);
              final isUser = rosterId == userRosterId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isCurrentTurn
                            ? Colors.orange
                            : hasSelected
                                ? Colors.green
                                : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Team ${rosterId}${isUser ? ' (You)' : ''}',
                      style: TextStyle(
                        fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (hasSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Slot ${derby.getSelectionForRoster(rosterId)?.draftPosition}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionGrid(
    BuildContext context,
    DraftProvider draftProvider,
    AuthProvider authProvider,
    DraftDerbyWithDetails derby,
    int? userRosterId,
  ) {
    final token = authProvider.token ?? '';
    final draftId = derby.derby.draftId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Your Draft Position',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: derby.derby.selectionOrder.length,
                itemBuilder: (context, index) {
                  final position = index + 1;
                  final isAvailable = derby.isPositionAvailable(position);

                  return InkWell(
                    onTap: isAvailable
                        ? () => _selectPosition(
                              context,
                              draftProvider,
                              token,
                              draftId,
                              userRosterId ?? 0,
                              position,
                            )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        border: Border.all(
                          color: isAvailable ? Colors.blue : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              position.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? Colors.blue : Colors.grey,
                              ),
                            ),
                            if (!isAvailable)
                              const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadySelectedCard(
    BuildContext context,
    DraftDerbyWithDetails derby,
    int? userRosterId,
  ) {
    final selection = derby.getSelectionForRoster(userRosterId ?? 0);
    if (selection == null) return const SizedBox.shrink();

    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              'You selected draft position ${selection.draftPosition}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for other managers to complete their selections...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingCard(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Waiting for other managers...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPosition(
    BuildContext context,
    DraftProvider draftProvider,
    String token,
    int draftId,
    int rosterId,
    int position,
  ) async {
    // Confirm selection
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Selection'),
        content: Text(
          'Are you sure you want to select draft position $position?\n\nThis cannot be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Make selection
    try {
      final success = await draftProvider.makeDerbySelection(
        token: token,
        draftId: draftId,
        rosterId: rosterId,
        draftPosition: position,
      );

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft position selected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              draftProvider.derbyError ?? 'Failed to select position',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
