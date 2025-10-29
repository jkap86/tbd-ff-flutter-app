class DraftOrder {
  final int id;
  final int draftId;
  final int rosterId;
  final int draftPosition;
  final bool isAutodrafting;
  final DateTime createdAt;

  // Extended fields from join query
  final int? rosterNumber;
  final int? userId;
  final String? username;

  // Chess timer fields
  final int? timeRemainingSeconds;
  final int timeUsedSeconds;

  DraftOrder({
    required this.id,
    required this.draftId,
    required this.rosterId,
    required this.draftPosition,
    this.isAutodrafting = false,
    required this.createdAt,
    this.rosterNumber,
    this.userId,
    this.username,
    this.timeRemainingSeconds,
    this.timeUsedSeconds = 0,
  });

  factory DraftOrder.fromJson(Map<String, dynamic> json) {
    return DraftOrder(
      id: json['id'] as int,
      draftId: json['draft_id'] as int,
      rosterId: json['roster_id'] as int,
      draftPosition: json['draft_position'] as int,
      isAutodrafting: json['is_autodrafting'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      rosterNumber: json['roster_number'] as int?,
      userId: json['user_id'] as int?,
      username: json['username'] as String?,
      timeRemainingSeconds: json['time_remaining_seconds'] as int?,
      timeUsedSeconds: json['time_used_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'draft_id': draftId,
      'roster_id': rosterId,
      'draft_position': draftPosition,
      'is_autodrafting': isAutodrafting,
      'created_at': createdAt.toIso8601String(),
      'roster_number': rosterNumber,
      'user_id': userId,
      'username': username,
      'time_remaining_seconds': timeRemainingSeconds,
      'time_used_seconds': timeUsedSeconds,
    };
  }

  String get positionLabel => '#$draftPosition';

  String get displayName => username ?? 'Team $rosterNumber';

  // Format time remaining for chess timer mode
  String get formattedTimeRemaining {
    if (timeRemainingSeconds == null) return '--';

    final hours = timeRemainingSeconds! ~/ 3600;
    final minutes = (timeRemainingSeconds! % 3600) ~/ 60;
    final seconds = timeRemainingSeconds! % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Check if time is running low (< 5 minutes)
  bool get isTimeLow {
    if (timeRemainingSeconds == null) return false;
    return timeRemainingSeconds! < 300; // 5 minutes
  }

  // Check if time is critical (< 1 minute)
  bool get isTimeCritical {
    if (timeRemainingSeconds == null) return false;
    return timeRemainingSeconds! < 60; // 1 minute
  }

  DraftOrder copyWith({
    int? id,
    int? draftId,
    int? rosterId,
    int? draftPosition,
    bool? isAutodrafting,
    DateTime? createdAt,
    int? rosterNumber,
    int? userId,
    String? username,
    int? timeRemainingSeconds,
    int? timeUsedSeconds,
  }) {
    return DraftOrder(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      rosterId: rosterId ?? this.rosterId,
      draftPosition: draftPosition ?? this.draftPosition,
      isAutodrafting: isAutodrafting ?? this.isAutodrafting,
      createdAt: createdAt ?? this.createdAt,
      rosterNumber: rosterNumber ?? this.rosterNumber,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      timeRemainingSeconds: timeRemainingSeconds ?? this.timeRemainingSeconds,
      timeUsedSeconds: timeUsedSeconds ?? this.timeUsedSeconds,
    );
  }
}
