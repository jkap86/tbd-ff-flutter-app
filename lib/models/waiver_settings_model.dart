class WaiverSettings {
  final int id;
  final int leagueId;
  final String waiverType; // 'faab', 'rolling', or 'none'
  final int faabBudget;
  final int waiverPeriodDays;
  final String processSchedule; // 'daily', 'twice_weekly', 'weekly', or 'manual'
  final String processTime; // HH:MM:SS format
  final DateTime createdAt;
  final DateTime updatedAt;

  WaiverSettings({
    required this.id,
    required this.leagueId,
    required this.waiverType,
    required this.faabBudget,
    required this.waiverPeriodDays,
    required this.processSchedule,
    required this.processTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WaiverSettings.fromJson(Map<String, dynamic> json) {
    return WaiverSettings(
      id: json['id'],
      leagueId: json['league_id'],
      waiverType: json['waiver_type'] ?? 'faab',
      faabBudget: json['faab_budget'] ?? 100,
      waiverPeriodDays: json['waiver_period_days'] ?? 2,
      processSchedule: json['process_schedule'] ?? 'daily',
      processTime: json['process_time'] ?? '03:00:00',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'waiver_type': waiverType,
      'faab_budget': faabBudget,
      'waiver_period_days': waiverPeriodDays,
      'process_schedule': processSchedule,
      'process_time': processTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WaiverSettings copyWith({
    int? id,
    int? leagueId,
    String? waiverType,
    int? faabBudget,
    int? waiverPeriodDays,
    String? processSchedule,
    String? processTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WaiverSettings(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      waiverType: waiverType ?? this.waiverType,
      faabBudget: faabBudget ?? this.faabBudget,
      waiverPeriodDays: waiverPeriodDays ?? this.waiverPeriodDays,
      processSchedule: processSchedule ?? this.processSchedule,
      processTime: processTime ?? this.processTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
