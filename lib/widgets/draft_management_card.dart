import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/league_model.dart';
import '../models/draft_model.dart';
import '../models/roster_model.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../services/draft_service.dart';
import '../screens/draft_setup_screen.dart';
import '../screens/draft_room_screen.dart';
import '../screens/auction_draft_screen.dart';
import '../screens/slow_auction_draft_screen.dart';

class DraftManagementCard extends StatelessWidget {
  final League league;
  final Draft? draft;
  final List<Roster> rosters;
  final VoidCallback onDraftDeleted;

  const DraftManagementCard({
    super.key,
    required this.league,
    required this.draft,
    required this.rosters,
    required this.onDraftDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Icon(
                  Icons.assessment,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Draft',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Draft status and actions based on state
            if (draft == null)
              _buildNoDraftState(context)
            else if (draft!.status == 'not_started')
              _buildDraftNotStartedState(context)
            else if (draft!.status == 'in_progress' || draft!.status == 'paused')
              _buildDraftInProgressState(context)
            else if (draft!.status == 'completed' || draft!.status == 'completing')
              _buildDraftCompletedState(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDraftState(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCommissioner = authProvider.user != null &&
                          league.isUserCommissioner(authProvider.user!.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No draft has been created yet',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          isCommissioner
              ? 'Create a draft to begin drafting players for your league'
              : 'The commissioner needs to create a draft',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 16),
        if (isCommissioner)
          FilledButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Draft'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DraftSetupScreen(
                    leagueId: league.id,
                    leagueName: league.name,
                  ),
                ),
              );
              // Reload draft after returning from draft setup
              if (context.mounted) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final draftProvider = Provider.of<DraftProvider>(context, listen: false);
                if (authProvider.token != null) {
                  await draftProvider.loadDraftByLeague(authProvider.token!, league.id);
                }
              }
            },
          ),
      ],
    );
  }

  Widget _buildDraftNotStartedState(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCommissioner = authProvider.user != null &&
                          league.isUserCommissioner(authProvider.user!.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Draft info summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Draft Not Started',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(context, 'Type', _formatDraftType(draft!.draftType)),
              if (draft!.draftType == 'snake' || draft!.draftType == 'linear')
                _buildInfoRow(context, 'Rounds', '${draft!.rounds}'),
              if (draft!.draftType == 'snake' || draft!.draftType == 'linear')
                _buildInfoRow(context, 'Pick Time', '${draft!.pickTimeSeconds}s'),
              if (draft!.timerMode == 'chess')
                _buildInfoRow(
                  context,
                  'Timer Mode',
                  'Chess (${draft!.teamTimeBudgetSeconds! ~/ 60} min per team)',
                ),
              if (draft!.draftType == 'auction' || draft!.draftType == 'slow_auction')
                _buildInfoRow(context, 'Starting Budget', '\$${draft!.startingBudget}'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Draft Order Display
        Consumer<DraftProvider>(
          builder: (context, draftProvider, _) {
            final draftOrder = draftProvider.draftOrder;
            if (draftOrder != null && draftOrder.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Draft Order',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: draftOrder.map((order) {
                        final roster = rosters.firstWhere(
                          (r) => r.id == order.rosterId,
                          orElse: () => rosters.first,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${order.draftPosition}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  roster.settings?['team_name'] ?? roster.username ?? 'Team ${roster.rosterId}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Action buttons
        Consumer<DraftProvider>(
          builder: (context, draftProvider, _) {
            // Show Start Derby button if:
            // 1. User is commissioner
            // 2. Derby is enabled on the draft
            // 3. Draft order has been randomized
            // 4. Draft hasn't started yet (status is 'not_started')

            // Debug logging
            debugPrint('[DraftManagementCard] Button visibility check:');
            debugPrint('  isCommissioner: $isCommissioner');
            debugPrint('  draft.derbyEnabled: ${draft!.derbyEnabled}');
            debugPrint('  draftOrder.length: ${draftProvider.draftOrder.length}');
            debugPrint('  draft.status: ${draft!.status}');

            final showStartDerbyButton = isCommissioner &&
                draft!.derbyEnabled &&
                draftProvider.draftOrder.isNotEmpty &&
                draft!.status == 'not_started';

            debugPrint('  showStartDerbyButton: $showStartDerbyButton');

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Enter Draft Room'),
                  onPressed: () => _navigateToDraftRoom(context),
                ),
                if (isCommissioner)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Randomize Order'),
                    onPressed: () => _handleRandomizeDraftOrder(context),
                  ),
                if (showStartDerbyButton)
                  FilledButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('Start Derby'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () => _handleStartDerby(context),
                  ),
                if (isCommissioner)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () => _showDeleteDraftDialog(context),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDraftInProgressState(BuildContext context) {
    final isPaused = draft!.status == 'paused';
    final totalPicks = draft!.rounds * rosters.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live draft indicator
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPaused
                  ? [Colors.orange.shade300, Colors.orange.shade600]
                  : [Colors.orange, Colors.deepOrange],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (!isPaused)
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                isPaused ? 'DRAFT PAUSED' : 'DRAFT IN PROGRESS',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Draft progress
        Text(
          'Round ${draft!.currentRound} of ${draft!.rounds}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Pick ${draft!.currentPick} of $totalPicks',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: draft!.currentPick / totalPicks,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              isPaused ? Colors.orange : Colors.green,
            ),
          ),
        ),

        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.sports_esports),
          label: const Text('Enter Draft Room'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => _navigateToDraftRoom(context),
        ),
      ],
    );
  }

  Widget _buildDraftCompletedState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            border: Border.all(color: Colors.green),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Draft Completed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (draft!.completedAt != null)
          Text(
            'Completed: ${_formatDate(draft!.completedAt!)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility),
          label: const Text('View Draft Results'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () => _navigateToDraftRoom(context),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _formatDraftType(String type) {
    switch (type) {
      case 'snake':
        return 'Snake Draft';
      case 'linear':
        return 'Linear Draft';
      case 'auction':
        return 'Auction Draft';
      case 'slow_auction':
        return 'Slow Auction';
      default:
        return type;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y \'at\' h:mm a').format(date);
  }

  void _navigateToDraftRoom(BuildContext context) {
    if (draft == null) return;

    Widget draftScreen;
    if (draft!.draftType == 'auction') {
      draftScreen = AuctionDraftScreen(
        draftId: draft!.id,
        leagueId: league.id,
        myRosterId: rosters.first.id,
        draftName: 'Auction Draft',
      );
    } else if (draft!.draftType == 'slow_auction') {
      draftScreen = SlowAuctionDraftScreen(
        draftId: draft!.id,
        leagueId: league.id,
        myRosterId: rosters.first.id,
      );
    } else {
      // Snake or linear draft
      draftScreen = DraftRoomScreen(
        leagueId: league.id,
        leagueName: league.name,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => draftScreen),
    );
  }

  void _showDeleteDraftDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: const Text(
          'Are you sure you want to delete this draft? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement draft deletion
              // For now, just show a message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draft deletion not yet implemented'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleRandomizeDraftOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Randomize Draft Order?'),
        content: const Text(
          'This will randomly assign draft positions to all teams. '
          'Are you sure you want to randomize the draft order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Randomize'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null || draft == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Randomizing draft order...'),
          duration: Duration(seconds: 1),
        ),
      );

      await DraftService().setDraftOrder(
        token: authProvider.token!,
        draftId: draft!.id,
        randomize: true,
      );

      if (context.mounted) {
        // Reload draft to get new order
        await draftProvider.loadDraftByLeague(authProvider.token!, league.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft order randomized successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to randomize draft order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleStartDerby(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Draft Slot Derby?'),
        content: const Text(
          'This will begin the derby phase where managers choose their draft positions. '
          'Are you sure you want to start the derby?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Start Derby'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null || draft == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting derby...'),
          duration: Duration(seconds: 1),
        ),
      );

      final success = await draftProvider.startDerby(
        token: authProvider.token!,
        draftId: draft!.id,
      );

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Derby started successfully! Managers can now select their draft positions.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate to draft room to see derby in action
          _navigateToDraftRoom(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start derby. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting derby: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
