class Player {
  final int id;
  final String playerId; // Sleeper player_id
  final String fullName;
  final String position;
  final String? team;
  final int? age;
  final int? yearsExp;
  final DateTime createdAt;
  final DateTime updatedAt;

  Player({
    required this.id,
    required this.playerId,
    required this.fullName,
    required this.position,
    this.team,
    this.age,
    this.yearsExp,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as int,
      playerId: json['player_id'] as String,
      fullName: json['full_name'] as String,
      position: json['position'] as String,
      team: json['team'] as String?,
      age: json['age'] as int?,
      yearsExp: json['years_exp'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'full_name': fullName,
      'position': position,
      'team': team,
      'age': age,
      'years_exp': yearsExp,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayName => fullName;

  String get positionTeam {
    if (team != null) {
      return '$position - $team';
    }
    return position;
  }
}
