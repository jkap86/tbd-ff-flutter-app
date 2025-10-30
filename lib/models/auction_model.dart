class AuctionNomination {
  final int id;
  final int draftId;
  final int nominatingRosterId;
  final String? nominatingTeamName;
  final String playerId;
  final String? playerName;
  final String? playerPosition;
  final String? playerTeam;
  final int? winningBid;
  final int? winningRosterId;
  final String? winningTeamName;
  final DateTime? deadline;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  AuctionNomination({
    required this.id,
    required this.draftId,
    required this.nominatingRosterId,
    this.nominatingTeamName,
    required this.playerId,
    this.playerName,
    this.playerPosition,
    this.playerTeam,
    this.winningBid,
    this.winningRosterId,
    this.winningTeamName,
    this.deadline,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AuctionNomination.fromJson(Map<String, dynamic> json) {
    return AuctionNomination(
      id: json['id'] as int,
      draftId: json['draft_id'] as int,
      nominatingRosterId: json['nominating_roster_id'] as int,
      nominatingTeamName: json['nominating_team_name'] as String?,
      playerId: json['player_id'] as String,
      playerName: json['player_name'] as String?,
      playerPosition: json['player_position'] as String?,
      playerTeam: json['player_team'] as String?,
      winningBid: json['winning_bid'] as int?,
      winningRosterId: json['winning_roster_id'] as int?,
      winningTeamName: json['winning_team_name'] as String?,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'draft_id': draftId,
      'nominating_roster_id': nominatingRosterId,
      'nominating_team_name': nominatingTeamName,
      'player_id': playerId,
      'player_name': playerName,
      'player_position': playerPosition,
      'player_team': playerTeam,
      'winning_bid': winningBid,
      'winning_roster_id': winningRosterId,
      'winning_team_name': winningTeamName,
      'deadline': deadline?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AuctionNomination copyWith({
    int? id,
    int? draftId,
    int? nominatingRosterId,
    String? nominatingTeamName,
    String? playerId,
    String? playerName,
    String? playerPosition,
    String? playerTeam,
    int? winningBid,
    int? winningRosterId,
    String? winningTeamName,
    DateTime? deadline,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuctionNomination(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      nominatingRosterId: nominatingRosterId ?? this.nominatingRosterId,
      nominatingTeamName: nominatingTeamName ?? this.nominatingTeamName,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      playerPosition: playerPosition ?? this.playerPosition,
      playerTeam: playerTeam ?? this.playerTeam,
      winningBid: winningBid ?? this.winningBid,
      winningRosterId: winningRosterId ?? this.winningRosterId,
      winningTeamName: winningTeamName ?? this.winningTeamName,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == 'active';
  bool get hasNoBids => winningBid == null;

  String get playerPositionTeam {
    if (playerPosition != null && playerTeam != null) {
      return '$playerPosition - $playerTeam';
    } else if (playerPosition != null) {
      return playerPosition!;
    }
    return '';
  }

  Duration get timeRemaining {
    if (deadline == null) return Duration.zero;
    final now = DateTime.now();
    if (deadline!.isBefore(now)) {
      return Duration.zero;
    }
    return deadline!.difference(now);
  }
}

class AuctionBid {
  final int id;
  final int nominationId;
  final int rosterId;
  final String? teamName;
  final int bidAmount;
  final int maxBid;
  final bool isWinning;
  final DateTime createdAt;

  AuctionBid({
    required this.id,
    required this.nominationId,
    required this.rosterId,
    this.teamName,
    required this.bidAmount,
    required this.maxBid,
    required this.isWinning,
    required this.createdAt,
  });

  factory AuctionBid.fromJson(Map<String, dynamic> json) {
    return AuctionBid(
      id: json['id'] as int,
      nominationId: json['nomination_id'] as int,
      rosterId: json['roster_id'] as int,
      teamName: json['team_name'] as String?,
      bidAmount: json['bid_amount'] as int,
      maxBid: json['max_bid'] as int,
      isWinning: json['is_winning'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nomination_id': nominationId,
      'roster_id': rosterId,
      'team_name': teamName,
      'bid_amount': bidAmount,
      'max_bid': maxBid,
      'is_winning': isWinning,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class RosterBudget {
  final int rosterId;
  final int startingBudget;
  final int spent;
  final int activeBids;
  final int reserved;
  final int available;

  RosterBudget({
    required this.rosterId,
    required this.startingBudget,
    required this.spent,
    required this.activeBids,
    required this.reserved,
    required this.available,
  });

  factory RosterBudget.fromJson(Map<String, dynamic> json) {
    return RosterBudget(
      rosterId: json['roster_id'] as int,
      startingBudget: json['starting_budget'] as int,
      spent: json['spent'] as int,
      activeBids: json['active_bids'] as int,
      reserved: json['reserved'] as int,
      available: json['available'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roster_id': rosterId,
      'starting_budget': startingBudget,
      'spent': spent,
      'active_bids': activeBids,
      'reserved': reserved,
      'available': available,
    };
  }

  bool canAfford(int amount) => available >= amount;
}

class ActivityItem {
  final String type; // 'bid', 'nomination', 'won', 'expired'
  final String description;
  final DateTime timestamp;
  final String? playerId;
  final String? playerName;
  final int? rosterId;
  final String? teamName;
  final int? amount;

  ActivityItem({
    required this.type,
    required this.description,
    required this.timestamp,
    this.playerId,
    this.playerName,
    this.rosterId,
    this.teamName,
    this.amount,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: json['type'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      playerId: json['player_id'] as String?,
      playerName: json['player_name'] as String?,
      rosterId: json['roster_id'] as int?,
      teamName: json['team_name'] as String?,
      amount: json['amount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'player_id': playerId,
      'player_name': playerName,
      'roster_id': rosterId,
      'team_name': teamName,
      'amount': amount,
    };
  }
}
