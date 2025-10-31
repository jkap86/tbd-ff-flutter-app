import 'package:flutter/material.dart';

/// A widget that displays player statistics in a horizontal scrollable row.
/// Shows fantasy points and various stat columns with sorting capability.
class DraftStatsRow extends StatelessWidget {
  final String playerId;
  final Map<String, dynamic>? stats;
  final String statsMode;
  final ScrollController? scrollController;
  final String? sortBy;
  final bool sortAscending;
  final Function(String) onStatTap;

  const DraftStatsRow({
    super.key,
    required this.playerId,
    required this.stats,
    required this.statsMode,
    this.scrollController,
    this.sortBy,
    this.sortAscending = false,
    required this.onStatTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use universal stat columns for all players
    final allStats = _getUniversalStatColumns();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: scrollController,
      child: Row(
        children: [
          // FPTS - always first, fixed width
          SizedBox(
            width: 65,
            child: _buildStatColumn(
              context,
              'FPTS',
              _getFantasyPoints(stats),
              sortable: true,
            ),
          ),
          _buildStatDivider(),
          // Universal stats (same for all players) with fixed widths
          ...allStats.expand((stat) => [
            _buildStatDivider(),
            SizedBox(
              width: 70,
              child: _buildStatColumn(
                context,
                stat,
                _getStatValue(stats, stat),
                sortable: true,
              ),
            ),
          ]),
        ],
      ),
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

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.shade400,
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value, {
    bool sortable = false,
  }) {
    final isCurrentSort = sortBy == label;

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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCurrentSort
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sortable && isCurrentSort) ...[
              const SizedBox(width: 2),
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
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
        onTap: () => onStatTap(label),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: column,
        ),
      );
    }

    return column;
  }

  String _getFantasyPoints(Map<String, dynamic>? data) {
    if (data == null) return '--';

    // The actual stats are nested inside 'stats' property
    final statsData = data['stats'] as Map<String, dynamic>?;
    if (statsData == null) return '--';

    // Try different possible keys for fantasy points
    final pts = statsData['fantasy_points'] ??
        statsData['pts_ppr'] ??
        statsData['pts_half_ppr'] ??
        statsData['pts_std'] ??
        statsData['fpts'] ??
        statsData['fantasy_points_ppr'];
    if (pts == null) return '--';

    if (pts is num) {
      return pts.toStringAsFixed(1);
    }
    return pts.toString();
  }

  String _getStatValue(Map<String, dynamic>? data, String statKey) {
    if (data == null) {
      return '--';
    }

    // The actual stats are nested inside 'stats' property
    final statsData = data['stats'] as Map<String, dynamic>?;
    if (statsData == null) {
      return '--';
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
      if (statsData[key] != null) {
        final value = statsData[key];
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

    return '--';
  }
}
