import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../providers/league_provider.dart';
import '../models/player_model.dart';
import '../models/draft_model.dart';
import '../models/draft_order_model.dart';
import '../widgets/draft_board_widget.dart';
import '../widgets/league_chat_tab_widget.dart';
import '../widgets/time_management_dialog.dart';
import '../widgets/chess_timer_team_list_widget.dart';
import '../widgets/draft/draft_status_bar.dart';
import '../widgets/draft/draft_queue_tab.dart';
import '../widgets/draft/draft_stats_row.dart';
import '../widgets/common/error_state_widget.dart';
import '../widgets/common/loading_skeletons.dart';
import '../services/player_stats_service.dart';
import '../services/nfl_service.dart';

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
  late TabController _drawerTabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPosition;
  Player? _selectedPlayer;
  bool _hasShownCompletionDialog = false;
  late AnimationController _timerAnimationController;
  final List<Player> _draftQueue = [];
  List<String> _positions = [];
  int? _lastAutoPickNumber; // Track which pick number we last auto-picked for
  double _drawerHeight = 0.5; // Start at 50% (players drawer)

  // Stats view mode
  String _statsMode = 'current_season'; // 'current_season', 'projections', 'previous_season'
  final PlayerStatsService _statsService = PlayerStatsService();
  final NflService _nflService = NflService();
  final Map<String, Map<String, dynamic>> _playerStats = {}; // Cache stats by playerId
  bool _isLoadingStats = false;
  int? _currentWeek;

  // Sorting
  String? _sortBy; // 'FPTS', 'GP', 'YDS', 'TD', etc.
  bool _sortAscending = false; // Default to descending (highest first)
  bool _isSorting = false; // Track if we're currently sorting

  // Scroll controllers for stats rows
  final Map<String, ScrollController> _statsScrollControllers = {};
  double _currentStatsScrollOffset = 0.0; // Track current scroll position for all rows
  bool _isScrolling = false; // Prevent concurrent scroll operations

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Will update drawer tab count after loading draft
    _drawerTabController = TabController(length: 3, vsync: this); // Players, Queue, and Chat tabs (will add Team Times if chess mode)
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Load stats in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllPlayerStats();
    });
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
    _drawerTabController.dispose();
    _searchController.dispose();
    _timerAnimationController.dispose();

    // Dispose all scroll controllers
    for (final controller in _statsScrollControllers.values) {
      controller.dispose();
    }
    _statsScrollControllers.clear();

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
    final currentRoster = draftProvider.draftOrder.cast<DraftOrder?>().firstWhere(
      (order) => order?.rosterId == currentRosterId,
      orElse: () => null,
    );

    if (currentRoster == null) return;

    // Check if this roster has autodraft enabled
    if (!currentRoster.isAutodrafting) {
      _lastAutoPickNumber = null;
      return;
    }

    // Check if it's the current user's roster (only the user can make picks for their roster)
    final isUsersTurn = authProvider.user != null &&
        currentRoster.userId == authProvider.user!.id;

    if (!isUsersTurn) return;

    // Check if we've already auto-picked for this specific pick number
    if (_lastAutoPickNumber == currentPickNumber) return;

    debugPrint('[AutoDraft] Triggering auto-pick for pick #$currentPickNumber (roster $currentRosterId)');

    // Mark that we're auto-picking for this pick number
    _lastAutoPickNumber = currentPickNumber;

    // Auto-pick the first player in queue, or best available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentRoster.isAutodrafting == true) {
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Draft Complete!'),
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

    if (authProvider.token == null) return;

    await draftProvider.loadDraftByLeague(authProvider.token!, widget.leagueId);

    if (mounted && draftProvider.currentDraft != null && authProvider.user != null) {
      await draftProvider.joinDraftRoom(
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

  Future<void> _handleDraftPlayer(
    Player player,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) async {
    final token = authProvider.token;
    final draft = draftProvider.currentDraft;

    if (token == null || draft == null) return;

    // Get current roster making the pick
    DraftOrder? currentRoster;
    try {
      currentRoster = draftProvider.draftOrder.firstWhere(
        (order) => order.rosterId == draft.currentRosterId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find current roster'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if it's the user's turn
    final isUsersTurn = authProvider.user != null &&
        currentRoster.userId == authProvider.user!.id;

    if (!isUsersTurn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not your turn to pick'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Remove from queue if it was queued
    setState(() {
      _draftQueue.remove(player);
      _selectedPlayer = null;
    });

    final success = await draftProvider.makePick(
      token: token,
      draftId: draft.id,
      rosterId: currentRoster.rosterId,
      playerId: player.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Drafted ${player.fullName}!'
                : 'Failed to draft ${player.fullName}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

    // Sort players if sort option is selected
    if (_sortBy != null) {
      // Pre-compute sort values to avoid repeated lookups during sort
      final sortValues = <String, double>{};
      for (final player in players) {
        final stats = _playerStats['${player.playerId}_$_statsMode'];
        sortValues[player.playerId] = _getStatValueForSorting(stats, _sortBy!, player.position);
      }

      players.sort((a, b) {
        final aValue = sortValues[a.playerId] ?? -1;
        final bValue = sortValues[b.playerId] ?? -1;

        // Handle missing stats (put at end)
        if (aValue == -1 && bValue == -1) return 0;
        if (aValue == -1) return 1;
        if (bValue == -1) return -1;

        final comparison = aValue.compareTo(bValue);
        return _sortAscending ? comparison : -comparison;
      });
    }

    return players;
  }

  double _getStatValueForSorting(Map<String, dynamic>? data, String statKey, String position) {
    if (data == null) return -1;

    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats == null) return -1;

    // Handle special cases
    if (statKey == 'FPTS') {
      final pts = stats['fantasy_points'] ??
                  stats['pts_ppr'] ??
                  stats['pts_half_ppr'] ??
                  stats['pts_std'] ??
                  stats['fpts'] ??
                  stats['fantasy_points_ppr'];
      if (pts == null) return -1;
      return (pts is num) ? pts.toDouble() : -1;
    }

    if (statKey == 'GP') {
      final gp = stats['games_played'] ?? stats['gp'] ?? stats['g'] ?? stats['gms_active'];
      if (gp == null) return -1;
      return (gp is num) ? gp.toDouble() : -1;
    }

    // Map display keys to possible API keys - must match _getStatValue mappings (Sleeper uses 'yd' not 'yds')
    final statMappings = {
      // Passing
      'PASS_YDS': ['pass_yd', 'pass_yds', 'passing_yds'],
      'PASS_TD': ['pass_td', 'passing_td'],
      'INT': ['pass_int', 'int', 'def_int'],
      'PASS_ATT': ['pass_att', 'passing_att'],
      'PASS_CMP': ['pass_cmp', 'passing_cmp'],

      // Rushing
      'RUSH_YDS': ['rush_yd', 'rush_yds', 'rushing_yds'],
      'RUSH_TD': ['rush_td', 'rushing_td'],
      'RUSH_ATT': ['rush_att', 'rushing_att'],

      // Receiving
      'REC': ['rec', 'receptions'],
      'REC_YDS': ['rec_yd', 'rec_yds', 'receiving_yds'],
      'REC_TD': ['rec_td', 'receiving_td'],
      'TGTS': ['rec_tgt', 'targets'],

      // Kicking
      'FG': ['fgm', 'fg_made'],
      'FGA': ['fga', 'fg_att'],
      'XP': ['xpm', 'xp_made'],

      // Defense/ST
      'SACK': ['sack', 'sacks'],
      'FR': ['fum_rec', 'fumbles_rec'],
      'FF': ['fum_forced', 'fumbles_forced'],
      'TD': ['def_td', 'td', 'pass_td', 'rush_td', 'rec_td'],
      'PA': ['pts_allow', 'points_allowed'],

      // IDP
      'TKLS': ['tackle_total', 'tkl', 'tackles'],
      'TFL': ['tackle_for_loss', 'tfl'],
      'QB_HIT': ['qb_hit', 'qb_hits'],

      // General
      'YDS': ['pass_yd', 'rush_yd', 'rec_yd', 'yards', 'yds'],
      'PTS': ['pts', 'points'],
    };

    final possibleKeys = statMappings[statKey] ?? [statKey.toLowerCase()];

    for (final key in possibleKeys) {
      if (stats[key] != null) {
        final value = stats[key];
        if (value is num) {
          return value.toDouble();
        }
      }
    }

    return -1;
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


  @override
  Widget build(BuildContext context) {

    return Consumer2<DraftProvider, AuthProvider>(
      builder: (context, draftProvider, authProvider, _) {
        final draft = draftProvider.currentDraft;

        // Check autodraft on every rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutoDraft();
        });

        return Scaffold(
          appBar: _buildAppBar(context, draft, draftProvider, authProvider),
          body: draftProvider.status == DraftStatus.error
              ? ErrorStateWidget(
                  message: draftProvider.errorMessage ?? 'Error loading draft',
                  onRetry: _loadDraftAndJoinRoom,
                )
              : draft == null
                  ? const ListSkeleton(itemCount: 8)
                  : Stack(
                      children: [
                        // Main draft board
                        Column(
                          children: [
                            _buildStickyStatusBar(draftProvider, authProvider),
                            if (draft.status == 'paused' && _isAutoPaused(draft))
                              _buildAutoPauseBanner(draft),
                            const Expanded(
                              child: DraftBoardWidget(),
                            ),
                          ],
                        ),
                    // Manual draggable drawer with tabs
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: MediaQuery.of(context).size.height * _drawerHeight,
                      child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            final screenHeight = MediaQuery.of(context).size.height;
                            _drawerHeight -= details.delta.dy / screenHeight;
                            _drawerHeight = _drawerHeight.clamp(0.1, 0.9);
                          });
                        },
                        onVerticalDragEnd: (details) {
                          // Snap to nearest position
                          setState(() {
                            if (_drawerHeight < 0.3) {
                              _drawerHeight = 0.1;
                            } else if (_drawerHeight < 0.7) {
                              _drawerHeight = 0.5;
                            } else {
                              _drawerHeight = 0.9;
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Column(
                              children: [
                                // Drag handle
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // Tab bar or collapsed preview
                                if (_drawerHeight > 0.2)
                                  TabBar(
                                    controller: _drawerTabController,
                                    isScrollable: draftProvider.isChessTimerMode,
                                    tabs: [
                                      const Tab(
                                        icon: Icon(Icons.people, size: 20),
                                        text: 'Players',
                                      ),
                                      Tab(
                                        icon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.playlist_add_check, size: 20),
                                            if (_draftQueue.isNotEmpty) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${_draftQueue.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        text: 'Queue',
                                      ),
                                      if (draftProvider.isChessTimerMode)
                                        const Tab(
                                          icon: Icon(Icons.hourglass_bottom, size: 20),
                                          text: 'Team Times',
                                        ),
                                      const Tab(
                                        icon: Icon(Icons.chat_bubble_outline, size: 20),
                                        text: 'Chat',
                                      ),
                                    ],
                                  ),
                                // Show tab previews when drawer is collapsed
                                if (_drawerHeight <= 0.2)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildCollapsedTab(
                                            icon: Icons.people,
                                            label: 'Players',
                                            onTap: () {
                                              setState(() {
                                                _drawerTabController.index = 0;
                                                _drawerHeight = 0.5;
                                              });
                                            },
                                          ),
                                          _buildCollapsedTab(
                                            icon: Icons.playlist_add_check,
                                            label: 'Queue',
                                            badge: _draftQueue.isNotEmpty ? _draftQueue.length : null,
                                            onTap: () {
                                              setState(() {
                                                _drawerTabController.index = 1;
                                                _drawerHeight = 0.5;
                                              });
                                            },
                                          ),
                                          if (draftProvider.isChessTimerMode)
                                            _buildCollapsedTab(
                                              icon: Icons.hourglass_bottom,
                                              label: 'Times',
                                              onTap: () {
                                                setState(() {
                                                  _drawerTabController.index = 2;
                                                  _drawerHeight = 0.5;
                                                });
                                              },
                                            ),
                                          _buildCollapsedTab(
                                            icon: Icons.chat_bubble_outline,
                                            label: 'Chat',
                                            onTap: () {
                                              setState(() {
                                                _drawerTabController.index = draftProvider.isChessTimerMode ? 3 : 2;
                                                _drawerHeight = 0.5;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Content area - always present but with constrained height
                                if (_drawerHeight > 0.2)
                                  Expanded(
                                    child: TabBarView(
                                      controller: _drawerTabController,
                                      children: [
                                        // Available Players Tab
                                        Column(
                                          children: [
                                            // Search field
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                              child: TextField(
                                                controller: _searchController,
                                                decoration: InputDecoration(
                                                  hintText: 'Search players...',
                                                  prefixIcon: const Icon(Icons.search, size: 20),
                                                  suffixIcon: _searchController.text.isNotEmpty
                                                      ? IconButton(
                                                          icon: const Icon(Icons.clear, size: 20),
                                                          onPressed: () {
                                                            setState(() {
                                                              _searchController.clear();
                                                            });
                                                          },
                                                        )
                                                      : null,
                                                  border: const OutlineInputBorder(),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                            // Position filters
                                            _buildPositionFilters(),
                                            const Divider(height: 1),
                                            // Stats mode toggle
                                            _buildStatsModeToggle(),
                                            const Divider(height: 1),
                                            // Sort hint or loading banner
                                            if (_sortBy == null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (_isLoadingStats) ...[
                                                      SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor: AlwaysStoppedAnimation<Color>(
                                                            Theme.of(context).colorScheme.primary,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Loading stats...',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ] else ...[
                                                      Icon(
                                                        Icons.info_outline,
                                                        size: 14,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Tap any stat to sort',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            if (_sortBy != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.sort,
                                                      size: 16,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Sorted by $_sortBy (${_sortAscending ? 'Low to High' : 'High to Low'})',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(context).colorScheme.primary,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          _sortBy = null;
                                                          _sortAscending = false;
                                                        });
                                                      },
                                                      style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (_sortBy != null)
                                              const Divider(height: 1),
                                            // Player list
                                            Expanded(
                                              child: _buildPlayerList(draftProvider, authProvider),
                                            ),
                                            // Bottom pick button
                                            _buildBottomPickButton(draftProvider, authProvider),
                                          ],
                                        ),
                                        // Queue Tab
                                        _buildQueueTab(draftProvider, authProvider),
                                        // Team Times Tab (chess timer mode only)
                                        if (draftProvider.isChessTimerMode)
                                          const ChessTimerTeamListWidget(),
                                        // Chat Tab
                                        LeagueChatTabWidget(leagueId: widget.leagueId),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPositionFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
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
                backgroundColor: _getPositionColor(position).withValues(alpha: 0.1),
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
    );
  }

  Widget _buildStatsModeToggle() {
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
    final league = leagueProvider.selectedLeague;
    final endWeek = league?.endWeek ?? 17;

    // Build projection label based on week range
    String projectionLabel = '2025 Proj';
    if (_currentWeek != null && _currentWeek! <= endWeek) {
      projectionLabel = 'Wk $_currentWeek-$endWeek Proj';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatsChip('2025 Stats', 'current_season'),
          _buildStatsChip(projectionLabel, 'projections'),
          _buildStatsChip('2024 Stats', 'previous_season'),
        ],
      ),
    );
  }

  Widget _buildStatsChip(String label, String mode) {
    final isSelected = _statsMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statsMode = mode;
          // Don't load stats automatically - too many API calls
          // Stats will be loaded on demand or in batches
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPlayerList(
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) {
    final filteredPlayers = _getFilteredPlayers(draftProvider);

    if (filteredPlayers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No players available'),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPlayers.length,
          itemBuilder: (context, index) {
            final player = filteredPlayers[index];
            final isSelected = _selectedPlayer?.id == player.id;
            final isInQueue = _draftQueue.any((p) => p.id == player.id);

            return _buildPlayerCard(
              player: player,
              isSelected: isSelected,
              isInQueue: isInQueue,
              draftProvider: draftProvider,
              authProvider: authProvider,
            );
          },
        ),
        // Show loading overlay while sorting
        if (_isSorting)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Sorting players...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerCard({
    required Player player,
    required bool isSelected,
    required bool isInQueue,
    required DraftProvider draftProvider,
    required AuthProvider authProvider,
  }) {
    return Semantics(
      label: '${player.fullName}, ${player.position}, ${player.team}${isInQueue ? ', in queue' : ''}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: isSelected ? 4 : 1,
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
          children: [
            // Left section: Position badge and player info (fixed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: _getPositionColor(player.position),
                  radius: 18,
                  child: Text(
                    player.position,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        player.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        player.team ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Middle section: Stats (scrollable horizontally)
            Expanded(
              child: _buildPlayerStatsRow(player),
            ),
            const SizedBox(width: 8),
            // Right section: Action buttons (fixed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isInQueue)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Q${_draftQueue.indexWhere((p) => p.id == player.id) + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // Add to Queue / Remove from Queue button
                Semantics(
                  label: isInQueue ? 'Remove from Queue' : 'Add to Queue',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      isInQueue ? Icons.remove_circle : Icons.playlist_add,
                      color: isInQueue ? Colors.red : Colors.blue,
                      size: 22,
                    ),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () {
                      setState(() {
                        if (isInQueue) {
                          _draftQueue.removeWhere((p) => p.id == player.id);
                        } else {
                          _draftQueue.add(player);
                        }
                      });
                    },
                    tooltip: isInQueue ? 'Remove from Queue' : 'Add to Queue',
                  ),
                ),
                const SizedBox(width: 4),
                // Draft Player button
                Semantics(
                  label: 'Draft ${player.fullName}',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 22),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () {
                      _handleDraftPlayer(
                        player,
                        draftProvider,
                        authProvider,
                      );
                    },
                    tooltip: 'Draft Player',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildPlayerStatsRow(Player player) {
    final cacheKey = '${player.playerId}_$_statsMode';
    final stats = _playerStats[cacheKey];

    // Get or create scroll controller for this player
    final scrollKey = player.playerId;
    if (!_statsScrollControllers.containsKey(scrollKey)) {
      // Create new controller with initial scroll position
      _statsScrollControllers[scrollKey] = ScrollController(
        initialScrollOffset: _currentStatsScrollOffset,
      );
    }

    // Ensure the controller syncs after being attached
    final controller = _statsScrollControllers[scrollKey]!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients &&
          controller.offset != _currentStatsScrollOffset) {
        try {
          if (_currentStatsScrollOffset <= controller.position.maxScrollExtent) {
            controller.jumpTo(_currentStatsScrollOffset);
          } else {
            controller.jumpTo(controller.position.maxScrollExtent);
          }
        } catch (e) {
          // Ignore if controller isn't ready
        }
      }
    });

    return DraftStatsRow(
      playerId: player.playerId,
      stats: stats,
      statsMode: _statsMode,
      scrollController: controller,
      sortBy: _sortBy,
      sortAscending: _sortAscending,
      onStatTap: (String columnLabel) {
        // Prevent multiple simultaneous sort operations
        if (_isSorting) return;

        setState(() {
          _isSorting = true;
        });

        // Allow UI to update with sorting indicator
        Future.delayed(const Duration(milliseconds: 10)).then((_) {
          if (mounted) {
            String? columnToScrollTo;

            setState(() {
              if (_sortBy == columnLabel) {
                // Toggle sort direction or clear sort
                if (!_sortAscending) {
                  // Was descending, now clear sort
                  _sortBy = null;
                  _sortAscending = false;
                  columnToScrollTo = null; // Don't scroll when clearing
                } else {
                  // Was ascending, now descending
                  _sortAscending = false;
                  columnToScrollTo = columnLabel;
                }
              } else {
                // New sort column, start with descending
                _sortBy = columnLabel;
                _sortAscending = false;
                columnToScrollTo = columnLabel;
              }
              _isSorting = false;
            });

            // Wait for UI to update, then scroll
            if (columnToScrollTo != null) {
              // Wait for the next frame to ensure all widgets are built
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _scrollToColumn(columnToScrollTo!);
                }
              });
            }
          }
        });
      },
    );
  }

  List<String> _getUniversalStatColumns() {
    // Return universal stat columns shown for all players
    // This ensures consistent scrolling across all positions
    return [
      'PASS_YDS',
      'PASS_TD',
      'RUSH_YDS',
      'RUSH_TD',
      'REC',
      'REC_YDS',
      'REC_TD',
    ];
  }

  void _scrollToColumn(String columnLabel) async {
    // Prevent concurrent scroll operations
    if (_isScrolling) return;
    _isScrolling = true;

    try {
      // Calculate scroll position (same for all players now)
      double scrollOffset = 0.0;

      if (columnLabel == 'FPTS') {
        // FPTS is always first, scroll to start
        scrollOffset = 0.0;
      } else {
        // Get universal stat columns
        final allStats = _getUniversalStatColumns();
        final columnIndex = allStats.indexOf(columnLabel);

        if (columnIndex >= 0) {
          // FPTS width + divider
          scrollOffset = 65 + 5;

          // Add widths for columns before this one
          for (int i = 0; i < columnIndex; i++) {
            scrollOffset += 70 + 5; // column width + divider
          }
        }
      }

      // Store the current scroll offset for new controllers
      _currentStatsScrollOffset = scrollOffset;

      // Scroll all existing player rows to the same position
      // Use jumpTo instead of animateTo for better performance with many controllers
      for (final controller in _statsScrollControllers.values) {
        if (controller.hasClients) {
          try {
            // Check if we can scroll to this position
            if (scrollOffset <= controller.position.maxScrollExtent) {
              controller.jumpTo(scrollOffset);
            } else {
              // Scroll to max if target is beyond scroll extent
              controller.jumpTo(controller.position.maxScrollExtent);
            }
          } catch (e) {
            // Controller might not be fully initialized, skip it
            // It will use _currentStatsScrollOffset when initialized
          }
        }
      }
    } finally {
      _isScrolling = false;
    }
  }


  Future<void> _loadAllPlayerStats() async {
    if (_isLoadingStats) return;

    setState(() => _isLoadingStats = true);

    try {
      final draftProvider = Provider.of<DraftProvider>(context, listen: false);
      final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
      final availablePlayers = draftProvider.availablePlayers;

      if (availablePlayers.isEmpty) {
        setState(() => _isLoadingStats = false);
        return;
      }

      // Get all player IDs
      final playerIds = availablePlayers.map((p) => p.playerId).toList();

      const currentSeason = 2025;
      const previousSeason = 2024;

      // Get current NFL week for remaining weeks projections
      final currentWeek = await _nflService.getCurrentWeek(
        season: currentSeason.toString(),
        seasonType: 'regular',
      );
      _currentWeek = currentWeek;

      // Get league's end week
      final league = leagueProvider.selectedLeague;
      final endWeek = league?.endWeek ?? 17;

      // Load all three modes in parallel
      final List<Future<Map<String, Map<String, dynamic>>?>> futures = [
        _statsService.getBulkSeasonStats(
          season: currentSeason,
          playerIds: playerIds,
        ),
        _statsService.getBulkSeasonStats(
          season: previousSeason,
          playerIds: playerIds,
        ),
      ];

      // For projections, use week range if we have current week, otherwise fall back to season projections
      if (currentWeek != null && currentWeek <= endWeek) {
        futures.add(
          _statsService.getBulkWeekRangeProjections(
            season: currentSeason,
            playerIds: playerIds,
            startWeek: currentWeek,
            endWeek: endWeek,
          ),
        );
      } else {
        futures.add(
          _statsService.getBulkSeasonProjections(
            season: currentSeason,
            playerIds: playerIds,
          ),
        );
      }

      final results = await Future.wait(futures);

      final currentStats = results[0];
      final previousStats = results[1];
      final projections = results[2];

      // Cache all the results
      if (currentStats != null) {
        for (var entry in currentStats.entries) {
          _playerStats['${entry.key}_current_season'] = entry.value;
        }
      }

      if (previousStats != null) {
        for (var entry in previousStats.entries) {
          _playerStats['${entry.key}_previous_season'] = entry.value;
        }
      }

      if (projections != null) {
        for (var entry in projections.entries) {
          _playerStats['${entry.key}_projections'] = entry.value;
        }
      }

      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      debugPrint('Error loading player stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Widget _buildCollapsedTab({
    required IconData icon,
    required String label,
    int? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab(DraftProvider draftProvider, AuthProvider authProvider) {
    return DraftQueueTab(
      draftQueue: _draftQueue,
      draftProvider: draftProvider,
      authProvider: authProvider,
      onClearQueue: () {
        setState(() {
          _draftQueue.clear();
        });
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final player = _draftQueue.removeAt(oldIndex);
          _draftQueue.insert(newIndex, player);
        });
      },
      onRemoveFromQueue: (index) {
        setState(() {
          _draftQueue.removeAt(index);
        });
      },
      bottomPickButton: _buildBottomPickButton(draftProvider, authProvider),
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
          // Manage Time button (commissioner only, chess mode only)
          if (isCommissioner && draftProvider.isChessTimerMode)
            _buildManageTimeButton(context, draftProvider, authProvider),
          _buildPauseResumeButton(context, draft.status, draftProvider, authProvider),
        ],
      ],
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

  Widget _buildManageTimeButton(
    BuildContext context,
    DraftProvider draftProvider,
    AuthProvider authProvider,
  ) {
    return PopupMenuButton<DraftOrder>(
      icon: const Icon(Icons.access_time),
      tooltip: 'Manage Team Time',
      onSelected: (DraftOrder order) {
        showDialog(
          context: context,
          builder: (context) => TimeManagementDialog(roster: order),
        );
      },
      itemBuilder: (context) {
        return draftProvider.draftOrder.map((order) {
          final timeRemaining = draftProvider.getRosterTimeRemaining(order.rosterId);
          final isLow = timeRemaining != null && timeRemaining < 300;
          final isCritical = timeRemaining != null && timeRemaining < 60;

          return PopupMenuItem<DraftOrder>(
            value: order,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: order.rosterId == draftProvider.currentDraft?.currentRosterId
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '${order.draftPosition}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: order.rosterId == draftProvider.currentDraft?.currentRosterId
                        ? Colors.white
                        : null,
                  ),
                ),
              ),
              title: Text(order.displayName),
              trailing: timeRemaining != null
                  ? Text(
                      _formatChessTime(timeRemaining),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCritical
                            ? Colors.red
                            : (isLow ? Colors.orange : null),
                      ),
                    )
                  : const Icon(Icons.timer_off, color: Colors.grey, size: 18),
            ),
          );
        }).toList();
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
    return DraftStatusBar(
      draftProvider: draftProvider,
      authProvider: authProvider,
      timerAnimationController: _timerAnimationController,
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
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            color: _getPositionColor(_selectedPlayer!.position).withValues(alpha: 0.2),
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

  /// Check if draft is auto-paused (has overnight pause settings enabled)
  bool _isAutoPaused(Draft draft) {
    return draft.settings?['auto_pause_enabled'] == true;
  }

  /// Convert UTC time to local TimeOfDay for display
  TimeOfDay _utcToLocalTimeOfDay(int hourUTC, int minuteUTC) {
    final now = DateTime.now();
    final utcTime = DateTime.utc(now.year, now.month, now.day, hourUTC, minuteUTC);
    final localTime = utcTime.toLocal();
    return TimeOfDay(hour: localTime.hour, minute: localTime.minute);
  }

  /// Build auto-pause notification banner
  Widget _buildAutoPauseBanner(Draft draft) {
    final settings = draft.settings;
    if (settings == null) return const SizedBox.shrink();

    final startHourUTC = settings['auto_pause_start_hour'] ?? 23;
    final startMinuteUTC = settings['auto_pause_start_minute'] ?? 0;
    final endHourUTC = settings['auto_pause_end_hour'] ?? 8;
    final endMinuteUTC = settings['auto_pause_end_minute'] ?? 0;

    // Convert UTC to local time for display
    final startTime = _utcToLocalTimeOfDay(startHourUTC, startMinuteUTC);
    final endTime = _utcToLocalTimeOfDay(endHourUTC, endMinuteUTC);

    // Get timezone abbreviation (EST, EDT, PST, etc.)
    final now = DateTime.now();
    final timeZoneName = now.timeZoneName; // e.g., "EST", "EDT", "PST", "PDT"

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade300, width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bedtime, color: Colors.orange.shade900, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Draft Auto-Paused Overnight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paused from ${startTime.format(context)} to ${endTime.format(context)} $timeZoneName',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
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
