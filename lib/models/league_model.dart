class League {
  final int id;
  final String name;
  final String status;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? scoringSettings;
  final String season;
  final String seasonType;
  final List<dynamic>? rosterPositions;
  final int totalRosters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? commissionerId;

  League({
    required this.id,
    required this.name,
    required this.status,
    this.settings,
    this.scoringSettings,
    required this.season,
    required this.seasonType,
    this.rosterPositions,
    required this.totalRosters,
    required this.createdAt,
    required this.updatedAt,
    this.commissionerId,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
      settings: json['settings'] as Map<String, dynamic>?,
      scoringSettings: json['scoring_settings'] as Map<String, dynamic>?,
      season: json['season'] as String,
      seasonType: json['season_type'] as String,
      rosterPositions: json['roster_positions'] as List<dynamic>?,
      totalRosters: json['total_rosters'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      commissionerId: json['commissioner_id'] as int? ??
          (json['settings'] != null &&
                  json['settings']['commissioner_id'] != null
              ? json['settings']['commissioner_id'] as int
              : null),
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
      'roster_positions': rosterPositions,
      'total_rosters': totalRosters,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'commissioner_id': commissionerId,
    };
  }
}
