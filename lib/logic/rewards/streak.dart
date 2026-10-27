import 'dart:math';

import '../daily/daily_quiz.dart';

/// How many days in a row the user was active.
class StreakInfo {
  /// Length of the streak. If the user was not active yet today, it still counts the days up to yesterday.
  final int days;

  /// At least one answer was given today (flashcards, quiz or daily quiz).
  final bool activeToday;

  const StreakInfo({required this.days, required this.activeToday});

  static const none = StreakInfo(days: 0, activeToday: false);
}

/// Streak of consecutive calendar days (in the user's time zone) with at least one answer.
/// A day without activity yet today does not break the streak - it only ends when yesterday was missed too.
StreakInfo computeStreak(Iterable<DateTime> answerTimes, {DateTime? now}) {
  final today = _dayOf((now ?? DateTime.now()).toLocal());
  final days = {for (final t in answerTimes) _dayOf(t.toLocal())};

  final activeToday = days.contains(today);
  var cursor = activeToday ? today : _daysBefore(today, 1);

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = _daysBefore(cursor, 1);
  }
  return StreakInfo(days: streak, activeToday: activeToday);
}

/// Coins for the daily reward: 10 + 5 per streak day, up to 7 days. Must match `claim_daily_reward` in Supabase.
int dailyRewardCoins(int streakDays) => 10 + min(max(streakDays, 0), 7) * 5;

/// The reward can be claimed once a day (UTC day, like the server) and only after some activity today.
bool canClaimDailyReward({required StreakInfo streak, required String? lastClaimDay, DateTime? now}) {
  return streak.activeToday && lastClaimDay != dayKey(now ?? DateTime.now());
}

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _daysBefore(DateTime date, int days) => DateTime(date.year, date.month, date.day - days);
