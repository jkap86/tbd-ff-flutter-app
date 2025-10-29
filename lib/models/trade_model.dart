class Trade {
  final int id;
  final int leagueId;
  final int proposerRosterId;
  final int receiverRosterId;
  final String status;
  final String? proposerMessage;
  final String? rejectionReason;
  final DateTime proposedAt;
  final DateTime? respondedAt;
  final DateTime? processedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional details
  final String? proposerName;
  final String? receiverName;
  final String? proposerTeamName;
  final String? receiverTeamName;
  final List<TradeItem>? items;

  Trade({
    required this.id,
    required this.leagueId,
    required this.proposerRosterId,
    required this.receiverRosterId,
    required this.status,
    this.proposerMessage,
    this.rejectionReason,
    required this.proposedAt,
    this.respondedAt,
    this.processedAt,
    required this.createdAt,
    required this.updatedAt,
    this.proposerName,
    this.receiverName,
    this.proposerTeamName,
    this.receiverTeamName,
    this.items,
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      id: json['id'],
      leagueId: json['league_id'],
      proposerRosterId: json['proposer_roster_id'],
      receiverRosterId: json['receiver_roster_id'],
      status: json['status'],
      proposerMessage: json['proposer_message'],
      rejectionReason: json['rejection_reason'],
      proposedAt: DateTime.parse(json['proposed_at']),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      proposerName: json['proposer_name'],
      receiverName: json['receiver_name'],
      proposerTeamName: json['proposer_team_name'],
      receiverTeamName: json['receiver_team_name'],
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => TradeItem.fromJson(item))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'proposer_roster_id': proposerRosterId,
      'receiver_roster_id': receiverRosterId,
      'status': status,
      'proposer_message': proposerMessage,
      'rejection_reason': rejectionReason,
      'proposed_at': proposedAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'proposer_name': proposerName,
      'receiver_name': receiverName,
      'proposer_team_name': proposerTeamName,
      'receiver_team_name': receiverTeamName,
      'items': items?.map((item) => item.toJson()).toList(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}

class TradeItem {
  final int id;
  final int tradeId;
  final int fromRosterId;
  final int toRosterId;
  final int playerId;
  final String? playerName;
  final DateTime createdAt;

  TradeItem({
    required this.id,
    required this.tradeId,
    required this.fromRosterId,
    required this.toRosterId,
    required this.playerId,
    this.playerName,
    required this.createdAt,
  });

  factory TradeItem.fromJson(Map<String, dynamic> json) {
    return TradeItem(
      id: json['id'],
      tradeId: json['trade_id'],
      fromRosterId: json['from_roster_id'],
      toRosterId: json['to_roster_id'],
      playerId: json['player_id'],
      playerName: json['player_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trade_id': tradeId,
      'from_roster_id': fromRosterId,
      'to_roster_id': toRosterId,
      'player_id': playerId,
      'player_name': playerName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
