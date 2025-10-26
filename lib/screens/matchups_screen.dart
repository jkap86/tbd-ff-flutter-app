import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/matchup_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/matchup_model.dart';
import '../widgets/responsive_container.dart';
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
  late int _selectedWeek;

  @override
  void initState() {
    super.initState();
    // Calculate current NFL week or default to start week
    _selectedWeek = _calculateCurrentWeek();
    _loadMatchups();
  }

  /// Calculate the current NFL week based on the season start
  /// For now, defaults to startWeek. Could be enhanced to calculate actual current week.
  int _calculateCurrentWeek() {
    // TODO: Calculate actual current week based on current date and NFL season calendar
    // For now, just use startWeek as a reasonable default
    return widget.startWeek;
  }

  Future<void> _loadMatchups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);

    if (authProvider.token != null) {
      await matchupProvider.loadMatchupsByWeek(
        token: authProvider.token!,
        leagueId: widget.leagueId,
        week: _selectedWeek,
        season: widget.season, // Pass season for auto-update
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.leagueName} - Matchups'),
        actions: [
          // Week selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<int>(
              value: _selectedWeek,
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
                  setState(() => _selectedWeek = week);
                  _loadMatchups();
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
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
                        'No matchups for Week $_selectedWeek',
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
                      color: Colors.grey.withOpacity(0.2),
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
