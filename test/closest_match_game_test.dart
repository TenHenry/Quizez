import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/models/game_term.dart';
import 'package:quizez/logic/closest_match/closest_match_game.dart';

const term = GameTerm(term: 'Gravity', definition: 'The force that pulls objects with mass toward each other.');

ClosestMatchGame game() => ClosestMatchGame(
      terms: [term, term],
      secondsPerRound: 30,
      players: ['anna', 'ben', 'cleo', 'dan'],
    )..nextTerm();

void main() {
  test('pointsForRank gives 1000, 700, 500 and then 300', () {
    expect([for (var i = 0; i < 5; i++) pointsForRank(i)], [1000, 700, 500, 300, 300]);
  });

  group('submitText', () {
    test('accepts one non-empty description per player', () {
      final g = game();

      expect(g.submitText(playerId: 'anna', roundIndex: 0, text: 'it pulls things', elapsedMs: 1000), isTrue);
      expect(g.submitText(playerId: 'anna', roundIndex: 0, text: 'again', elapsedMs: 2000), isFalse);
    });

    test('ignores empty text, unknown players and other rounds', () {
      final g = game();

      expect(g.submitText(playerId: 'anna', roundIndex: 0, text: '   ', elapsedMs: 0), isFalse);
      expect(g.submitText(playerId: 'stranger', roundIndex: 0, text: 'x', elapsedMs: 0), isFalse);
      expect(g.submitText(playerId: 'anna', roundIndex: 3, text: 'x', elapsedMs: 0), isFalse);
    });

    test('submittedTexts lists the earliest submission first', () {
      final g = game();
      g.submitText(playerId: 'ben', roundIndex: 0, text: 'late', elapsedMs: 9000);
      g.submitText(playerId: 'anna', roundIndex: 0, text: 'early', elapsedMs: 1000);

      expect(g.submittedTexts.keys, ['anna', 'ben']);
    });

    test('very long text is cut', () {
      final g = game();
      g.submitText(playerId: 'anna', roundIndex: 0, text: 'a' * 1000, elapsedMs: 0);

      expect(g.submittedTexts['anna']!.length, ClosestMatchGame.maxTextLength);
    });
  });

  group('finishRound', () {
    test('the closest description wins and points follow the ranking', () {
      final g = game();
      for (final id in ['anna', 'ben', 'cleo']) {
        g.submitText(playerId: id, roundIndex: 0, text: 'text of $id', elapsedMs: 1000);
      }

      final result = g.finishRound({'anna': 0.5, 'ben': 0.9, 'cleo': 0.7});

      expect(result.results.map((r) => r.playerId), ['ben', 'cleo', 'anna']);
      expect(result.results.map((r) => r.points), [1000, 700, 500]);
      expect(result.scores['ben'], 1000);
      expect(result.scores['dan'], 0); // did not answer
    });

    test('equal similarity is decided by who submitted earlier', () {
      final g = game();
      g.submitText(playerId: 'anna', roundIndex: 0, text: 'slow', elapsedMs: 9000);
      g.submitText(playerId: 'ben', roundIndex: 0, text: 'fast', elapsedMs: 2000);

      final result = g.finishRound({'anna': 0.80, 'ben': 0.802});

      expect(result.results.first.playerId, 'ben');
    });

    test('a clearly better answer beats a faster one', () {
      final g = game();
      g.submitText(playerId: 'anna', roundIndex: 0, text: 'slow but right', elapsedMs: 9000);
      g.submitText(playerId: 'ben', roundIndex: 0, text: 'fast but off', elapsedMs: 100);

      final result = g.finishRound({'anna': 0.9, 'ben': 0.4});

      expect(result.results.first.playerId, 'anna');
    });

    test('scores add up over rounds', () {
      final g = game();
      g.submitText(playerId: 'anna', roundIndex: 0, text: 'x', elapsedMs: 0);
      g.finishRound({'anna': 0.9});

      g.nextTerm();
      g.submitText(playerId: 'anna', roundIndex: 1, text: 'y', elapsedMs: 0);
      final second = g.finishRound({'anna': 0.9});

      expect(second.scores['anna'], 2000);
      expect(g.hasNext, isFalse);
    });

    test('a round without any description gives no points', () {
      final g = game();

      final result = g.finishRound({});

      expect(result.results, isEmpty);
      expect(result.scores.values.every((s) => s == 0), isTrue);
    });
  });

  group('GameTerm.tryParse', () {
    test('accepts a valid term', () => expect(GameTerm.tryParse({'term': 'Atom', 'definition': 'The smallest unit of an element.'}), isNotNull));
    test('rejects missing or too short definitions', () {
      expect(GameTerm.tryParse({'term': 'Atom', 'definition': 'small'}), isNull);
      expect(GameTerm.tryParse({'definition': 'The smallest unit of an element.'}), isNull);
      expect(GameTerm.tryParse(null), isNull);
    });
  });
}
