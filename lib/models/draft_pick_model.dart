class DraftPick {
  final int id;
  final int draftId;
  final int pickNumber;
  final int round;
  final int pickInRound;
  final int rosterId;
  final int? playerId;
  final bool isAutoPick;
  final DateTime pickedAt;
  final DateTime? pickStartedAt;
  final int? pickTimeSeconds;
  final DateTime createdAt;

  // Extended fields from join query
  final String? playerName;
  final String? playerPosition;
  final String? playerTeam;
  final int? rosterNumber;
  final String? pickedByUsername;

  DraftPick({
    required this.id,
    required this.draftId,
    required this.pickNumber,
    required this.round,
    required this.pickInRound,
    required this.rosterId,
    this.playerId,
    required this.isAutoPick,
    required this.pickedAt,
    this.pickStartedAt,
    this.pickTimeSeconds,
    required this.createdAt,
    this.playerName,
    this.playerPosition,
    this.playerTeam,
    this.rosterNumber,
    this.pickedByUsername,
  });

  factory DraftPick.fromJson(Map<String, dynamic> json) {
    return DraftPick(
      id: json['id'] as int,
      draftId: json['draft_id'] as int,
      pickNumber: json['pick_number'] as int,
      round: json['round'] as int,
      pickInRound: json['pick_in_round'] as int,
      rosterId: json['roster_id'] as int,
      playerId: json['player_id'] as int?,
      isAutoPick: json['is_auto_pick'] as bool? ?? false,
      pickedAt: DateTime.parse(json['picked_at'] as String),
      pickStartedAt: json['pick_started_at'] != null
          ? DateTime.parse(json['pick_started_at'] as String)
          : null,
      pickTimeSeconds: json['pick_time_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      playerName: json['player_name'] as String?,
      playerPosition: json['player_position'] as String?,
      playerTeam: json['player_team'] as String?,
      rosterNumber: json['roster_number'] as int?,
      pickedByUsername: json['picked_by_username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'draft_id': draftId,
      'pick_number': pickNumber,
      'round': round,
      'pick_in_round': pickInRound,
      'roster_id': rosterId,
      'player_id': playerId,
      'is_auto_pick': isAutoPick,
      'picked_at': pickedAt.toIso8601String(),
      'pick_started_at': pickStartedAt?.toIso8601String(),
      'pick_time_seconds': pickTimeSeconds,
      'created_at': createdAt.toIso8601String(),
      'player_name': playerName,
      'player_position': playerPosition,
      'player_team': playerTeam,
      'roster_number': rosterNumber,
      'picked_by_username': pickedByUsername,
    };
  }

  String get pickLabel => '#$pickNumber';

  String get roundPickLabel => 'Round $round, Pick $pickInRound';

  String get playerDisplay {
    if (playerName != null) {
      if (playerPosition != null && playerTeam != null) {
        return '$playerName ($playerPosition - $playerTeam)';
      }
      return playerName!;
    }
    return 'Unknown Player';
  }
}
