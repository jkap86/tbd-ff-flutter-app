class WaiverClaim {
  final int id;
  final int leagueId;
  final int rosterId;
  final int playerId;
  final int? dropPlayerId;
  final int bidAmount;
  final String status; // 'pending', 'processed', 'failed'
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? processedAt;

  WaiverClaim({
    required this.id,
    required this.leagueId,
    required this.rosterId,
    required this.playerId,
    this.dropPlayerId,
    required this.bidAmount,
    required this.status,
    this.failureReason,
    required this.createdAt,
    this.processedAt,
  });

  factory WaiverClaim.fromJson(Map<String, dynamic> json) {
    return WaiverClaim(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      rosterId: json['roster_id'] as int,
      playerId: json['player_id'] as int,
      dropPlayerId: json['drop_player_id'] as int?,
      bidAmount: json['bid_amount'] as int,
      status: json['status'] as String,
      failureReason: json['failure_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'roster_id': rosterId,
      'player_id': playerId,
      'drop_player_id': dropPlayerId,
      'bid_amount': bidAmount,
      'status': status,
      'failure_reason': failureReason,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isProcessed => status == 'processed';
  bool get isFailed => status == 'failed';
}
