import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../providers/league_provider.dart';
import '../models/player_model.dart';
import '../models/draft_order_model.dart';
import '../widgets/draft_board_widget.dart';
import '../widgets/league_chat_tab_widget.dart';
import '../widgets/player_stats_widget.dart';

class DraftRoomScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const DraftRoomScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<DraftRoomScreen> createState() => _DraftRoomScreenState();
}

class _DraftRoomScreenState extends State<DraftRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPosition;
  Player? _selectedPlayer;
  bool _hasShownCompletionDialog = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDraftAndJoinRoom();

    // Listen for draft completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupDraftListener();
    });
  }

  void _setupDraftListener() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    draftProvider.addListener(_checkDraftCompletion);
  }

  void _checkDraftCompletion() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    if (draftProvider.currentDraft?.status == 'completed' &&
        !_hasShownCompletionDialog) {
      _hasShownCompletionDialog = true;
      // Show completion dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDraftCompletionDialog();
        }
      });
    }
  }

  void _showDraftCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('Draft Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The draft has been completed. All picks have been made.',
            ),
            const SizedBox(height: 16),
            Text(
              'Your league is now in season!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to league details
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to League'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDraftAndJoinRoom() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    await draftProvider.loadDraftByLeague(widget.leagueId);

    if (draftProvider.currentDraft != null && authProvider.user != null) {
      // Join WebSocket room
      draftProvider.joinDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();

    // Remove draft listener
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    draftProvider.removeListener(_checkDraftCompletion);

    // Leave WebSocket room
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (draftProvider.currentDraft != null && authProvider.user != null) {
      draftProvider.leaveDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }

    super.dispose();
  }

  Future<void> _makePick() async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a player first')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null ||
        draftProvider.currentDraft == null) {
      return;
    }

    // TODO: Get actual roster ID for current user
    final rosterId = draftProvider.currentDraft!.currentRosterId;
    if (rosterId == null) return;

    final success = await draftProvider.makePick(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
      rosterId: rosterId,
      playerId: _selectedPlayer!.id,
    );

    if (mounted) {
      if (success) {
        setState(() => _selectedPlayer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picked ${_selectedPlayer!.fullName}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                draftProvider.errorMessage ?? 'Failed to make pick'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _filterPlayers() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    await draftProvider.filterPlayers(
      position: _selectedPosition,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DraftProvider, AuthProvider>(
      builder: (context, draftProvider, authProvider, _) {
        final draft = draftProvider.currentDraft;

        return Scaffold(
          appBar: AppBar(
            title: Text('Draft - ${widget.leagueName}'),
            actions: [
              if (draft != null)
                _buildPauseResumeButton(context, draft.status, draftProvider, authProvider),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: 'Players'),
                Tab(icon: Icon(Icons.grid_on), text: 'Board'),
                Tab(icon: Icon(Icons.chat), text: 'Chat'),
              ],
            ),
          ),
          body: _buildBody(draftProvider),
        );
      },
    );
  }

  Widget _buildBody(DraftProvider draftProvider) {
    final draft = draftProvider.currentDraft;

    if (draft == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Draft Status Bar
        _buildStatusBar(draftProvider),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Players Tab
              _buildPlayersTab(draftProvider),

              // Draft Board Tab
              const DraftBoardWidget(),

              // Chat Tab
              LeagueChatTabWidget(leagueId: widget.leagueId),
            ],
          ),
        ),

        // Pick Button (only if it's user's turn and player selected)
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            if (!draft.isInProgress) return const SizedBox.shrink();

            // Check if it's the current user's turn
            DraftOrder? currentRoster;
            try {
              currentRoster = draftProvider.draftOrder.firstWhere(
                (order) => order.rosterId == draft.currentRosterId,
              );
            } catch (e) {
              currentRoster = null;
            }

            final isUsersTurn = authProvider.user != null &&
                currentRoster != null &&
                currentRoster.userId == authProvider.user!.id;

            if (isUsersTurn && _selectedPlayer != null) {
              return _buildPickButton(draftProvider);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  void _showPlayerStats(Player player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Text(player.position),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          player.positionTeam,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Stats Widget
            Expanded(
              child: PlayerStatsWidget(
                playerId: player.playerId,
                currentSeason: 2024,
                currentWeek: null, // Will show full season stats
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseResumeButton(
    BuildContext context,
    String draftStatus,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) {
    // Only show for commissioner during active draft
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
    if (!leagueProvider.isCommissioner) {
      return const SizedBox.shrink();
    }

    if (draftStatus != 'in_progress' && draftStatus != 'paused') {
      return const SizedBox.shrink();
    }

    final isPaused = draftStatus == 'paused';

    return IconButton(
      icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
      tooltip: isPaused ? 'Resume Draft' : 'Pause Draft',
      onPressed: () async {
        final token = authProvider.token;
        final draftId = draftProvider.currentDraft?.id;

        if (token == null || draftId == null) return;

        final success = isPaused
            ? await draftProvider.resumeDraft(token: token, draftId: draftId)
            : await draftProvider.pauseDraft(token: token, draftId: draftId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? isPaused
                        ? 'Draft resumed'
                        : 'Draft paused'
                    : 'Failed to ${isPaused ? 'resume' : 'pause'} draft',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      },
    );
  }

  Widget _buildStatusBar(DraftProvider draftProvider) {
    final draft = draftProvider.currentDraft!;
    final timeRemaining = draftProvider.timeRemaining;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Find the roster on the clock from draft order
    final currentRoster = draftProvider.draftOrder.firstWhere(
      (order) => order.rosterId == draft.currentRosterId,
      orElse: () => draftProvider.draftOrder.first,
    );

    // Check if it's the current user's turn
    final isUsersTurn = authProvider.user != null &&
        currentRoster.userId == authProvider.user!.id;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isUsersTurn
          ? Colors.green.shade700
          : Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          // "YOU'RE ON THE CLOCK" banner
          if (isUsersTurn)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    "YOU'RE ON THE CLOCK!",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Round ${draft.currentRound}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isUsersTurn ? Colors.white : null,
                        ),
                  ),
                  Text(
                    'Pick ${draft.currentPick}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isUsersTurn ? Colors.white70 : null,
                        ),
                  ),
                ],
              ),
              if (timeRemaining != null)
                Column(
                  children: [
                    Text(
                      '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: timeRemaining.inSeconds < 10
                                ? Colors.red
                                : isUsersTurn
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                          ),
                    ),
                    Text(
                      'Time Remaining',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isUsersTurn ? Colors.white70 : null,
                          ),
                    ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'On the Clock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isUsersTurn ? Colors.white70 : null,
                        ),
                  ),
                  Text(
                    currentRoster.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isUsersTurn ? Colors.white : null,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: draft.progressPercentage,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersTab(DraftProvider draftProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draft = draftProvider.currentDraft;

    // Check if it's the current user's turn
    DraftOrder? currentRoster;
    try {
      currentRoster = draftProvider.draftOrder.firstWhere(
        (order) => order.rosterId == draft?.currentRosterId,
      );
    } catch (e) {
      currentRoster = null;
    }

    final isUsersTurn = authProvider.user != null &&
        currentRoster != null &&
        currentRoster.userId == authProvider.user!.id;

    return Column(
      children: [
        // Not your turn banner
        if (!isUsersTurn && draft != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Waiting for ${currentRoster?.displayName ?? "other team"} to pick...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        // Search and Filter
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                enabled: isUsersTurn,
                decoration: InputDecoration(
                  hintText: isUsersTurn
                      ? 'Search players...'
                      : 'Wait for your turn...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPlayers();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => _filterPlayers(),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedPosition == null,
                      onSelected: isUsersTurn
                          ? (selected) {
                              setState(() => _selectedPosition = null);
                              _filterPlayers();
                            }
                          : null,
                    ),
                    const SizedBox(width: 8),
                    ...['QB', 'RB', 'WR', 'TE', 'K', 'DEF'].map((pos) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(pos),
                          selected: _selectedPosition == pos,
                          onSelected: isUsersTurn
                              ? (selected) {
                                  setState(() => _selectedPosition =
                                      selected ? pos : null);
                                  _filterPlayers();
                                }
                              : null,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Players List
        Expanded(
          child: draftProvider.availablePlayers.isEmpty
              ? const Center(child: Text('No players available'))
              : ListView.builder(
                  itemCount: draftProvider.availablePlayers.length,
                  itemBuilder: (context, index) {
                    final player = draftProvider.availablePlayers[index];
                    final isSelected = _selectedPlayer?.id == player.id;

                    return ListTile(
                      selected: isSelected,
                      enabled: isUsersTurn,
                      leading: CircleAvatar(
                        child: Text(player.position),
                      ),
                      title: Text(player.fullName),
                      subtitle: Text(player.positionTeam),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _showPlayerStats(player),
                            tooltip: 'View Stats',
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      onTap: isUsersTurn
                          ? () {
                              setState(() {
                                _selectedPlayer = isSelected ? null : player;
                              });
                            }
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPickButton(DraftProvider draftProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedPlayer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Text(_selectedPlayer!.position),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPlayer!.fullName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _selectedPlayer!.positionTeam,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _makePick,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text('Draft ${_selectedPlayer!.fullName}'),
          ),
        ],
      ),
    );
  }
}
