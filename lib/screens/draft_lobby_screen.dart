import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/responsive_container.dart';
import 'draft_room_screen.dart';

class DraftLobbyScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const DraftLobbyScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<DraftLobbyScreen> createState() => _DraftLobbyScreenState();
}

class _DraftLobbyScreenState extends State<DraftLobbyScreen> {
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Leave WebSocket room when leaving the screen
    if (draftProvider.currentDraft != null && authProvider.user != null) {
      draftProvider.leaveDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }

    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await draftProvider.loadDraftByLeague(widget.leagueId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Join WebSocket room if draft exists
      if (draftProvider.currentDraft != null && authProvider.user != null) {
        draftProvider.joinDraftRoom(
          draftId: draftProvider.currentDraft!.id,
          userId: authProvider.user!.id,
          username: authProvider.user!.username,
        );
      }

      // If draft is already in progress or paused, navigate to draft room
      final draft = draftProvider.currentDraft;
      if (draft != null && (draft.isInProgress || draft.isPaused)) {
        _navigateToDraftRoom();
      }
    }
  }

  Future<void> _randomizeDraftOrder() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null || draftProvider.currentDraft == null) {
      return;
    }

    final success = await draftProvider.setDraftOrder(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
      randomize: true,
    );

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to randomize draft order'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startDraft() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final hasOrder = draftProvider.draftOrder.isNotEmpty;

    if (!hasOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set draft order first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null || draftProvider.currentDraft == null) {
      setState(() => _isStarting = false);
      return;
    }

    final success = await draftProvider.startDraft(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
    );

    if (mounted) {
      setState(() => _isStarting = false);

      if (success) {
        _navigateToDraftRoom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(draftProvider.errorMessage ?? 'Failed to start draft'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetDraft() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Draft'),
        content: const Text(
          'Are you sure you want to reset the draft? This will clear all picks and reset the draft to not started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isResetting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null || draftProvider.currentDraft == null) {
      setState(() => _isResetting = false);
      return;
    }

    final success = await draftProvider.resetDraft(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
    );

    if (mounted) {
      setState(() => _isResetting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft reset successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                draftProvider.errorMessage ?? 'Failed to reset draft'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToDraftRoom() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DraftRoomScreen(
          leagueId: widget.leagueId,
          leagueName: widget.leagueName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Draft Lobby - ${widget.leagueName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<DraftProvider>(
              builder: (context, draftProvider, child) {
                final draft = draftProvider.currentDraft;
                if (draft == null) {
                  return const Center(
                    child: Text('Draft not found'),
                  );
                }

                return SafeArea(
                  child: ResponsiveContainer(
                    child: Column(
                      children: [
                        // Draft Info Card
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Draft Settings',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildInfoRow(
                                    'Type', draft.draftType.toUpperCase()),
                                if (draft.isSnake && draft.thirdRoundReversal)
                                  _buildInfoRow('3rd Round Reversal', 'Yes'),
                                _buildInfoRow(
                                    'Pick Timer', '${draft.pickTimeSeconds}s'),
                                _buildInfoRow('Rounds', '${draft.rounds}'),
                                _buildInfoRow(
                                  'Status',
                                  draft.status.toUpperCase(),
                                  valueColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Draft Order Section
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Draft Order',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      if (draft.status == 'not_started')
                                        FilledButton.icon(
                                          onPressed: _randomizeDraftOrder,
                                          icon: const Icon(Icons.shuffle),
                                          label: Text(draftProvider
                                                  .draftOrder.isEmpty
                                              ? 'Randomize'
                                              : 'Re-randomize'),
                                        ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                                Expanded(
                                  child: draftProvider.draftOrder.isNotEmpty
                                      ? ListView.builder(
                                          itemCount:
                                              draftProvider.draftOrder.length,
                                          itemBuilder: (context, index) {
                                            final order =
                                                draftProvider.draftOrder[index];
                                            return ListTile(
                                              leading: CircleAvatar(
                                                child: Text(
                                                    '${order.draftPosition}'),
                                              ),
                                              title: Text(order.displayName),
                                              subtitle: Text(
                                                  'Team ${order.rosterNumber ?? "?"}'),
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.shuffle,
                                                size: 64,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No draft order set',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Commissioner needs to randomize or set the draft order',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Start Draft Button (Commissioner only)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: FilledButton(
                            onPressed: (_isStarting ||
                                    draftProvider.draftOrder.isEmpty)
                                ? null
                                : _startDraft,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _isStarting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.play_arrow),
                                        const SizedBox(width: 8),
                                        Text(draftProvider.draftOrder.isNotEmpty
                                            ? 'Start Draft'
                                            : 'Set Draft Order First'),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
