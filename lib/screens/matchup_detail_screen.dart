import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/matchup_model.dart';
import '../models/player_model.dart';
import '../services/matchup_service.dart';
import '../widgets/responsive_container.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import 'weekly_lineup_screen.dart';

class MatchupDetailScreen extends StatefulWidget {
  final Matchup matchup;

  const MatchupDetailScreen({
    super.key,
    required this.matchup,
  });

  @override
  State<MatchupDetailScreen> createState() => _MatchupDetailScreenState();
}

class _MatchupDetailScreenState extends State<MatchupDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _matchupDetails;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMatchupDetails();
  }

  Future<void> _loadMatchupDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Use the scores endpoint to get player scores
    final details = await MatchupService().getMatchupScores(
      matchupId: widget.matchup.id,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (details != null) {
          _matchupDetails = details;
        } else {
          _errorMessage = 'Failed to load matchup details';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Week ${widget.matchup.week} Matchup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMatchupDetails,
            tooltip: 'Refresh Scores',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMatchupDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildMatchupContent(),
    );
  }

  Widget _buildMatchupContent() {
    if (_matchupDetails == null) {
      return const Center(child: Text('No data available'));
    }

    final matchup = _matchupDetails!['matchup'];
    final roster1 = _matchupDetails!['roster1'];
    final roster2 = _matchupDetails!['roster2'];

    final team1Name = widget.matchup.roster1Display;
    final team2Name = widget.matchup.roster2Display;
    final team1Score = widget.matchup.roster1Score;
    final team2Score = widget.matchup.roster2Score;

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Header
            _buildScoreHeader(team1Name, team1Score, team2Name, team2Score),
            const SizedBox(height: 24),

            // Side by side rosters
            if (widget.matchup.isByeWeek)
              _buildTeamSection(
                teamName: team1Name,
                totalScore: team1Score,
                rosterData: roster1,
                rosterId: widget.matchup.roster1Id,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team 1 Lineup
                  Expanded(
                    child: _buildTeamSection(
                      teamName: team1Name,
                      totalScore: team1Score,
                      rosterData: roster1,
                      rosterId: widget.matchup.roster1Id,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Team 2 Lineup
                  if (widget.matchup.roster2Id != null)
                    Expanded(
                      child: _buildTeamSection(
                        teamName: team2Name,
                        totalScore: team2Score,
                        rosterData: roster2,
                        rosterId: widget.matchup.roster2Id!,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreHeader(String team1, double score1, String team2, double score2) {
    final isTeam1Winning = score1 > score2;
    final isTeam2Winning = score2 > score1;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Team 1
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isTeam1Winning ? FontWeight.bold : FontWeight.normal,
                      color: isTeam1Winning ? Colors.green : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    score1.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isTeam1Winning ? Colors.green : null,
                    ),
                  ),
                ],
              ),
            ),

            // VS
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),

            // Team 2
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    team2,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isTeam2Winning ? FontWeight.bold : FontWeight.normal,
                      color: isTeam2Winning ? Colors.green : null,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    score2.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isTeam2Winning ? Colors.green : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection({
    required String teamName,
    required double totalScore,
    required Map<String, dynamic>? rosterData,
    required int rosterId,
  }) {
    if (rosterData == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('No roster data available'),
        ],
      );
    }

    final starters = rosterData['starters'] as List<dynamic>? ?? [];
    final bench = rosterData['bench'] as List<dynamic>? ?? [];

    // Check if this roster belongs to the current user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    final rosterUserId = rosterData['user_id'];
    final isMyRoster = userId != null && rosterUserId != null && userId == rosterUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team name and total score
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                teamName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              totalScore.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Starters section
        const Text(
          'Starters',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...starters.map((starter) => _buildPlayerRow(starter, isStarter: true)),
      ],
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> slotData, {required bool isStarter}) {
    final slot = slotData['slot'] as String?;
    final playerData = slotData['player'];

    if (playerData == null) {
      // Empty slot
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  slot ?? '-',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Empty',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                    if (slot != null)
                      Text(
                        slot,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              const Text(
                '0.00',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Parse player data
    final fullName = playerData['full_name'] as String? ?? 'Unknown Player';
    final position = playerData['position'] as String? ?? '';
    final team = playerData['team'] as String?;
    final fantasyPoints = playerData['fantasy_points'];
    final score = fantasyPoints is num
        ? fantasyPoints.toDouble()
        : (fantasyPoints is String ? double.tryParse(fantasyPoints) ?? 0.0 : 0.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isStarter ? null : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _getPositionColor(position),
              child: Text(
                position,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    team ?? position,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              score.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPositionColor(String position) {
    switch (position.toUpperCase()) {
      case 'QB':
        return Colors.red;
      case 'RB':
        return Colors.blue;
      case 'WR':
        return Colors.green;
      case 'TE':
        return Colors.orange;
      case 'K':
        return Colors.purple;
      case 'DEF':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
