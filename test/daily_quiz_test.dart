import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/models/quiz_question.dart';
import 'package:quizez/logic/daily/daily_quiz.dart';
import 'package:quizez/logic/daily/leaderboard.dart';

List<QuizQuestion> bank(int n) => [
      for (var i = 0; i < n; i++)
        QuizQuestion(text: 'Question $i', options: const ['a', 'b', 'c', 'd'], correctIndex: i % 4),
    ];

LeaderboardEntry row(String id, int score, {int correct = 5, int total = 10}) =>
    LeaderboardEntry(userId: id, nickname: 'nick-$id', score: score, correct: correct, total: total);

void main() {
  group('dayKey', () {
    test('formats the UTC date', () => expect(dayKey(DateTime.utc(2026, 3, 7, 23, 59)), '2026-03-07'));
    test('uses UTC, not the local time zone', () {
      final late = DateTime.parse('2026-03-07T23:30:00-05:00'); // 04:30 UTC on the 8th
      expect(dayKey(late), '2026-03-08');
    });
  });

  group('pickDailyQuestions', () {
    final day = DateTime.utc(2026, 10, 28, 12);

    test('gives the same questions in the same order for the same day', () {
      final a = pickDailyQuestions(bank(30), day).map((q) => q.text).toList();
      final b = pickDailyQuestions(bank(30), day.add(const Duration(hours: 5))).map((q) => q.text).toList();

      expect(a, b);
    });

    test('does not depend on the order of the bank', () {
      final forward = pickDailyQuestions(bank(30), day).map((q) => q.text).toList();
      final backward = pickDailyQuestions(bank(30).reversed.toList(), day).map((q) => q.text).toList();

      expect(forward, backward);
    });

    test('differs between days', () {
      final today = pickDailyQuestions(bank(30), day).map((q) => q.text).toList();
      final tomorrow = pickDailyQuestions(bank(30), day.add(const Duration(days: 1))).map((q) => q.text).toList();

      expect(today, isNot(tomorrow));
    });

    test('returns the requested number, or everything when the bank is smaller', () {
      expect(pickDailyQuestions(bank(30), day).length, dailyQuestionCount);
      expect(pickDailyQuestions(bank(4), day).length, 4);
      expect(pickDailyQuestions([], day), isEmpty);
    });

    test('does not repeat questions', () {
      final texts = pickDailyQuestions(bank(30), day).map((q) => q.text).toSet();

      expect(texts.length, dailyQuestionCount);
    });
  });

  group('leaderboard', () {
    test('sumByUser adds up the days of every user and sorts best first', () {
      final result = sumByUser([row('anna', 800), row('ben', 1500), row('anna', 900)]);

      expect(result.map((e) => e.userId), ['anna', 'ben']);
      expect(result.first.score, 1700);
      expect(result.first.total, 20);
    });

    test('equal totals keep the input order', () {
      final result = sumByUser([row('anna', 500), row('ben', 500)]);

      expect(result.map((e) => e.userId), ['anna', 'ben']);
    });

    test('placeOf returns the 1-based place or null', () {
      final ranking = sumByUser([row('anna', 900), row('ben', 500)]);

      expect(placeOf(ranking, 'ben'), 2);
      expect(placeOf(ranking, 'nobody'), isNull);
    });
  });
}
