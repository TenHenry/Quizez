import 'dart:math';

import '../../data/models/quiz_question.dart';

/// The daily quiz has the same questions for everybody, so results can be compared in a ranking.
const int dailyQuestionCount = 10;
const int dailySecondsPerQuestion = 15;

/// Day key used in the database (`yyyy-MM-dd`). The day is counted in UTC, so it changes at the same
/// moment for every player (midnight UTC).
String dayKey(DateTime moment) {
  final utc = moment.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

/// Chooses today's questions from the whole bank. The choice depends only on the day and on the bank,
/// so every device gets the same questions in the same order.
List<QuizQuestion> pickDailyQuestions(List<QuizQuestion> bank, DateTime moment, {int count = dailyQuestionCount}) {
  final utc = moment.toUtc();
  final seed = utc.year * 10000 + utc.month * 100 + utc.day;

  // Sorting first removes the dependency on the order in which the database returned the rows.
  final sorted = [...bank]..sort((a, b) => a.text.compareTo(b.text));
  sorted.shuffle(Random(seed));
  return sorted.take(count).toList();
}
