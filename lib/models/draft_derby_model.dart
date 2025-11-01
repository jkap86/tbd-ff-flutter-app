class DraftDerby {
  final int id;
  final int draftId;
  final String status; // 'not_started', 'in_progress', 'completed'
  final int currentTurn; // Index in derby_order array
  final DateTime? turnDeadline;
  final List<int> derbyOrder; // Roster IDs in selection order
  final DateTime createdAt;
  final DateTime updatedAt;

  DraftDerby({
    required this.id,
    required this.draftId,
    required this.status,
    required this.currentTurn,
    this.turnDeadline,
    required this.derbyOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DraftDerby.fromJson(Map<String, dynamic> json) {
    return DraftDerby(
      id: json['id'] as int,
      draftId: json['draft_id'] as int,
      status: json['status'] as String,
      currentTurn: json['current_turn'] as int? ?? 0,
      turnDeadline: json['turn_deadline'] != null
          ? DateTime.parse(json['turn_deadline'] as String)
          : null,
      derbyOrder: (json['derby_order'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'draft_id': draftId,
      'status': status,
      'current_turn': currentTurn,
      'turn_deadline': turnDeadline?.toIso8601String(),
      'derby_order': derbyOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'not_started';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  // Get current roster ID whose turn it is
  int? get currentTurnRosterId {
    if (currentTurn >= 0 && currentTurn < derbyOrder.length) {
      return derbyOrder[currentTurn];
    }
    return null;
  }

  DraftDerby copyWith({
    int? id,
    int? draftId,
    String? status,
    int? currentTurn,
    DateTime? turnDeadline,
    List<int>? derbyOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DraftDerby(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      status: status ?? this.status,
      currentTurn: currentTurn ?? this.currentTurn,
      turnDeadline: turnDeadline ?? this.turnDeadline,
      derbyOrder: derbyOrder ?? this.derbyOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DraftDerbySelection {
  final int id;
  final int derbyId;
  final int rosterId;
  final int draftPosition;
  final DateTime selectedAt;

  DraftDerbySelection({
    required this.id,
    required this.derbyId,
    required this.rosterId,
    required this.draftPosition,
    required this.selectedAt,
  });

  factory DraftDerbySelection.fromJson(Map<String, dynamic> json) {
    return DraftDerbySelection(
      id: json['id'] as int,
      derbyId: json['derby_id'] as int,
      rosterId: json['roster_id'] as int,
      draftPosition: json['draft_position'] as int,
      selectedAt: DateTime.parse(json['selected_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'derby_id': derbyId,
      'roster_id': rosterId,
      'draft_position': draftPosition,
      'selected_at': selectedAt.toIso8601String(),
    };
  }
}

class DraftDerbyRoster {
  final int rosterId;
  final int userId;
  final String username;
  final String? teamName;

  DraftDerbyRoster({
    required this.rosterId,
    required this.userId,
    required this.username,
    this.teamName,
  });

  factory DraftDerbyRoster.fromJson(Map<String, dynamic> json) {
    return DraftDerbyRoster(
      rosterId: json['roster_id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      teamName: json['team_name'] as String?,
    );
  }
}

class DraftDerbyWithDetails {
  final DraftDerby derby;
  final List<DraftDerbySelection> selections;
  final List<int> availablePositions;
  final List<DraftDerbyRoster> rosters;

  DraftDerbyWithDetails({
    required this.derby,
    required this.selections,
    required this.availablePositions,
    this.rosters = const [],
  });

  factory DraftDerbyWithDetails.fromJson(Map<String, dynamic> json) {
    return DraftDerbyWithDetails(
      derby: DraftDerby.fromJson(json),
      selections: (json['selections'] as List<dynamic>?)
              ?.map((e) => DraftDerbySelection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availablePositions: (json['available_positions'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      rosters: (json['rosters'] as List<dynamic>?)
              ?.map((e) => DraftDerbyRoster.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isMyTurn => derby.currentTurnRosterId != null;
  bool get hasSelections => selections.isNotEmpty;
  bool get hasAvailablePositions => availablePositions.isNotEmpty;

  DraftDerbySelection? getSelectionForRoster(int rosterId) {
    try {
      return selections.firstWhere((s) => s.rosterId == rosterId);
    } catch (e) {
      return null;
    }
  }

  bool hasRosterSelected(int rosterId) {
    return selections.any((s) => s.rosterId == rosterId);
  }

  bool isPositionAvailable(int position) {
    return availablePositions.contains(position);
  }
}
