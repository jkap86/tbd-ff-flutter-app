import 'package:flutter/material.dart';

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

  // Injury fields
  final String? injuryStatus; // 'Out', 'Doubtful', 'Questionable', 'IR', 'PUP', 'Healthy'
  final String? injuryDesignation; // 'Ankle', 'Hamstring', etc.
  final DateTime? injuryReturnDate;
  final DateTime? injuryUpdatedAt;

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
    this.injuryStatus,
    this.injuryDesignation,
    this.injuryReturnDate,
    this.injuryUpdatedAt,
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
      injuryStatus: json['injury_status'] as String?,
      injuryDesignation: json['injury_designation'] as String?,
      injuryReturnDate: json['injury_return_date'] != null
          ? DateTime.parse(json['injury_return_date'])
          : null,
      injuryUpdatedAt: json['injury_updated_at'] != null
          ? DateTime.parse(json['injury_updated_at'])
          : null,
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
      'injury_status': injuryStatus,
      'injury_designation': injuryDesignation,
      'injury_return_date': injuryReturnDate?.toIso8601String(),
      'injury_updated_at': injuryUpdatedAt?.toIso8601String(),
    };
  }

  String get displayName => fullName;

  String get positionTeam {
    if (team != null) {
      return '$position - $team';
    }
    return position;
  }

  // Injury helpers
  bool get isInjured => injuryStatus != null && injuryStatus != 'Healthy';

  Color get injuryStatusColor {
    switch (injuryStatus) {
      case 'Out':
      case 'IR':
      case 'PUP':
        return Colors.red;
      case 'Doubtful':
        return Colors.orange;
      case 'Questionable':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }
}
