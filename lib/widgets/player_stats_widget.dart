import 'package:flutter/material.dart';
import '../services/player_stats_service.dart';

class PlayerStatsWidget extends StatefulWidget {
  final String playerId;
  final int currentSeason;
  final int? currentWeek;

  const PlayerStatsWidget({
    super.key,
    required this.playerId,
    required this.currentSeason,
    this.currentWeek,
  });

  @override
  State<PlayerStatsWidget> createState() => _PlayerStatsWidgetState();
}

class _PlayerStatsWidgetState extends State<PlayerStatsWidget>
    with SingleTickerProviderStateMixin {
  final PlayerStatsService _statsService = PlayerStatsService();
  late TabController _tabController;

  Map<String, dynamic>? _currentSeasonStats;
  Map<String, dynamic>? _previousSeasonStats;
  Map<String, dynamic>? _restOfSeasonProjections;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load current season stats
      final currentStats = await _statsService.getSeasonStats(
        season: widget.currentSeason,
        playerId: widget.playerId,
      );

      // Load previous season stats
      final previousStats = await _statsService.getSeasonStats(
        season: widget.currentSeason - 1,
        playerId: widget.playerId,
      );

      // Load full season projections
      final projections = await _statsService.getSeasonProjections(
        season: widget.currentSeason,
        playerId: widget.playerId,
      );

      setState(() {
        _currentSeasonStats = currentStats;
        _previousSeasonStats = previousStats;
        _restOfSeasonProjections = projections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stats: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStats,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Current Season'),
            Tab(text: 'Previous Season'),
            Tab(text: 'Projections'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStatsTab(_currentSeasonStats, '${widget.currentSeason}'),
              _buildStatsTab(_previousSeasonStats, '${widget.currentSeason - 1}'),
              _buildProjectionsTab(_restOfSeasonProjections),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(Map<String, dynamic>? statsData, String season) {
    if (statsData == null || statsData['stats'] == null) {
      return Center(
        child: Text(
          'No stats available for $season season',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final stats = statsData['stats'] as Map<String, dynamic>;

    // Define key stats to display based on position
    final keyStats = _getKeyStats(stats);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$season Season Stats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...keyStats.entries.map((entry) {
            return _buildStatRow(entry.key, entry.value);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProjectionsTab(Map<String, dynamic>? projectionsData) {
    if (projectionsData == null || projectionsData['stats'] == null) {
      return const Center(
        child: Text('No projections available'),
      );
    }

    final stats = projectionsData['stats'] as Map<String, dynamic>;
    final keyStats = _getKeyStats(stats);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Season Projections',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Full ${widget.currentSeason} season projections',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
          const SizedBox(height: 16),
          ...keyStats.entries.map((entry) {
            return _buildStatRow(entry.key, entry.value);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value is double ? value.toStringAsFixed(1) : value.toString(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getKeyStats(Map<String, dynamic> stats) {
    // Common fantasy stats to display
    final Map<String, dynamic> keyStats = {};

    // Passing stats
    if (stats.containsKey('pass_yd')) {
      keyStats['Passing Yards'] = stats['pass_yd'];
    }
    if (stats.containsKey('pass_td')) {
      keyStats['Passing TDs'] = stats['pass_td'];
    }
    if (stats.containsKey('pass_int')) {
      keyStats['Interceptions'] = stats['pass_int'];
    }
    if (stats.containsKey('pass_cmp_pct')) {
      keyStats['Completion %'] = stats['pass_cmp_pct'];
    }

    // Rushing stats
    if (stats.containsKey('rush_yd')) {
      keyStats['Rushing Yards'] = stats['rush_yd'];
    }
    if (stats.containsKey('rush_td')) {
      keyStats['Rushing TDs'] = stats['rush_td'];
    }
    if (stats.containsKey('rush_att')) {
      keyStats['Rushing Attempts'] = stats['rush_att'];
    }

    // Receiving stats
    if (stats.containsKey('rec')) {
      keyStats['Receptions'] = stats['rec'];
    }
    if (stats.containsKey('rec_yd')) {
      keyStats['Receiving Yards'] = stats['rec_yd'];
    }
    if (stats.containsKey('rec_td')) {
      keyStats['Receiving TDs'] = stats['rec_td'];
    }
    if (stats.containsKey('rec_tgt')) {
      keyStats['Targets'] = stats['rec_tgt'];
    }

    // Fantasy points
    if (stats.containsKey('pts_ppr')) {
      keyStats['PPR Points'] = stats['pts_ppr'];
    }
    if (stats.containsKey('pts_half_ppr')) {
      keyStats['Half PPR Points'] = stats['pts_half_ppr'];
    }
    if (stats.containsKey('pts_std')) {
      keyStats['Standard Points'] = stats['pts_std'];
    }

    // If no key stats found, return a subset of all stats
    if (keyStats.isEmpty) {
      int count = 0;
      for (var entry in stats.entries) {
        if (entry.value is num && count < 10) {
          keyStats[_formatStatName(entry.key)] = entry.value;
          count++;
        }
      }
    }

    return keyStats;
  }

  String _formatStatName(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
