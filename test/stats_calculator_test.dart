import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/models/answer_log.dart';
import 'package:quizez/logic/stats/stats_calculator.dart';

final now = DateTime(2026, 10, 27, 12);

AnswerLog log(String category, bool correct, {String source = AnswerLog.sourceQuiz, int daysAgo = 0}) => AnswerLog()
  ..uuid = '$category-$correct-$daysAgo-${DateTime.now().microsecondsSinceEpoch}'
  ..source = source
  ..category = category
  ..correct = correct
  ..answeredAt = DateTime(now.year, now.month, now.day - daysAgo, 10);

void main() {
  test('no answers gives an empty overview with zero-filled days', () {
    final stats = computeStats([], now: now);

    expect(stats.total, 0);
    expect(stats.accuracyPercent, 0);
    expect(stats.categories, isEmpty);
    expect(stats.days.length, 14);
    expect(stats.days.every((d) => d.total == 0), isTrue);
  });

  test('counts totals and accuracy', () {
    final stats = computeStats([log('A', true), log('A', true), log('A', false), log('B', false)], now: now);

    expect(stats.total, 4);
    expect(stats.correct, 2);
    expect(stats.accuracyPercent, 50);
  });

  test('categories are sorted from the hardest to the easiest', () {
    final stats = computeStats([
      log('easy', true),
      log('easy', true),
      log('hard', false),
      log('hard', true),
      log('hard', false),
    ], now: now);

    expect(stats.categories.map((c) => c.category), ['hard', 'easy']);
    expect(stats.categories.first.accuracyPercent, 33);
  });

  test('with equal accuracy the category with more answers comes first', () {
    final stats = computeStats([log('few', true), log('many', true), log('many', true)], now: now);

    expect(stats.categories.first.category, 'many');
  });

  test('filters by source', () {
    final logs = [
      log('Deck', true, source: AnswerLog.sourceFlashcards),
      log('Geography', false, source: AnswerLog.sourceQuiz),
    ];

    final flashcards = computeStats(logs, source: AnswerLog.sourceFlashcards, now: now);

    expect(flashcards.total, 1);
    expect(flashcards.categories.single.category, 'Deck');
  });

  test('days are oldest first, today is last and old answers fall out of the window', () {
    final stats = computeStats([log('A', true), log('A', true, daysAgo: 3), log('A', true, daysAgo: 30)], now: now);

    expect(stats.days.last.total, 1);
    expect(stats.days[stats.days.length - 1 - 3].total, 1);
    expect(stats.days.fold<int>(0, (s, d) => s + d.total), 2);
    expect(stats.total, 3); // the totals still include everything
  });

  test('answersLast7Days counts only the last 7 days', () {
    final stats = computeStats([log('A', true), log('A', true, daysAgo: 6), log('A', true, daysAgo: 7)], now: now);

    expect(stats.answersLast7Days, 2);
  });
}
