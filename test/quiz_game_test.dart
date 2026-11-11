import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/models/quiz_question.dart';
import 'package:quizez/logic/quiz/quiz_game.dart';

QuizQuestion question(int correct) => QuizQuestion(text: 'q', options: const ['a', 'b', 'c', 'd'], correctIndex: correct);

QuizGame game({int seconds = 10}) => QuizGame(
      questions: [question(1), question(2)],
      secondsPerQuestion: seconds,
      players: ['anna', 'ben'],
    )..nextQuestion();

void main() {
  group('pointsFor', () {
    test('wrong answer gives nothing', () => expect(pointsFor(correct: false, elapsedMs: 0, totalMs: 10000), 0));
    test('instant correct answer gives the maximum', () => expect(pointsFor(correct: true, elapsedMs: 0, totalMs: 10000), 1000));
    test('correct answer at the last moment still gives the base points', () {
      expect(pointsFor(correct: true, elapsedMs: 10000, totalMs: 10000), 500);
    });
    test('faster answers score more', () {
      final fast = pointsFor(correct: true, elapsedMs: 2000, totalMs: 10000);
      final slow = pointsFor(correct: true, elapsedMs: 8000, totalMs: 10000);
      expect(fast, greaterThan(slow));
    });
  });

  group('QuizGame', () {
    test('scores correct answers and ignores wrong ones', () {
      final g = game();
      g.submitAnswer(playerId: 'anna', questionIndex: 0, choice: 1, elapsedMs: 0);
      g.submitAnswer(playerId: 'ben', questionIndex: 0, choice: 3, elapsedMs: 0);

      final result = g.finishRound();

      expect(result.correctIndex, 1);
      expect(result.gained['anna'], 1000);
      expect(result.gained['ben'], 0);
      expect(result.scores, {'anna': 1000, 'ben': 0});
    });

    test('a second answer from the same player is ignored', () {
      final g = game();

      expect(g.submitAnswer(playerId: 'anna', questionIndex: 0, choice: 3, elapsedMs: 0), isTrue);
      expect(g.submitAnswer(playerId: 'anna', questionIndex: 0, choice: 1, elapsedMs: 0), isFalse);
      expect(g.finishRound().gained['anna'], 0);
    });

    test('answers for another round or from unknown players are ignored', () {
      final g = game();

      expect(g.submitAnswer(playerId: 'anna', questionIndex: 5, choice: 1, elapsedMs: 0), isFalse);
      expect(g.submitAnswer(playerId: 'stranger', questionIndex: 0, choice: 1, elapsedMs: 0), isFalse);
      expect(g.submitAnswer(playerId: 'anna', questionIndex: 0, choice: 9, elapsedMs: 0), isFalse);
    });

    test('players who did not answer get 0 points', () {
      final g = game();
      g.submitAnswer(playerId: 'anna', questionIndex: 0, choice: 1, elapsedMs: 0);

      final result = g.finishRound();

      expect(result.gained['ben'], 0);
      expect(result.choices.containsKey('ben'), isFalse);
    });

    test('allAnswered turns true once everyone answered', () {
      final g = game();
      g.submitAnswer(playerId: 'anna', questionIndex: 0, choice: 1, elapsedMs: 0);
      expect(g.allAnswered(['anna', 'ben']), isFalse);

      g.submitAnswer(playerId: 'ben', questionIndex: 0, choice: 0, elapsedMs: 0);
      expect(g.allAnswered(['anna', 'ben']), isTrue);
    });

    test('scores add up over rounds and the ranking is sorted', () {
      final g = game();
      g.submitAnswer(playerId: 'ben', questionIndex: 0, choice: 1, elapsedMs: 0);
      g.finishRound();

      g.nextQuestion();
      g.submitAnswer(playerId: 'ben', questionIndex: 1, choice: 2, elapsedMs: 0);
      g.submitAnswer(playerId: 'anna', questionIndex: 1, choice: 2, elapsedMs: 5000);
      g.finishRound();

      final ranking = g.ranking();
      expect(ranking.first.playerId, 'ben');
      expect(ranking.first.score, 2000);
      expect(ranking.last.playerId, 'anna');
      expect(g.hasNext, isFalse);
    });
  });

  group('QuizQuestion.tryParse', () {
    test('accepts a valid question', () {
      final q = QuizQuestion.tryParse({
        'question': 'Capital of France?',
        'options': ['Paris', 'Rome', 'Berlin', 'Madrid'],
        'correct_index': 0,
        'category': 'Geography',
        'difficulty': 1,
      });

      expect(q, isNotNull);
      expect(q!.difficulty, 1);
    });

    test('rejects broken data', () {
      expect(QuizQuestion.tryParse(null), isNull);
      expect(QuizQuestion.tryParse({'question': 'x', 'options': ['a'], 'correct_index': 0}), isNull);
      expect(QuizQuestion.tryParse({'question': 'x', 'options': ['a', 'b'], 'correct_index': 5}), isNull);
      expect(QuizQuestion.tryParse({'question': 'x', 'options': ['a', 'a'], 'correct_index': 0}), isNull);
    });
  });
}
