import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/widgets/draft/draft_picks_list_widget.dart';
import 'package:flutter_app/models/draft_pick_model.dart';

void main() {
  group('DraftPicksListWidget', () {
    testWidgets('should display empty state when no picks', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DraftPicksListWidget(picks: []),
          ),
        ),
      );

      expect(find.text('No picks yet'), findsOneWidget);
      expect(find.text('Picks will appear here as they are made'), findsOneWidget);
      expect(find.byIcon(Icons.sports_football), findsOneWidget);
    });

    testWidgets('should display picks in descending order', (WidgetTester tester) async {
      final picks = [
        DraftPick(
          id: 1,
          draftId: 1,
          playerId: 'player1',
          playerName: 'Player One',
          playerPosition: 'QB',
          playerTeam: 'KC',
          rosterId: 1,
          pickedByUsername: 'User1',
          pickNumber: 1,
          round: 1,
          pickInRound: 1,
          pickedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        DraftPick(
          id: 2,
          draftId: 1,
          playerId: 'player2',
          playerName: 'Player Two',
          playerPosition: 'RB',
          playerTeam: 'SF',
          rosterId: 2,
          pickedByUsername: 'User2',
          pickNumber: 2,
          round: 1,
          pickInRound: 2,
          pickedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        DraftPick(
          id: 3,
          draftId: 1,
          playerId: 'player3',
          playerName: 'Player Three',
          playerPosition: 'WR',
          playerTeam: 'DAL',
          rosterId: 3,
          pickedByUsername: 'User3',
          pickNumber: 3,
          round: 1,
          pickInRound: 3,
          pickedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftPicksListWidget(picks: picks),
          ),
        ),
      );

      // Find all pick cards
      final listTiles = find.byType(ListTile);
      expect(listTiles, findsNWidgets(3));

      // Verify most recent pick is first
      expect(find.text('Player Three'), findsOneWidget);

      // Verify NEW badge appears on recent picks
      expect(find.text('NEW'), findsWidgets);
    });

    testWidgets('should display position badges with correct colors', (WidgetTester tester) async {
      final picks = [
        DraftPick(
          id: 1,
          draftId: 1,
          playerId: 'player1',
          playerName: 'Quarterback',
          playerPosition: 'QB',
          playerTeam: 'KC',
          rosterId: 1,
          pickedByUsername: 'User1',
          pickNumber: 1,
          round: 1,
          pickInRound: 1,
          pickedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftPicksListWidget(picks: picks),
          ),
        ),
      );

      // Find QB position badge
      expect(find.text('QB'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('should display pick details correctly', (WidgetTester tester) async {
      final pick = DraftPick(
        id: 1,
        draftId: 1,
        playerId: 'player1',
        playerName: 'Test Player',
        playerPosition: 'RB',
        playerTeam: 'KC',
        rosterId: 1,
        pickedByUsername: 'TestUser',
        pickNumber: 5,
        round: 1,
        pickInRound: 5,
        pickedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftPicksListWidget(picks: [pick]),
          ),
        ),
      );

      expect(find.text('Test Player'), findsOneWidget);
      expect(find.text('KC'), findsOneWidget);
      expect(find.textContaining('Pick #5'), findsOneWidget);
      expect(find.textContaining('Round 1, Pick 5'), findsOneWidget);
      expect(find.textContaining('TestUser'), findsOneWidget);
    });

    testWidgets('should highlight recent picks', (WidgetTester tester) async {
      // Create 5 picks
      final picks = List.generate(
        5,
        (index) => DraftPick(
          id: index + 1,
          draftId: 1,
          playerId: 'player${index + 1}',
          playerName: 'Player ${index + 1}',
          playerPosition: 'RB',
          playerTeam: 'KC',
          rosterId: 1,
          pickedByUsername: 'User',
          pickNumber: index + 1,
          round: 1,
          pickInRound: index + 1,
          pickedAt: DateTime.now().subtract(Duration(minutes: index)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraftPicksListWidget(picks: picks),
          ),
        ),
      );

      // Should highlight 3 most recent picks with "NEW" badge
      expect(find.text('NEW'), findsNWidgets(3));
    });
  });
}
