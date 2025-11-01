class DraftDerby {
  final int id;
  final int draftId;
  final String status; // 'pending', 'in_progress', 'completed'
  final int? currentTurnRosterId;
  final DateTime? currentTurnStartedAt;
  final List<int> selectionOrder;
  final List<int> skippedRosterIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  DraftDerby({
    required this.id,
    required this.draftId,
    required this.status,
    this.currentTurnRosterId,
    this.currentTurnStartedAt,
    required this.selectionOrder,
    required this.skippedRosterIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DraftDerby.fromJson(Map<String, dynamic> json) {
    return DraftDerby(
      id: json['id'] as int,
      draftId: json['draft_id'] as int,
      status: json['status'] as String,
      currentTurnRosterId: json['current_turn_roster_id'] as int?,
      currentTurnStartedAt: json['current_turn_started_at'] != null
          ? DateTime.parse(json['current_turn_started_at'] as String)
          : null,
      selectionOrder: (json['selection_order'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      skippedRosterIds: (json['skipped_roster_ids'] as List<dynamic>)
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
      'current_turn_roster_id': currentTurnRosterId,
      'current_turn_started_at': currentTurnStartedAt?.toIso8601String(),
      'selection_order': selectionOrder,
      'skipped_roster_ids': skippedRosterIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  DraftDerby copyWith({
    int? id,
    int? draftId,
    String? status,
    int? currentTurnRosterId,
    DateTime? currentTurnStartedAt,
    List<int>? selectionOrder,
    List<int>? skippedRosterIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DraftDerby(
      id: id ?? this.id,
      draftId: draftId ?? this.draftId,
      status: status ?? this.status,
      currentTurnRosterId: currentTurnRosterId ?? this.currentTurnRosterId,
      currentTurnStartedAt: currentTurnStartedAt ?? this.currentTurnStartedAt,
      selectionOrder: selectionOrder ?? this.selectionOrder,
      skippedRosterIds: skippedRosterIds ?? this.skippedRosterIds,
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

class DraftDerbyWithDetails {
  final DraftDerby derby;
  final List<DraftDerbySelection> selections;
  final List<int> availablePositions;

  DraftDerbyWithDetails({
    required this.derby,
    required this.selections,
    required this.availablePositions,
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
