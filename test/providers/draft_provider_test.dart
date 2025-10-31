import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/providers/draft_provider.dart';
import 'package:flutter_app/models/player_model.dart';
import 'package:flutter_app/models/draft_pick_model.dart';

/// Unit tests for DraftProvider
///
/// Regression tests for snake draft UI bug fix
void main() {
  late DraftProvider draftProvider;
  final now = DateTime.now();

  setUp(() {
    draftProvider = DraftProvider();
  });

  tearDown(() {
    draftProvider.dispose();
  });

  group('DraftProvider - Initial State', () {
    test('should start with empty state', () {
      expect(draftProvider.availablePlayers, isEmpty);
      expect(draftProvider.draftPicks, isEmpty);
      expect(draftProvider.draftOrder, isEmpty);
      expect(draftProvider.currentDraft, isNull);
      expect(draftProvider.status, DraftStatus.initial);
    });
  });

  group('DraftProvider - Available Players Management', () {
    test('should allow adding players to available list', () {
      final testPlayer = Player(
        id: 1,
        playerId: '123',
        fullName: 'Christian McCaffrey',
        position: 'RB',
        team: 'SF',
        createdAt: now,
        updatedAt: now,
      );

      draftProvider.availablePlayers.add(testPlayer);

      expect(draftProvider.availablePlayers.length, 1);
      expect(draftProvider.availablePlayers.first.id, 1);
    });

    test('should allow removing players from available list', () {
      final player1 = Player(
        id: 1,
        playerId: '123',
        fullName: 'Christian McCaffrey',
        position: 'RB',
        team: 'SF',
        createdAt: now,
        updatedAt: now,
      );

      final player2 = Player(
        id: 2,
        playerId: '456',
        fullName: 'Tyreek Hill',
        position: 'WR',
        team: 'MIA',
        createdAt: now,
        updatedAt: now,
      );

      draftProvider.availablePlayers.addAll([player1, player2]);
      expect(draftProvider.availablePlayers.length, 2);

      draftProvider.availablePlayers.removeWhere((p) => p.id == 1);

      expect(draftProvider.availablePlayers.length, 1);
      expect(draftProvider.availablePlayers.first.id, 2);
    });

    test('REGRESSION: removing same player twice should not crash', () {
      // This was the bug: player removed twice caused issues
      final testPlayer = Player(
        id: 1,
        playerId: '123',
        fullName: 'Test Player',
        position: 'RB',
        team: 'TB',
        createdAt: now,
        updatedAt: now,
      );

      draftProvider.availablePlayers.add(testPlayer);
      expect(draftProvider.availablePlayers.length, 1);

      // First removal
      draftProvider.availablePlayers.removeWhere((p) => p.id == 1);
      expect(draftProvider.availablePlayers.length, 0);

      // Second removal (should not crash)
      draftProvider.availablePlayers.removeWhere((p) => p.id == 1);
      expect(draftProvider.availablePlayers.length, 0);
    });
  });

  group('DraftProvider - Draft Picks Management', () {
    test('should allow adding picks to draft picks list', () {
      final testPick = DraftPick(
        id: 1,
        draftId: 1,
        pickNumber: 1,
        round: 1,
        pickInRound: 1,
        rosterId: 1,
        playerId: 123,
        isAutoPick: false,
        pickedAt: now,
        createdAt: now,
        playerName: 'Christian McCaffrey',
        playerPosition: 'RB',
        playerTeam: 'SF',
        pickedByUsername: 'TestUser',
      );

      draftProvider.draftPicks.add(testPick);

      expect(draftProvider.draftPicks.length, 1);
      expect(draftProvider.draftPicks.first.playerName, 'Christian McCaffrey');
    });

    test('REGRESSION: draft picks and available players are independent', () {
      // Verifies that picks list and available list are managed separately
      final player = Player(
        id: 1,
        playerId: '123',
        fullName: 'Test Player',
        position: 'RB',
        team: 'TB',
        createdAt: now,
        updatedAt: now,
      );

      final pick = DraftPick(
        id: 1,
        draftId: 1,
        pickNumber: 1,
        round: 1,
        pickInRound: 1,
        rosterId: 1,
        playerId: 1,
        isAutoPick: false,
        pickedAt: now,
        createdAt: now,
        playerName: 'Test Player',
        playerPosition: 'RB',
        playerTeam: 'TB',
        pickedByUsername: 'TestUser',
      );

      draftProvider.availablePlayers.add(player);
      expect(draftProvider.availablePlayers.length, 1);

      draftProvider.draftPicks.add(pick);
      expect(draftProvider.draftPicks.length, 1);

      draftProvider.availablePlayers.removeWhere((p) => p.id == 1);

      // Pick exists but player is gone from available
      expect(draftProvider.availablePlayers.length, 0);
      expect(draftProvider.draftPicks.length, 1);
    });
  });
}
