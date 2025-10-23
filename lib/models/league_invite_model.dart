class LeagueInvite {
  final int id;
  final int leagueId;
  final int inviterUserId;
  final int invitedUserId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? leagueName;
  final String? season;
  final int? totalRosters;
  final String? inviterUsername;

  LeagueInvite({
    required this.id,
    required this.leagueId,
    required this.inviterUserId,
    required this.invitedUserId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.leagueName,
    this.season,
    this.totalRosters,
    this.inviterUsername,
  });

  factory LeagueInvite.fromJson(Map<String, dynamic> json) {
    return LeagueInvite(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      inviterUserId: json['inviter_user_id'] as int,
      invitedUserId: json['invited_user_id'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      leagueName: json['league_name'] as String?,
      season: json['season'] as String?,
      totalRosters: json['total_rosters'] as int?,
      inviterUsername: json['inviter_username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'inviter_user_id': inviterUserId,
      'invited_user_id': invitedUserId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
