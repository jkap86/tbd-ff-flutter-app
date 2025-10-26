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
  int _selectedWeek = 1;
  bool _isGenerating = false;
  bool _isUpdatingScores = false;

  @override
  void initState() {
    super.initState();
    _loadMatchups();
  }

  Future<void> _loadMatchups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);

    if (authProvider.token != null) {
      await matchupProvider.loadMatchupsByWeek(
        token: authProvider.token!,
        leagueId: widget.leagueId,
        week: _selectedWeek,
      );
    }
  }

  Future<void> _generateMatchups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);

    if (authProvider.token == null) return;

    setState(() => _isGenerating = true);

    final success = await matchupProvider.generateMatchups(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      week: _selectedWeek,
      season: widget.season,
    );

    if (mounted) {
      setState(() => _isGenerating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Matchups generated for week $_selectedWeek!'
                : 'Failed to generate matchups',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _generateAllRegularSeasonMatchups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);

    if (authProvider.token == null) return;

    final int totalWeeks = widget.playoffWeekStart - widget.startWeek;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate All Regular Season Matchups?'),
        content: Text(
          'This will generate matchups for all $totalWeeks regular season weeks (Week ${widget.startWeek} to Week ${widget.playoffWeekStart - 1}).\n\nAny existing matchups will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isGenerating = true);

    final success = await matchupProvider.generateAllRegularSeasonMatchups(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      season: widget.season,
      startWeek: widget.startWeek,
      playoffWeekStart: widget.playoffWeekStart,
    );

    if (mounted) {
      setState(() => _isGenerating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Generated matchups for all $totalWeeks regular season weeks!'
                : 'Failed to generate all matchups',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateScores() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);

    if (authProvider.token == null) return;

    setState(() => _isUpdatingScores = true);

    final success = await matchupProvider.updateScores(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      week: _selectedWeek,
      season: widget.season,
    );

    if (mounted) {
      setState(() => _isUpdatingScores = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Scores updated for week $_selectedWeek!'
                : 'Failed to update scores',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
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
                        'Generate matchups to get started',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (leagueProvider.isCommissioner) ...[
                        FilledButton.icon(
                          onPressed: _isGenerating ? null : _generateAllRegularSeasonMatchups,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text('Generate All Regular Season'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isGenerating ? null : _generateMatchups,
                          icon: const Icon(Icons.add),
                          label: const Text('Generate This Week Only'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadMatchups,
                child: Column(
                  children: [
                    // Commissioner actions
                    if (leagueProvider.isCommissioner)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isGenerating ? null : _generateMatchups,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh, size: 18),
                                label: const Text('Re-generate'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isUpdatingScores ? null : _updateScores,
                                icon: _isUpdatingScores
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync, size: 18),
                                label: const Text('Update Scores'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Matchups list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: matchupProvider.matchups.length,
                        itemBuilder: (context, index) {
                          final matchup = matchupProvider.matchups[index];
                          return _buildMatchupCard(matchup);
                        },
                      ),
                    ),
                  ],
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
