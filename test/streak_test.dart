import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/logic/rewards/streak.dart';

final now = DateTime(2026, 10, 28, 15);

DateTime daysAgo(int n, {int hour = 10}) => DateTime(now.year, now.month, now.day - n, hour);

void main() {
  group('computeStreak', () {
    test('no activity gives no streak', () {
      final info = computeStreak([], now: now);

      expect(info.days, 0);
      expect(info.activeToday, isFalse);
    });

    test('counts consecutive days ending today', () {
      final info = computeStreak([daysAgo(0), daysAgo(1), daysAgo(2)], now: now);

      expect(info.days, 3);
      expect(info.activeToday, isTrue);
    });

    test('several answers on one day count as one day', () {
      final info = computeStreak([daysAgo(0, hour: 8), daysAgo(0, hour: 9), daysAgo(0, hour: 20)], now: now);

      expect(info.days, 1);
    });

    test('a streak is kept until the end of today when yesterday was active', () {
      final info = computeStreak([daysAgo(1), daysAgo(2)], now: now);

      expect(info.days, 2);
      expect(info.activeToday, isFalse);
    });

    test('a missed day breaks the streak', () {
      final info = computeStreak([daysAgo(0), daysAgo(2), daysAgo(3)], now: now);

      expect(info.days, 1);
    });

    test('older activity without yesterday gives no streak', () {
      final info = computeStreak([daysAgo(2), daysAgo(3)], now: now);

      expect(info.days, 0);
    });
  });

  group('dailyRewardCoins', () {
    test('starts at 10 and grows by 5 per day', () {
      expect(dailyRewardCoins(0), 10);
      expect(dailyRewardCoins(1), 15);
      expect(dailyRewardCoins(3), 25);
    });

    test('is capped after 7 days', () {
      expect(dailyRewardCoins(7), 45);
      expect(dailyRewardCoins(100), 45);
    });

    test('ignores a negative streak', () => expect(dailyRewardCoins(-3), 10));
  });

  group('canClaimDailyReward', () {
    final utcNow = DateTime.utc(2026, 10, 28, 12);
    const active = StreakInfo(days: 1, activeToday: true);

    test('needs activity today', () {
      expect(canClaimDailyReward(streak: const StreakInfo(days: 2, activeToday: false), lastClaimDay: null, now: utcNow), isFalse);
    });

    test('is possible when it was not claimed today', () {
      expect(canClaimDailyReward(streak: active, lastClaimDay: '2026-10-27', now: utcNow), isTrue);
      expect(canClaimDailyReward(streak: active, lastClaimDay: null, now: utcNow), isTrue);
    });

    test('is not possible twice a day', () {
      expect(canClaimDailyReward(streak: active, lastClaimDay: '2026-10-28', now: utcNow), isFalse);
    });
  });
}
