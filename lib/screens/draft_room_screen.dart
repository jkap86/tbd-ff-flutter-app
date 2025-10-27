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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _drawerTabController = TabController(length: 3, vsync: this); // Players, Queue, and Chat tabs
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
              : Stack(
                  children: [
                    // Main draft board
                    Column(
                      children: [
                        _buildStickyStatusBar(draftProvider, authProvider),
                        Expanded(
                          child: const DraftBoardWidget(),
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
                                color: Colors.black.withOpacity(0.3),
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
                                // Tab bar
                                if (_drawerHeight > 0.2)
                                  TabBar(
                                    controller: _drawerTabController,
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
                                      const Tab(
                                        icon: Icon(Icons.chat_bubble_outline, size: 20),
                                        text: 'Chat',
                                      ),
                                    ],
                                  ),
                                // Show minimized label when drawer is collapsed
                                if (_drawerHeight <= 0.2)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.expand_less, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Swipe up to view',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
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
                                            // Sort hint or active sort banner
                                            if (_sortBy == null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
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
                                                ),
                                              ),
                                            if (_sortBy != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
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
        children: [
          Text(
            'View:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          if (_isLoadingStats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatsChip('2025 Stats', 'current_season'),
                  const SizedBox(width: 8),
                  _buildStatsChip(projectionLabel, 'projections'),
                  const SizedBox(width: 8),
                  _buildStatsChip('2024 Stats', 'previous_season'),
                ],
              ),
            ),
          ),
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
            color: Colors.black.withOpacity(0.3),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                IconButton(
                  icon: Icon(
                    isInQueue ? Icons.remove_circle : Icons.playlist_add,
                    color: isInQueue ? Colors.red : Colors.blue,
                    size: 22,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
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
                const SizedBox(width: 4),
                // Draft Player button
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 22),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _handleDraftPlayer(
                      player,
                      draftProvider,
                      authProvider,
                    );
                  },
                  tooltip: 'Draft Player',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStatsRow(Player player) {
    final cacheKey = '${player.playerId}_$_statsMode';
    final stats = _playerStats[cacheKey];

    // Use universal stat columns for all players
    final allStats = _getUniversalStatColumns();

    return Row(
      children: [
        // FPTS - always first
        Expanded(
          flex: 2,
          child: _buildStatColumn('FPTS', _getFantasyPoints(stats), sortable: true),
        ),
        _buildStatDivider(),
        // GP - always second
        Expanded(
          child: _buildStatColumn('GP', _getGamesPlayed(stats), sortable: true),
        ),
        // Universal stats (same for all players)
        ...allStats.expand((stat) => [
          _buildStatDivider(),
          Expanded(
            child: _buildStatColumn(stat, _getStatValue(stats, stat, player.position), sortable: true),
          ),
        ]),
      ],
    );
  }

  List<String> _getUniversalStatColumns() {
    // Return a universal set of stat columns that apply to all offensive players
    // This ensures consistent column ordering across all positions
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

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.shade400,
    );
  }

  String _getFantasyPoints(Map<String, dynamic>? data) {
    if (data == null) return '--';

    // The actual stats are nested inside 'stats' property
    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats == null) return '--';

    // Try different possible keys for fantasy points
    final pts = stats['fantasy_points'] ??
                stats['pts_ppr'] ??
                stats['pts_half_ppr'] ??
                stats['pts_std'] ??
                stats['fpts'] ??
                stats['fantasy_points_ppr'];
    if (pts == null) return '--';

    if (pts is num) {
      return pts.toStringAsFixed(1);
    }
    return pts.toString();
  }

  String _getGamesPlayed(Map<String, dynamic>? data) {
    if (data == null) return '--';

    // The actual stats are nested inside 'stats' property
    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats == null) return '--';

    final gp = stats['games_played'] ?? stats['gp'] ?? stats['g'] ?? stats['gms_active'];
    if (gp == null) return '--';
    return gp.toString();
  }

  String _getStatValue(Map<String, dynamic>? data, String statKey, String position) {
    if (data == null) {
      print('[$statKey] data is null');
      return '--';
    }

    // The actual stats are nested inside 'stats' property
    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats == null) {
      print('[$statKey] stats is null');
      return '--';
    }

    // Debug: Print ALL available keys once per position
    if (statKey == 'PASS_YDS' && stats.isNotEmpty) {
      print('[$position] ALL stat keys (${stats.keys.length}): ${stats.keys.join(", ")}');
      // Also check for any keys containing 'yd'
      final ydKeys = stats.keys.where((k) => k.toString().contains('yd')).toList();
      print('[$position] Keys containing "yd": ${ydKeys.join(", ")}');
    }

    // Map display keys to possible API keys (Sleeper uses 'yd' not 'yds')
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
          // Show integers for counts, 1 decimal for yards/points
          if (statKey.contains('YDS') || statKey == 'FPTS') {
            return value.toStringAsFixed(1);
          }
          return value.toInt().toString();
        }
        return value.toString();
      }
    }

    // Debug: Log when we can't find a stat
    if (statKey == 'PASS_YDS' || statKey == 'RUSH_YDS' || statKey == 'REC_YDS') {
      print('[$position] Could not find $statKey. Tried keys: ${possibleKeys.join(", ")}');
    }

    return '--';
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

      final currentSeason = 2025;
      final previousSeason = 2024;

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
        print('Cached ${currentStats.length} current season stats');
      }

      if (previousStats != null) {
        for (var entry in previousStats.entries) {
          _playerStats['${entry.key}_previous_season'] = entry.value;
        }
        print('Cached ${previousStats.length} previous season stats');
      }

      if (projections != null) {
        for (var entry in projections.entries) {
          _playerStats['${entry.key}_projections'] = entry.value;
        }
        if (currentWeek != null && currentWeek <= endWeek) {
          print('Cached ${projections.length} projections for weeks $currentWeek-$endWeek (remaining)');
        } else {
          print('Cached ${projections.length} projections');
        }
      }

      if (mounted) {
        setState(() => _isLoadingStats = false);
      }

      print('Loaded stats for ${playerIds.length} players, total cached: ${_playerStats.length}');
    } catch (e) {
      print('Error loading all player stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Widget _buildStatColumn(String label, String value, {bool sortable = false}) {
    final isCurrentSort = _sortBy == label;

    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isCurrentSort ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sortable && isCurrentSort) ...[
              const SizedBox(width: 2),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 9,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isCurrentSort ? Theme.of(context).colorScheme.primary : null,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (sortable) {
      return InkWell(
        onTap: () async {
          // Prevent multiple simultaneous sort operations
          if (_isSorting) return;

          setState(() {
            _isSorting = true;
          });

          // Allow UI to update with sorting indicator
          await Future.delayed(const Duration(milliseconds: 10));

          if (mounted) {
            setState(() {
              if (_sortBy == label) {
                // Toggle sort direction or clear sort
                if (!_sortAscending) {
                  // Was descending, now clear sort
                  _sortBy = null;
                  _sortAscending = false;
                } else {
                  // Was ascending, now descending
                  _sortAscending = false;
                }
              } else {
                // New sort column, start with descending
                _sortBy = label;
                _sortAscending = false;
              }
              _isSorting = false;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: column,
        ),
      );
    }

    return column;
  }

  List<String> _getAllStatsForPosition(String position) {
    // Return ALL relevant stat categories in consistent order based on position
    switch (position) {
      case 'QB':
        return ['PASS_YDS', 'PASS_TD', 'INT', 'RUSH_YDS', 'RUSH_TD'];
      case 'RB':
        return ['RUSH_YDS', 'RUSH_TD', 'REC', 'REC_YDS', 'REC_TD'];
      case 'WR':
      case 'TE':
        return ['REC', 'REC_YDS', 'REC_TD', 'RUSH_YDS', 'RUSH_TD'];
      case 'K':
        return ['FG', 'FGA', 'XP'];
      case 'DEF':
        return ['SACK', 'INT', 'FR', 'TD', 'PA'];
      case 'DL':
      case 'LB':
      case 'DB':
        return ['TKLS', 'SACK', 'INT', 'FF'];
      default:
        return [];
    }
  }

  List<String> _getStatsForPosition(String position) {
    // Backward compatibility - use the comprehensive version
    return _getAllStatsForPosition(position);
  }

  Widget _buildQueueTab(DraftProvider draftProvider, AuthProvider authProvider) {
    if (_draftQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.playlist_add,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Queue is Empty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add players from the Available Players tab',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Queue header with clear button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Players will be drafted in order when autodraft is on',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (_draftQueue.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _draftQueue.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Queue list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _draftQueue.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final player = _draftQueue.removeAt(oldIndex);
                _draftQueue.insert(newIndex, player);
              });
            },
            itemBuilder: (context, index) {
              final player = _draftQueue[index];
              return Card(
                key: ValueKey(player.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Queue position number
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Position avatar
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
                    ],
                  ),
                  title: Text(
                    player.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${player.team} - ${player.position}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Icon(Icons.drag_handle, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      // Remove button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _draftQueue.removeAt(index);
                          });
                        },
                        tooltip: 'Remove from Queue',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom pick button for queue
        _buildBottomPickButton(draftProvider, authProvider),
      ],
    );
  }

  Widget _buildRecentPicksTab(DraftProvider draftProvider, ScrollController? scrollController) {
    final picks = draftProvider.draftPicks.reversed.take(20).toList(); // Show last 20 picks

    if (picks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No picks yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: picks.length,
      itemBuilder: (context, index) {
        final pick = picks[index];
        final playerId = pick.playerId;

        // Skip if playerId is null
        if (playerId == null) {
          return const SizedBox.shrink();
        }

        final player = draftProvider.availablePlayers.firstWhere(
          (p) => p.id == playerId,
          orElse: () => Player(
            id: playerId,
            playerId: '',
            fullName: 'Unknown Player',
            position: '',
            team: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Find roster that made the pick
        final roster = draftProvider.draftOrder.firstWhere(
          (r) => r.rosterId == pick.rosterId,
          orElse: () => DraftOrder(
            id: 0,
            draftId: 0,
            rosterId: pick.rosterId,
            draftPosition: 0,
            userId: 0,
            username: 'Unknown',
            isAutodrafting: false,
            createdAt: DateTime.now(),
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: _getPositionColor(player.position),
              radius: 20,
              child: Text(
                player.position,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              player.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${roster.displayName} • Pick ${pick.pickNumber}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  player.team ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rd ${pick.round}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
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
