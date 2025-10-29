class Draft {
  final int id;
  final int leagueId;
  final String draftType; // 'snake', 'linear', 'auction', 'slow_auction'
  final bool thirdRoundReversal;
  final String status; // 'not_started', 'in_progress', 'paused', 'completed'
  final int currentPick;
  final int currentRound;
  final int? currentRosterId;
  final int pickTimeSeconds;
  final DateTime? pickDeadline;
  final int rounds;
  final String timerMode; // 'traditional' or 'chess'
  final int? teamTimeBudgetSeconds; // Budget for chess timer mode
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Auction-specific fields
  final int startingBudget;
  final int minBid;
  final int maxSimultaneousNominations;
  final int? nominationTimerHours;
  final bool reserveBudgetPerSlot;

  Draft({
    required this.id,
    required this.leagueId,
    required this.draftType,
    required this.thirdRoundReversal,
    required this.status,
    required this.currentPick,
    required this.currentRound,
    this.currentRosterId,
    required this.pickTimeSeconds,
    this.pickDeadline,
    required this.rounds,
    this.timerMode = 'traditional',
    this.teamTimeBudgetSeconds,
    this.startedAt,
    this.completedAt,
    this.settings,
    required this.createdAt,
    required this.updatedAt,
    // Auction-specific params
    this.startingBudget = 200,
    this.minBid = 1,
    this.maxSimultaneousNominations = 1,
    this.nominationTimerHours,
    this.reserveBudgetPerSlot = false,
  });

  factory Draft.fromJson(Map<String, dynamic> json) {
    return Draft(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      draftType: json['draft_type'] as String,
      thirdRoundReversal: json['third_round_reversal'] as bool? ?? false,
      status: json['status'] as String,
      currentPick: json['current_pick'] as int? ?? 1,
      currentRound: json['current_round'] as int? ?? 1,
      currentRosterId: json['current_roster_id'] as int?,
      pickTimeSeconds: json['pick_time_seconds'] as int? ?? 90,
      pickDeadline: json['pick_deadline'] != null
          ? DateTime.parse(json['pick_deadline'] as String)
          : null,
      rounds: json['rounds'] as int? ?? 15,
      timerMode: json['timer_mode'] as String? ?? 'traditional',
      teamTimeBudgetSeconds: json['team_time_budget_seconds'] as int?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      settings: json['settings'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Auction-specific fields
      startingBudget: json['starting_budget'] as int? ?? 200,
      minBid: json['min_bid'] as int? ?? 1,
      maxSimultaneousNominations: json['max_simultaneous_nominations'] as int? ?? 1,
      nominationTimerHours: json['nomination_timer_hours'] as int?,
      reserveBudgetPerSlot: json['reserve_budget_per_slot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'draft_type': draftType,
      'third_round_reversal': thirdRoundReversal,
      'status': status,
      'current_pick': currentPick,
      'current_round': currentRound,
      'current_roster_id': currentRosterId,
      'pick_time_seconds': pickTimeSeconds,
      'pick_deadline': pickDeadline?.toIso8601String(),
      'rounds': rounds,
      'timer_mode': timerMode,
      'team_time_budget_seconds': teamTimeBudgetSeconds,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Auction-specific fields
      'starting_budget': startingBudget,
      'min_bid': minBid,
      'max_simultaneous_nominations': maxSimultaneousNominations,
      'nomination_timer_hours': nominationTimerHours,
      'reserve_budget_per_slot': reserveBudgetPerSlot,
    };
  }

  bool get isNotStarted => status == 'not_started';
  bool get isInProgress => status == 'in_progress';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isSnake => draftType == 'snake';
  bool get isLinear => draftType == 'linear';
  bool get isAuction => draftType == 'auction';
  bool get isSlowAuction => draftType == 'slow_auction';
  bool get isTraditionalTimer => timerMode == 'traditional';
  bool get isChessTimer => timerMode == 'chess';

  int get totalPicks => rounds * 12; // Assuming max 12 teams for now

  double get progressPercentage {
    if (totalPicks == 0) return 0.0;
    return (currentPick - 1) / totalPicks;
  }

  Duration? get timeRemaining {
    if (pickDeadline == null) return null;
    final now = DateTime.now();
    if (pickDeadline!.isBefore(now)) return Duration.zero;
    return pickDeadline!.difference(now);
  }

  Draft copyWith({
    int? id,
    int? leagueId,
    String? draftType,
    bool? thirdRoundReversal,
    String? status,
    int? currentPick,
    int? currentRound,
    int? currentRosterId,
    int? pickTimeSeconds,
    DateTime? pickDeadline,
    int? rounds,
    String? timerMode,
    int? teamTimeBudgetSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? startingBudget,
    int? minBid,
    int? maxSimultaneousNominations,
    int? nominationTimerHours,
    bool? reserveBudgetPerSlot,
  }) {
    return Draft(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      draftType: draftType ?? this.draftType,
      thirdRoundReversal: thirdRoundReversal ?? this.thirdRoundReversal,
      status: status ?? this.status,
      currentPick: currentPick ?? this.currentPick,
      currentRound: currentRound ?? this.currentRound,
      currentRosterId: currentRosterId ?? this.currentRosterId,
      pickTimeSeconds: pickTimeSeconds ?? this.pickTimeSeconds,
      pickDeadline: pickDeadline ?? this.pickDeadline,
      rounds: rounds ?? this.rounds,
      timerMode: timerMode ?? this.timerMode,
      teamTimeBudgetSeconds: teamTimeBudgetSeconds ?? this.teamTimeBudgetSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startingBudget: startingBudget ?? this.startingBudget,
      minBid: minBid ?? this.minBid,
      maxSimultaneousNominations: maxSimultaneousNominations ?? this.maxSimultaneousNominations,
      nominationTimerHours: nominationTimerHours ?? this.nominationTimerHours,
      reserveBudgetPerSlot: reserveBudgetPerSlot ?? this.reserveBudgetPerSlot,
    );
  }
}
