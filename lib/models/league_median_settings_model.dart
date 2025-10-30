class LeagueMedianSettings {
  final int leagueId;
  final bool enableLeagueMedian;
  final int? medianMatchupWeekStart;
  final int? medianMatchupWeekEnd;

  LeagueMedianSettings({
    required this.leagueId,
    required this.enableLeagueMedian,
    this.medianMatchupWeekStart,
    this.medianMatchupWeekEnd,
  });

  factory LeagueMedianSettings.fromJson(Map<String, dynamic> json) {
    return LeagueMedianSettings(
      leagueId: json['league_id'] as int,
      enableLeagueMedian: json['enable_league_median'] as bool? ?? false,
      medianMatchupWeekStart: json['median_matchup_week_start'] as int?,
      medianMatchupWeekEnd: json['median_matchup_week_end'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'league_id': leagueId,
      'enable_league_median': enableLeagueMedian,
      'median_matchup_week_start': medianMatchupWeekStart,
      'median_matchup_week_end': medianMatchupWeekEnd,
    };
  }

  LeagueMedianSettings copyWith({
    int? leagueId,
    bool? enableLeagueMedian,
    int? medianMatchupWeekStart,
    int? medianMatchupWeekEnd,
  }) {
    return LeagueMedianSettings(
      leagueId: leagueId ?? this.leagueId,
      enableLeagueMedian: enableLeagueMedian ?? this.enableLeagueMedian,
      medianMatchupWeekStart: medianMatchupWeekStart ?? this.medianMatchupWeekStart,
      medianMatchupWeekEnd: medianMatchupWeekEnd ?? this.medianMatchupWeekEnd,
    );
  }
}
