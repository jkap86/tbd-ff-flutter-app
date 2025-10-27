class Roster {
  final int id;
  final int leagueId;
  final int userId;
  final int rosterId;
  final Map<String, dynamic>? settings;
  final List<dynamic> starters;
  final List<dynamic> bench;
  final List<dynamic> taxi;
  final List<dynamic> ir;
  final String? username;
  final String? email;
  final int? wins;
  final int? losses;
  final int? ties;
  final double? pointsFor;
  final double? pointsAgainst;

  Roster({
    required this.id,
    required this.leagueId,
    required this.userId,
    required this.rosterId,
    this.settings,
    required this.starters,
    required this.bench,
    required this.taxi,
    required this.ir,
    this.username,
    this.email,
    this.wins,
    this.losses,
    this.ties,
    this.pointsFor,
    this.pointsAgainst,
  });

  factory Roster.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>?;

    return Roster(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      userId: json['user_id'] as int,
      rosterId: json['roster_id'] as int,
      settings: settings,
      starters: json['starters'] as List<dynamic>? ?? [],
      bench: json['bench'] as List<dynamic>? ?? [],
      taxi: json['taxi'] as List<dynamic>? ?? [],
      ir: json['ir'] as List<dynamic>? ?? [],
      username: json['username'] as String?,
      email: json['email'] as String?,
      wins: settings?['wins'] as int?,
      losses: settings?['losses'] as int?,
      ties: settings?['ties'] as int?,
      pointsFor: _parseDouble(settings?['points_for']),
      pointsAgainst: _parseDouble(settings?['points_against']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'user_id': userId,
      'roster_id': rosterId,
      'settings': settings,
      'starters': starters,
      'bench': bench,
      'taxi': taxi,
      'ir': ir,
    };
  }
}
