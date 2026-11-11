import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/services/quiz_room_service.dart';
import 'package:quizez/logic/quiz/quiz_state.dart';
import 'package:quizez/presentation/quiz/quiz_lobby_view.dart';
import 'package:quizez/presentation/quiz/scoreboard.dart';
import 'package:quizez/presentation/rewards/win_animation.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

const host1 = RoomPlayer(id: 'h', nickname: 'Hanna', isHost: true, avatar: '🦊');
const guest = RoomPlayer(id: 'g', nickname: 'Greg', isHost: false);

void main() {
  group('Scoreboard', () {
    const entries = [
      RankingEntry(playerId: 'a', nickname: 'Anna', score: 1500, gained: 900, avatar: '🦁'),
      RankingEntry(playerId: 'b', nickname: 'Ben', score: 700),
      RankingEntry(playerId: 'c', nickname: 'Cleo', score: 100),
      RankingEntry(playerId: 'd', nickname: 'Dan', score: 0),
    ];

    testWidgets('lists the players in order with medals, places and scores', (tester) async {
      await tester.pumpWidget(host(const Scoreboard(entries: entries, myId: null)));

      expect(find.text('🥇'), findsOneWidget);
      expect(find.text('🥈'), findsOneWidget);
      expect(find.text('🥉'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
      expect(find.text('🦁 Anna'), findsOneWidget); // avatar is shown before the nickname
    });

    testWidgets('marks the current player', (tester) async {
      await tester.pumpWidget(host(const Scoreboard(entries: entries, myId: 'b')));

      expect(find.text('Ben (you)'), findsOneWidget);
      expect(find.text('Cleo (you)'), findsNothing);
    });

    testWidgets('shows the points gained in the round only when asked', (tester) async {
      await tester.pumpWidget(host(const Scoreboard(entries: entries, myId: null, showGained: true)));
      expect(find.text('+900'), findsOneWidget);

      await tester.pumpWidget(host(const Scoreboard(entries: entries, myId: null)));
      expect(find.text('+900'), findsNothing);
    });
  });

  group('QuizLobbyView', () {
    testWidgets('the host sees the code, the players and an enabled Start button', (tester) async {
      await tester.pumpWidget(host(const QuizLobbyView(state: QuizLobby(code: 'AB7K2', players: [host1, guest], isHost: true))));

      expect(find.text('AB7K2'), findsOneWidget);
      expect(find.text('Players (2/8)'), findsOneWidget);
      expect(find.text('Hanna'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Start game')).onPressed, isNotNull);
    });

    testWidgets('a guest waits for the host and has no Start button', (tester) async {
      await tester.pumpWidget(host(const QuizLobbyView(state: QuizLobby(code: 'AB7K2', players: [host1, guest], isHost: false))));

      expect(find.text('Waiting for the host to start...'), findsOneWidget);
      expect(find.text('Start game'), findsNothing);
    });

    testWidgets('an error is shown in the lobby', (tester) async {
      await tester.pumpWidget(host(const QuizLobbyView(state: QuizLobby(code: 'AB7K2', players: [host1], isHost: true, error: 'No questions found for these settings.'))));

      expect(find.text('No questions found for these settings.'), findsOneWidget);
    });
  });

  group('WinAnimation', () {
    for (final id in ['anim_confetti', 'anim_stars', 'anim_balloons']) {
      testWidgets('$id plays without errors and finishes', (tester) async {
        await tester.pumpWidget(host(WinAnimation(animationId: id)));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 5));

        expect(tester.takeException(), isNull);
      });
    }
  });
}
