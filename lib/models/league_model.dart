class League {
  final int id;
  final String name;
  final String status;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? scoringSettings;
  final String season;
  final String seasonType; // pre, regular, post
  final String leagueType; // redraft, keeper, dynasty
  final List<dynamic>? rosterPositions;
  final int totalRosters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? commissionerId;
  final int? currentRosters;

  League({
    required this.id,
    required this.name,
    required this.status,
    this.settings,
    this.scoringSettings,
    required this.season,
    required this.seasonType,
    required this.leagueType,
    this.rosterPositions,
    required this.totalRosters,
    required this.createdAt,
    required this.updatedAt,
    this.commissionerId,
    this.currentRosters,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    int? extractedCommissionerId;

    // Try to get commissioner_id from top level first
    if (json['commissioner_id'] != null) {
      extractedCommissionerId = json['commissioner_id'] as int;
    }
    // Then try to get it from settings
    else if (json['settings'] != null &&
        json['settings']['commissioner_id'] != null) {
      extractedCommissionerId = json['settings']['commissioner_id'] as int;
    }

    return League(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
      settings: json['settings'] as Map<String, dynamic>?,
      scoringSettings: json['scoring_settings'] as Map<String, dynamic>?,
      season: json['season'] as String,
      seasonType: json['season_type'] as String? ?? 'regular',
      leagueType: json['league_type'] as String? ?? 'redraft',
      rosterPositions: json['roster_positions'] as List<dynamic>?,
      totalRosters: json['total_rosters'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      commissionerId: extractedCommissionerId,
      currentRosters: json['current_rosters'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'settings': settings,
      'scoring_settings': scoringSettings,
      'season': season,
      'season_type': seasonType,
      'league_type': leagueType,
      'roster_positions': rosterPositions,
      'total_rosters': totalRosters,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'commissioner_id': commissionerId,
      'current_rosters': currentRosters,
    };
  }

  // Check if user is commissioner
  bool isUserCommissioner(int userId) {
    return commissionerId == userId;
  }

  // Get available spots
  int getAvailableSpots() {
    final current = currentRosters ?? 0;
    return totalRosters - current;
  }

  // Check if league is full
  bool isFull() {
    final current = currentRosters ?? 0;
    return current >= totalRosters;
  }
}
