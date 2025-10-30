class Matchup {
  final int id;
  final int leagueId;
  final int week;
  final String season;
  final int roster1Id;
  final int? roster2Id; // null for bye week
  final double roster1Score;
  final double roster2Score;
  final String status; // scheduled, in_progress, completed
  final String? roster1TeamName;
  final String? roster1Username;
  final String? roster2TeamName;
  final String? roster2Username;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? isMedianMatchup;
  final double? medianScore;

  Matchup({
    required this.id,
    required this.leagueId,
    required this.week,
    required this.season,
    required this.roster1Id,
    this.roster2Id,
    required this.roster1Score,
    required this.roster2Score,
    required this.status,
    this.roster1TeamName,
    this.roster1Username,
    this.roster2TeamName,
    this.roster2Username,
    required this.createdAt,
    required this.updatedAt,
    this.isMedianMatchup,
    this.medianScore,
  });

  factory Matchup.fromJson(Map<String, dynamic> json) {
    return Matchup(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      week: json['week'] as int,
      season: json['season'] as String,
      roster1Id: json['roster1_id'] as int,
      roster2Id: json['roster2_id'] as int?,
      roster1Score: _parseScore(json['roster1_score']),
      roster2Score: _parseScore(json['roster2_score']),
      status: json['status'] as String,
      roster1TeamName: json['roster1_team_name'] as String?,
      roster1Username: json['roster1_username'] as String?,
      roster2TeamName: json['roster2_team_name'] as String?,
      roster2Username: json['roster2_username'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isMedianMatchup: json['is_median_matchup'] as bool?,
      medianScore: json['median_score'] != null
          ? (json['median_score'] as num).toDouble()
          : null,
    );
  }

  // Helper method to parse score from either String or num
  static double _parseScore(dynamic score) {
    if (score == null) return 0.0;
    if (score is num) return score.toDouble();
    if (score is String) return double.tryParse(score) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'week': week,
      'season': season,
      'roster1_id': roster1Id,
      'roster2_id': roster2Id,
      'roster1_score': roster1Score,
      'roster2_score': roster2Score,
      'status': status,
      'roster1_team_name': roster1TeamName,
      'roster1_username': roster1Username,
      'roster2_team_name': roster2TeamName,
      'roster2_username': roster2Username,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_median_matchup': isMedianMatchup,
      'median_score': medianScore,
    };
  }

  // Helper getters
  bool get isByeWeek => roster2Id == null;
  bool get isScheduled => status == 'scheduled';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  String get roster1Display =>
      roster1TeamName ?? roster1Username ?? 'Team $roster1Id';
  String get roster2Display =>
      isByeWeek
          ? 'BYE'
          : (roster2TeamName ?? roster2Username ?? 'Team $roster2Id');

  // Get winner/loser info
  String? get winner {
    if (!isCompleted || isByeWeek) return null;
    if (roster1Score > roster2Score) return roster1Display;
    if (roster2Score > roster1Score) return roster2Display;
    return null; // tie
  }

  bool get isTie =>
      isCompleted && !isByeWeek && roster1Score == roster2Score;

  double get scoreDifference =>
      isByeWeek ? 0 : (roster1Score - roster2Score).abs();

  // Median matchup helpers
  bool get isMedianMatchupType => isMedianMatchup == true;

  bool get isMedianWin {
    if (!isMedianMatchupType || medianScore == null) return false;
    return roster1Score > medianScore!;
  }

  bool get isMedianLoss {
    if (!isMedianMatchupType || medianScore == null) return false;
    return roster1Score < medianScore!;
  }

  bool get isMedianTie {
    if (!isMedianMatchupType || medianScore == null) return false;
    return roster1Score == medianScore!;
  }
}
