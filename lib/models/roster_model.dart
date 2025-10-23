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
  });

  factory Roster.fromJson(Map<String, dynamic> json) {
    return Roster(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      userId: json['user_id'] as int,
      rosterId: json['roster_id'] as int,
      settings: json['settings'] as Map<String, dynamic>?,
      starters: json['starters'] as List<dynamic>? ?? [],
      bench: json['bench'] as List<dynamic>? ?? [],
      taxi: json['taxi'] as List<dynamic>? ?? [],
      ir: json['ir'] as List<dynamic>? ?? [],
      username: json['username'] as String?,
      email: json['email'] as String?,
    );
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
