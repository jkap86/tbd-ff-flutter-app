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
    };
  }

  String get positionLabel => '#$draftPosition';

  String get displayName => username ?? 'Team $rosterNumber';

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
    );
  }
}
