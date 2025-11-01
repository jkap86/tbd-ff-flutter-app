import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/player_model.dart';

void main() {
  group('Player.fromJson', () {
    test('should parse valid player data with int age and yearsExp', () {
      final json = {
        'id': 1,
        'player_id': 'P123',
        'full_name': 'Test Player',
        'position': 'QB',
        'team': 'TST',
        'age': 25,
        'years_exp': 3,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };

      final player = Player.fromJson(json);

      expect(player.id, 1);
      expect(player.playerId, 'P123');
      expect(player.fullName, 'Test Player');
      expect(player.position, 'QB');
      expect(player.team, 'TST');
      expect(player.age, 25);
      expect(player.yearsExp, 3);
    });

    test('should parse player data with string age and yearsExp', () {
      // This is the bug fix - backend sometimes sends these as strings
      final json = {
        'id': 1,
        'player_id': 'P123',
        'full_name': 'Test Player',
        'position': 'QB',
        'team': 'TST',
        'age': '25',
        'years_exp': '3',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };

      final player = Player.fromJson(json);

      expect(player.age, 25);
      expect(player.yearsExp, 3);
    });

    test('should handle null age and yearsExp', () {
      final json = {
        'id': 1,
        'player_id': 'P123',
        'full_name': 'Test Player',
        'position': 'QB',
        'team': 'TST',
        'age': null,
        'years_exp': null,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };

      final player = Player.fromJson(json);

      expect(player.age, null);
      expect(player.yearsExp, null);
    });

    test('should handle invalid string age and yearsExp gracefully', () {
      final json = {
        'id': 1,
        'player_id': 'P123',
        'full_name': 'Test Player',
        'position': 'QB',
        'team': 'TST',
        'age': 'invalid',
        'years_exp': 'invalid',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };

      final player = Player.fromJson(json);

      // int.tryParse returns null for invalid strings
      expect(player.age, null);
      expect(player.yearsExp, null);
    });

    test('should parse player with optional injury data', () {
      final json = {
        'id': 1,
        'player_id': 'P123',
        'full_name': 'Injured Player',
        'position': 'RB',
        'team': 'TST',
        'age': 27,
        'years_exp': 5,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
        'injury_status': 'Out',
        'injury_designation': 'Knee',
        'injury_return_date': '2025-02-01T00:00:00.000Z',
        'injury_updated_at': '2025-01-15T00:00:00.000Z',
      };

      final player = Player.fromJson(json);

      expect(player.injuryStatus, 'Out');
      expect(player.injuryDesignation, 'Knee');
      expect(player.injuryReturnDate, isNotNull);
      expect(player.injuryUpdatedAt, isNotNull);
    });

    test('should handle missing optional fields', () {
      final json = {
        'id': 1,
        'player_id': 'P123',
        'full_name': 'Test Player',
        'position': 'WR',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };

      final player = Player.fromJson(json);

      expect(player.team, null);
      expect(player.age, null);
      expect(player.yearsExp, null);
      expect(player.injuryStatus, null);
      expect(player.injuryDesignation, null);
      expect(player.injuryReturnDate, null);
      expect(player.injuryUpdatedAt, null);
    });
  });
}
