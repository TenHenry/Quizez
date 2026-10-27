import '../../data/models/answer_log.dart';

/// Results in one category (a deck name for flashcards, a question category for the quiz).
class CategoryStats {
  final String category;
  final int total;
  final int correct;

  const CategoryStats({required this.category, required this.total, required this.correct});

  /// Share of correct answers, 0.0 - 1.0.
  double get accuracy => total == 0 ? 0 : correct / total;

  int get accuracyPercent => (accuracy * 100).round();
}

/// Number of answers on one calendar day.
class DayStats {
  final DateTime day;
  final int total;
  final int correct;

  const DayStats({required this.day, required this.total, required this.correct});
}

/// Everything the statistics screen shows.
class StatsOverview {
  final int total;
  final int correct;
  final int answersLast7Days;

  /// Categories sorted from the hardest (lowest accuracy) to the easiest.
  final List<CategoryStats> categories;

  /// The last days, oldest first, including days without answers.
  final List<DayStats> days;

  const StatsOverview({
    required this.total,
    required this.correct,
    required this.answersLast7Days,
    required this.categories,
    required this.days,
  });

  int get accuracyPercent => total == 0 ? 0 : (correct * 100 / total).round();
}

/// Builds the statistics from the answer log. With [source] only answers of that source are counted
/// ([AnswerLog.sourceFlashcards] or [AnswerLog.sourceQuiz]); null counts everything.
StatsOverview computeStats(List<AnswerLog> logs, {String? source, DateTime? now, int days = 14}) {
  final today = _dayOf((now ?? DateTime.now()).toLocal());
  final filtered = source == null ? logs : logs.where((l) => l.source == source).toList();

  // Per category.
  final perCategory = <String, List<int>>{}; // [total, correct]
  for (final log in filtered) {
    final counts = perCategory.putIfAbsent(log.category, () => [0, 0]);
    counts[0]++;
    if (log.correct) counts[1]++;
  }
  final categories = [
    for (final e in perCategory.entries) CategoryStats(category: e.key, total: e.value[0], correct: e.value[1]),
  ]..sort((a, b) {
      final byAccuracy = a.accuracy.compareTo(b.accuracy);
      if (byAccuracy != 0) return byAccuracy;
      final byVolume = b.total.compareTo(a.total); // more answers = more reliable, show first
      return byVolume != 0 ? byVolume : a.category.compareTo(b.category);
    });

  // Per day (zero-filled).
  final perDay = <DateTime, List<int>>{};
  for (final log in filtered) {
    final counts = perDay.putIfAbsent(_dayOf(log.answeredAt.toLocal()), () => [0, 0]);
    counts[0]++;
    if (log.correct) counts[1]++;
  }
  final dayList = [
    for (var i = days - 1; i >= 0; i--)
      () {
        final day = DateTime(today.year, today.month, today.day - i);
        final counts = perDay[day] ?? [0, 0];
        return DayStats(day: day, total: counts[0], correct: counts[1]);
      }(),
  ];

  final last7 = dayList.skip(dayList.length > 7 ? dayList.length - 7 : 0).fold<int>(0, (sum, d) => sum + d.total);

  return StatsOverview(
    total: filtered.length,
    correct: filtered.where((l) => l.correct).length,
    answersLast7Days: last7,
    categories: categories,
    days: dayList,
  );
}

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
