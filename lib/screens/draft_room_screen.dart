import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
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
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPosition;
  Player? _selectedPlayer;
  bool _hasShownCompletionDialog = false;
  late AnimationController _timerAnimationController;
  final List<Player> _draftQueue = [];
  List<String> _positions = [];
  int? _lastAutoPickNumber; // Track which pick number we last auto-picked for

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _loadDraftAndJoinRoom();
    _initializePositionFilters();

    // Listen for draft completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupDraftListener();
    });

    // Listen to search changes
    _searchController.addListener(() {
      setState(() {
        _filterPlayers();
      });
    });
  }

  void _initializePositionFilters() {
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
    final league = leagueProvider.selectedLeague;

    if (league?.rosterPositions != null && league!.rosterPositions!.isNotEmpty) {
      final Set<String> positions = {'ALL'};

      for (var positionData in league.rosterPositions!) {
        final position = positionData['position'] as String?;
        if (position != null && position != 'BN') {
          // Add the position slot itself
          positions.add(position);

          // Expand multi-position slots into individual positions
          switch (position) {
            case 'FLEX':
              positions.addAll(['RB', 'WR', 'TE']);
              break;
            case 'SUPER_FLEX':
              positions.addAll(['QB', 'RB', 'WR', 'TE']);
              break;
            case 'IDP_FLEX':
              positions.addAll(['DL', 'LB', 'DB']);
              break;
            case 'REC_FLEX':
              positions.addAll(['WR', 'TE']);
              break;
            case 'WRT':
              positions.addAll(['WR', 'RB', 'TE']);
              break;
          }
        }
      }

      // Order positions logically
      final List<String> orderedPositions = ['ALL'];
      final positionOrder = ['QB', 'RB', 'WR', 'TE', 'FLEX', 'SUPER_FLEX', 'WRT', 'REC_FLEX',
                             'K', 'DEF', 'DL', 'LB', 'DB', 'IDP_FLEX'];

      for (var pos in positionOrder) {
        if (positions.contains(pos)) {
          orderedPositions.add(pos);
        }
      }

      setState(() {
        _positions = orderedPositions;
      });
    } else {
      // Fallback to default positions
      setState(() {
        _positions = ['ALL', 'QB', 'RB', 'WR', 'TE', 'FLEX', 'K', 'DEF'];
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _timerAnimationController.dispose();

    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Leave WebSocket room
    if (draftProvider.currentDraft != null && authProvider.user != null) {
      draftProvider.leaveDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }

    super.dispose();
  }

  void _setupDraftListener() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    draftProvider.addListener(_checkDraftCompletion);
    draftProvider.addListener(_checkAutoDraft);
  }

  void _checkDraftCompletion() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    if (draftProvider.currentDraft?.status == 'completed' &&
        !_hasShownCompletionDialog) {
      _hasShownCompletionDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDraftCompletionDialog();
        }
      });
    }
  }

  void _checkAutoDraft() {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draft = draftProvider.currentDraft;

    if (draft == null || draft.status != 'in_progress') return;

    final currentPickNumber = draft.currentPick;
    final currentRosterId = draft.currentRosterId;

    // Find the roster that's currently on the clock
    DraftOrder? currentRoster;
    try {
      currentRoster = draftProvider.draftOrder.firstWhere(
        (order) => order.rosterId == currentRosterId,
      );
    } catch (e) {
      return;
    }

    // Check if this roster has autodraft enabled
    if (currentRoster == null || !currentRoster.isAutodrafting) {
      _lastAutoPickNumber = null;
      return;
    }

    // Check if it's the current user's roster (only the user can make picks for their roster)
    final isUsersTurn = authProvider.user != null &&
        currentRoster.userId == authProvider.user!.id;

    if (!isUsersTurn) return;

    // Check if we've already auto-picked for this specific pick number
    if (_lastAutoPickNumber == currentPickNumber) return;

    print('[AutoDraft] Triggering auto-pick for pick #$currentPickNumber (roster $currentRosterId)');

    // Mark that we're auto-picking for this pick number
    _lastAutoPickNumber = currentPickNumber;

    // Auto-pick the first player in queue, or best available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentRoster?.isAutodrafting == true) {
        Player? playerToPick;

        if (_draftQueue.isNotEmpty) {
          // Pick from queue
          playerToPick = _draftQueue.first;
        } else {
          // Pick best available (first in filtered list)
          final filteredPlayers = _getFilteredPlayers(draftProvider);
          if (filteredPlayers.isNotEmpty) {
            playerToPick = filteredPlayers.first;
          }
        }

        if (playerToPick != null) {
          _makeAutoPick(playerToPick);
        }
      }
    });
  }

  Future<void> _makeAutoPick(Player player) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final token = authProvider.token;
    final draft = draftProvider.currentDraft;
    final draftId = draft?.id;
    final rosterId = draft?.currentRosterId;

    if (token == null || draftId == null || rosterId == null) return;

    // Remove from queue if it was queued
    setState(() {
      _draftQueue.remove(player);
      _selectedPlayer = null;
    });

    final success = await draftProvider.makePick(
      token: token,
      draftId: draftId,
      rosterId: rosterId,
      playerId: player.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Auto-picked ${player.fullName}'
                : 'Failed to auto-pick ${player.fullName}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
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
        content: const Text('The draft has been completed. All picks have been made.'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to League'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDraftAndJoinRoom() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await draftProvider.loadDraftByLeague(widget.leagueId);

    if (mounted && draftProvider.currentDraft != null && authProvider.user != null) {
      draftProvider.joinDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }
  }

  Future<void> _makePick() async {
    if (_selectedPlayer == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null || draftProvider.currentDraft == null) return;

    // Get current roster making the pick
    final currentRoster = draftProvider.draftOrder.firstWhere(
      (order) => order.rosterId == draftProvider.currentDraft!.currentRosterId,
    );

    final success = await draftProvider.makePick(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
      playerId: _selectedPlayer!.id,
      rosterId: currentRoster.rosterId,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _selectedPlayer = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to make pick'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterPlayers() {
    // Filtering is handled by the provider internally
    // Just trigger a rebuild
    setState(() {});
  }

  List<Player> _getFilteredPlayers(DraftProvider draftProvider) {
    var players = draftProvider.availablePlayers;

    // Filter by position
    if (_selectedPosition != null && _selectedPosition != 'ALL') {
      // Handle multi-position slots
      List<String> eligiblePositions = [];

      switch (_selectedPosition) {
        case 'FLEX':
          eligiblePositions = ['RB', 'WR', 'TE'];
          break;
        case 'SUPER_FLEX':
          eligiblePositions = ['QB', 'RB', 'WR', 'TE'];
          break;
        case 'WRT':
          eligiblePositions = ['WR', 'RB', 'TE'];
          break;
        case 'REC_FLEX':
          eligiblePositions = ['WR', 'TE'];
          break;
        case 'IDP_FLEX':
          eligiblePositions = ['DL', 'LB', 'DB'];
          break;
        default:
          // Single position filter
          eligiblePositions = [_selectedPosition!];
      }

      players = players.where((p) => eligiblePositions.contains(p.position)).toList();
    }

    // Filter by search
    final searchText = _searchController.text.trim().toLowerCase();
    if (searchText.isNotEmpty) {
      players = players.where((p) =>
        p.fullName.toLowerCase().contains(searchText) ||
        (p.team?.toLowerCase().contains(searchText) ?? false)
      ).toList();
    }

    return players;
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'QB':
        return Colors.red.shade400;
      case 'RB':
        return Colors.green.shade400;
      case 'WR':
        return Colors.blue.shade400;
      case 'TE':
        return Colors.orange.shade400;
      case 'FLEX':
      case 'SUPER_FLEX':
      case 'WRT':
      case 'REC_FLEX':
        return Colors.teal.shade400;
      case 'K':
        return Colors.purple.shade400;
      case 'DEF':
        return Colors.brown.shade400;
      case 'DL':
        return Colors.indigo.shade400;
      case 'LB':
        return Colors.cyan.shade400;
      case 'DB':
        return Colors.pink.shade400;
      case 'IDP_FLEX':
        return Colors.deepPurple.shade400;
      case 'ALL':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade400;
    }
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPositionColor(player.position),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      player.position,
                      style: TextStyle(
                        color: _getPositionColor(player.position),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          player.positionTeam,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PlayerStatsWidget(
                playerId: player.playerId,
                currentSeason: 2024,
                currentWeek: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Consumer2<DraftProvider, AuthProvider>(
      builder: (context, draftProvider, authProvider, _) {
        final draft = draftProvider.currentDraft;

        // Check autodraft on every rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutoDraft();
        });

        return Scaffold(
          appBar: _buildAppBar(context, draft, draftProvider, authProvider),
          body: draft == null
              ? const Center(child: CircularProgressIndicator())
              : draft.isNotStarted
                  ? _buildNotStartedScreen(draftProvider, authProvider)
                  : Column(
                      children: [
                        _buildStickyStatusBar(draftProvider, authProvider),
                        Expanded(
                          child: isWideScreen
                              ? _buildSplitScreenLayout(draftProvider, authProvider)
                              : _buildTabLayout(draftProvider),
                        ),
                        _buildBottomPickButton(draftProvider, authProvider),
                      ],
                    ),
        );
      },
    );
  }

  Future<void> _handleStartDraft(
    BuildContext context,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Draft'),
        content: const Text(
          'Are you ready to start the draft? Once started, managers can begin making picks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start Draft'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await draftProvider.startDraft(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft started!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              draftProvider.errorMessage ?? 'Failed to start draft',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    draft,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) {
    final leagueProvider = Provider.of<LeagueProvider>(context);
    final isCommissioner = leagueProvider.isCommissioner;
    final hasOrder = draftProvider.draftOrder.isNotEmpty;

    return AppBar(
      title: Text('Draft - ${widget.leagueName}'),
      actions: [
        // Start Draft button (commissioner only, when draft not started)
        if (draft != null && draft.isNotStarted && isCommissioner && hasOrder)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: () => _handleStartDraft(context, draftProvider, authProvider),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Start Draft'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        // Auto-draft and pause/resume buttons (when draft is started)
        if (draft != null && !draft.isNotStarted) ...[
          _buildAutoDraftButton(context, draftProvider, authProvider),
          _buildPauseResumeButton(context, draft.status, draftProvider, authProvider),
        ],
      ],
    );
  }

  Widget _buildNotStartedScreen(DraftProvider draftProvider, AuthProvider authProvider) {
    final leagueProvider = Provider.of<LeagueProvider>(context);
    final isCommissioner = leagueProvider.isCommissioner;
    final hasOrder = draftProvider.draftOrder.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_football,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Draft Not Started',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              hasOrder
                  ? 'Draft order is set and ready to begin'
                  : 'Waiting for commissioner to set draft order',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Show draft order if set
            if (hasOrder) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draft Order',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: draftProvider.draftOrder.length,
                          itemBuilder: (context, index) {
                            final order = draftProvider.draftOrder[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text(
                                  '${order.draftPosition}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(order.displayName),
                              subtitle: Text('Team ${order.rosterNumber ?? "?"}'),
                              trailing: order.isAutodrafting
                                  ? const Tooltip(
                                      message: 'Autodraft enabled',
                                      child: Icon(
                                        Icons.auto_mode,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Messages for commissioner and non-commissioner
            if (isCommissioner && !hasOrder)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go to Settings to Set Draft Order'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              )
            else if (!isCommissioner)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(
                  'Waiting for commissioner to start the draft...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoDraftButton(
    BuildContext context,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) {
    // Find the user's roster
    DraftOrder? userRoster;
    try {
      userRoster = draftProvider.draftOrder.firstWhere(
        (order) => order.userId == authProvider.user?.id,
      );
    } catch (e) {
      userRoster = null;
    }

    // Use the roster's autodraft status if available
    final isAutodrafting = userRoster?.isAutodrafting ?? false;

    return IconButton(
      icon: Icon(
        isAutodrafting ? Icons.auto_mode : Icons.auto_mode_outlined,
        color: isAutodrafting ? Colors.green : null,
      ),
      tooltip: isAutodrafting ? 'Autodraft ON' : 'Autodraft OFF',
      onPressed: () {
        final draft = draftProvider.currentDraft;
        if (draft == null || userRoster == null) return;

        final newStatus = !isAutodrafting;

        // Emit WebSocket event to toggle autodraft
        draftProvider.toggleAutodraft(
          draftId: draft.id,
          rosterId: userRoster.rosterId,
          isAutodrafting: newStatus,
          username: authProvider.user?.username ?? 'Unknown',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Autodraft enabled - best available player will be picked automatically'
                  : 'Autodraft disabled',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Widget _buildPauseResumeButton(
    BuildContext context,
    String draftStatus,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) {
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

  Widget _buildStickyStatusBar(DraftProvider draftProvider, AuthProvider authProvider) {
    final draft = draftProvider.currentDraft!;
    final timeRemaining = draftProvider.timeRemaining ?? Duration.zero;

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
            color: Colors.black.withOpacity(0.2),
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
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _timerAnimationController,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (math.sin(_timerAnimationController.value * 2 * math.pi) * 0.1),
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

  Widget _buildSplitScreenLayout(DraftProvider draftProvider, AuthProvider authProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildPlayersPanel(draftProvider, authProvider),
        ),
        Expanded(
          flex: 3,
          child: const DraftBoardWidget(),
        ),
      ],
    );
  }

  Widget _buildTabLayout(DraftProvider draftProvider) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Players'),
            Tab(icon: Icon(Icons.grid_on), text: 'Board'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlayersPanel(
                draftProvider,
                Provider.of<AuthProvider>(context, listen: false),
              ),
              const DraftBoardWidget(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersPanel(DraftProvider draftProvider, AuthProvider authProvider) {
    final draft = draftProvider.currentDraft;

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
        // Draft Queue Section
        if (_draftQueue.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.playlist_play,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Draft Queue (${_draftQueue.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _draftQueue.clear();
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _draftQueue.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final player = _draftQueue.removeAt(oldIndex);
                        _draftQueue.insert(newIndex, player);
                      });
                    },
                    itemBuilder: (context, index) {
                      final player = _draftQueue[index];
                      return Container(
                        key: ValueKey(player.id),
                        margin: const EdgeInsets.only(right: 8),
                        child: Chip(
                          backgroundColor: _getPositionColor(player.position).withOpacity(0.2),
                          avatar: CircleAvatar(
                            backgroundColor: _getPositionColor(player.position),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                player.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getPositionColor(player.position),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  player.position,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _draftQueue.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        // Search and Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search players...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _positions.map((position) {
                    final isSelected = _selectedPosition == position ||
                        (_selectedPosition == null && position == 'ALL');
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(position),
                        onSelected: (selected) {
                          setState(() {
                            _selectedPosition = position == 'ALL' ? null : position;
                            _filterPlayers();
                          });
                        },
                        backgroundColor: _getPositionColor(position).withOpacity(0.1),
                        selectedColor: _getPositionColor(position),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : _getPositionColor(position),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Players List
        Expanded(
          child: Builder(
            builder: (context) {
              final filteredPlayers = _getFilteredPlayers(draftProvider);

              if (filteredPlayers.isEmpty) {
                return const Center(child: Text('No players available'));
              }

              return ListView.builder(
                itemCount: filteredPlayers.length,
                itemBuilder: (context, index) {
                  final player = filteredPlayers[index];
                  final isSelected = _selectedPlayer?.id == player.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: isSelected ? 4 : 1,
                      color: isSelected
                          ? _getPositionColor(player.position).withOpacity(0.2)
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getPositionColor(player.position),
                          child: Text(
                            player.position,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          player.fullName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(player.team ?? 'FA'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () => _showPlayerStats(player),
                              tooltip: 'View Stats',
                            ),
                            IconButton(
                              icon: Icon(
                                _draftQueue.any((p) => p.id == player.id)
                                    ? Icons.playlist_add_check
                                    : Icons.playlist_add,
                                color: _draftQueue.any((p) => p.id == player.id)
                                    ? _getPositionColor(player.position)
                                    : null,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_draftQueue.any((p) => p.id == player.id)) {
                                    _draftQueue.removeWhere((p) => p.id == player.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${player.fullName} removed from queue'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  } else {
                                    _draftQueue.add(player);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${player.fullName} added to queue'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                });
                              },
                              tooltip: _draftQueue.any((p) => p.id == player.id)
                                  ? 'Remove from queue'
                                  : 'Add to queue',
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: _getPositionColor(player.position),
                                size: 28,
                              ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPlayer = isSelected ? null : player;
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPickButton(DraftProvider draftProvider, AuthProvider authProvider) {
    final draft = draftProvider.currentDraft!;

    if (!draft.isInProgress) return const SizedBox.shrink();

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

    if (!isUsersTurn || _selectedPlayer == null) {
      return const SizedBox.shrink();
    }

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
          Card(
            color: _getPositionColor(_selectedPlayer!.position).withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getPositionColor(_selectedPlayer!.position),
                    radius: 28,
                    child: Text(
                      _selectedPlayer!.position,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPlayer!.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _selectedPlayer!.positionTeam,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _makePick,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: Colors.green.shade700,
            ),
            icon: const Icon(Icons.add_circle, size: 28),
            label: Text(
              'DRAFT ${_selectedPlayer!.fullName.toUpperCase()}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
