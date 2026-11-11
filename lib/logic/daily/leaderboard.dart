/// One line of a ranking.
class LeaderboardEntry {
  final String userId;
  final String nickname;
  final int score;
  final int correct;
  final int total;

  const LeaderboardEntry({
    required this.userId,
    required this.nickname,
    required this.score,
    required this.correct,
    required this.total,
  });
}

/// Rows of the daily results (one per user and day) -> one entry per user with the sum of the scores,
/// best first. Equal scores keep the order of the input.
List<LeaderboardEntry> sumByUser(Iterable<LeaderboardEntry> rows) {
  final sums = <String, LeaderboardEntry>{};
  for (final row in rows) {
    final existing = sums[row.userId];
    sums[row.userId] = existing == null
        ? row
        : LeaderboardEntry(
            userId: row.userId,
            nickname: row.nickname,
            score: existing.score + row.score,
            correct: existing.correct + row.correct,
            total: existing.total + row.total,
          );
  }

  final order = {for (final (i, id) in sums.keys.indexed) id: i};
  return sums.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : order[a.userId]!.compareTo(order[b.userId]!);
    });
}

/// 1-based place of [userId] in [ranking], or null when the user is not in it.
int? placeOf(List<LeaderboardEntry> ranking, String userId) {
  final index = ranking.indexWhere((e) => e.userId == userId);
  return index == -1 ? null : index + 1;
}
