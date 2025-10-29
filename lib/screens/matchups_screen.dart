import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/matchup_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/matchup_model.dart';
import '../widgets/responsive_container.dart';
import '../widgets/league_chat_tab_widget.dart';
import '../services/socket_service.dart';
import '../services/nfl_service.dart';
import 'matchup_detail_screen.dart';

class MatchupsScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;
  final String season;
  final int startWeek;
  final int playoffWeekStart;

  const MatchupsScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
    required this.season,
    this.startWeek = 1,
    this.playoffWeekStart = 15,
  });

  @override
  State<MatchupsScreen> createState() => _MatchupsScreenState();
}

class _MatchupsScreenState extends State<MatchupsScreen> {
  int? _selectedWeek;
  final SocketService _socketService = SocketService();
  final NflService _nflService = NflService();
  bool _isLoadingWeek = true;
  double _chatDrawerHeight = 0.1; // Start collapsed showing preview

  @override
  void initState() {
    super.initState();
    _initializeCurrentWeek();
  }

  Future<void> _initializeCurrentWeek() async {
    // Fetch actual current week from backend
    final currentWeek = await _nflService.getCurrentWeek(season: widget.season);

    if (mounted) {
      setState(() {
        _selectedWeek = currentWeek ?? widget.startWeek;
        _isLoadingWeek = false;
      });

      _loadMatchups();
      _setupLiveScores();
    }
  }

  void _setupLiveScores() {
    if (_selectedWeek == null) return; // Don't set up until week is initialized

    // Set up socket for live score updates
    _socketService.onMatchupScoresUpdated = (data) {
      final leagueId = data['league_id'] as int?;
      final week = data['week'] as int?;
      final matchups = data['matchups'] as List?;

      // Only update if it's the current league and week
      if (leagueId == widget.leagueId && week == _selectedWeek && matchups != null) {
        debugPrint('[LiveScores] Received live score update for week $_selectedWeek');

        // Update the provider with new matchup data
        final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);
        final updatedMatchups = matchups
            .map((m) => Matchup.fromJson(m as Map<String, dynamic>))
            .toList();

        matchupProvider.updateMatchupsInPlace(updatedMatchups);
      }
    };

    // Join the matchup room for live updates
    _socketService.joinLeagueMatchups(
      leagueId: widget.leagueId,
      week: _selectedWeek!,
    );
  }

  @override
  void dispose() {
    // Leave the matchup room when leaving the screen
    if (_selectedWeek != null) {
      _socketService.leaveLeagueMatchups(
        leagueId: widget.leagueId,
        week: _selectedWeek!,
      );
    }
    _socketService.clearCallbacks();
    super.dispose();
  }

  Future<void> _loadMatchups() async {
    if (_isLoadingWeek || _selectedWeek == null) return; // Don't load until we know the current week

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);

    if (authProvider.token != null) {
      await matchupProvider.loadMatchupsByWeek(
        token: authProvider.token!,
        leagueId: widget.leagueId,
        week: _selectedWeek!,
        season: widget.season, // Pass season for auto-update
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator until week is initialized
    if (_selectedWeek == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.leagueName} - Matchups'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final drawerHeight = MediaQuery.of(context).size.height * _chatDrawerHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.leagueName} - Matchups'),
        actions: [
          // Week selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<int>(
              value: _selectedWeek!,
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: const SizedBox(),
              items: List.generate(
                18,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(
                    'Week ${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              onChanged: (week) {
                if (week != null) {
                  // Leave old room
                  _socketService.leaveLeagueMatchups(
                    leagueId: widget.leagueId,
                    week: _selectedWeek!,
                  );

                  setState(() => _selectedWeek = week);
                  _loadMatchups();

                  // Join new room
                  _socketService.joinLeagueMatchups(
                    leagueId: widget.leagueId,
                    week: _selectedWeek!,
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: drawerHeight,
              child: ResponsiveContainer(
                child: Consumer2<MatchupProvider, LeagueProvider>(
            builder: (context, matchupProvider, leagueProvider, child) {
              if (matchupProvider.status == MatchupStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (matchupProvider.status == MatchupStatus.error) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        matchupProvider.errorMessage ?? 'Error loading matchups',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMatchups,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (matchupProvider.matchups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_football,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No matchups for Week ${_selectedWeek!}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Matchups are auto-generated when league settings are updated',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadMatchups,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: matchupProvider.matchups.length,
                  itemBuilder: (context, index) {
                    final matchup = matchupProvider.matchups[index];
                    return _buildMatchupCard(matchup);
                  },
                ),
              );
            },
                ),
              ),
            ),
            // Chat Drawer (bottom)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: drawerHeight,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    final screenHeight = MediaQuery.of(context).size.height;
                    _chatDrawerHeight -= details.delta.dy / screenHeight;
                    _chatDrawerHeight = _chatDrawerHeight.clamp(0.1, 0.9);
                  });
                },
                onVerticalDragEnd: (details) {
                  setState(() {
                    if (_chatDrawerHeight < 0.3) {
                      _chatDrawerHeight = 0.1;
                    } else if (_chatDrawerHeight < 0.7) {
                      _chatDrawerHeight = 0.5;
                    } else {
                      _chatDrawerHeight = 0.9;
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle bar and header
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _chatDrawerHeight = _chatDrawerHeight <= 0.2 ? 0.5 : 0.1;
                          });
                        },
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              // Handle bar
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Title
                              Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'League Chat',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Chat content
                      if (_chatDrawerHeight > 0.2)
                        Expanded(
                          child: LeagueChatTabWidget(leagueId: widget.leagueId),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupCard(Matchup matchup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchupDetailScreen(matchup: matchup),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          children: [
            // Status indicator
            if (matchup.isInProgress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            if (matchup.isByeWeek)
              // Bye week display
              Column(
                children: [
                  Text(
                    matchup.roster1Display,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BYE WEEK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              )
            else
              // Regular matchup
              Row(
                children: [
                  // Team 1
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matchup.roster1Display,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: matchup.isCompleted &&
                                    matchup.roster1Score > matchup.roster2Score
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          matchup.roster1Score.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: matchup.isCompleted &&
                                    matchup.roster1Score > matchup.roster2Score
                                ? Colors.green
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // VS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),

                  // Team 2
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          matchup.roster2Display,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: matchup.isCompleted &&
                                    matchup.roster2Score > matchup.roster1Score
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          matchup.roster2Score.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: matchup.isCompleted &&
                                    matchup.roster2Score > matchup.roster1Score
                                ? Colors.green
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Winner/Tie indicator
            if (matchup.isCompleted && !matchup.isByeWeek)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: matchup.isTie
                    ? const Text(
                        'TIE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      )
                    : Text(
                        '${matchup.winner} wins by ${matchup.scoreDifference.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
