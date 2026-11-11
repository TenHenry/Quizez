import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/daily/leaderboard.dart';
import 'quiz_question_service.dart';

/// A finished daily quiz of the signed-in user.
class DailyResult {
  final int score;
  final int correct;
  final int total;
  const DailyResult({required this.score, required this.correct, required this.total});
}

/// Results of the daily quiz and the rankings (Supabase tables `daily_results` and view `daily_leaderboard`).
class DailyQuizService {
  SupabaseClient get _client => Supabase.instance.client;

  String get userId => _client.auth.currentUser?.id ?? '';

  /// The user's result for [day] (`yyyy-MM-dd`), or null when the quiz was not played yet.
  Future<DailyResult?> getMyResult(String day) async {
    try {
      final row = await _client.from('daily_results').select().eq('user_id', userId).eq('day', day).maybeSingle();
      if (row == null) return null;
      return DailyResult(score: row['score'] as int, correct: row['correct'] as int, total: row['total'] as int);
    } catch (_) {
      throw const QuizException('Could not check today\'s result. Is the daily quiz set up in Supabase?');
    }
  }

  /// Saves the result. A second result for the same day is silently ignored (one attempt per day).
  Future<void> submitResult({required String day, required int score, required int correct, required int total}) async {
    try {
      await _client.from('daily_results').insert({
        'user_id': userId,
        'day': day,
        'score': score,
        'correct': correct,
        'total': total,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already saved
      throw const QuizException('Could not save the result.');
    } catch (_) {
      throw const QuizException('Could not save the result. Check your connection.');
    }
  }

  /// Ranking of one day, best first.
  Future<List<LeaderboardEntry>> dayRanking(String day) async {
    final rows = await _fetch((q) => q.eq('day', day));
    return sumByUser(rows);
  }

  /// Ranking of the days from [fromDay] on (sum of the scores), best first.
  Future<List<LeaderboardEntry>> rankingSince(String fromDay) async {
    final rows = await _fetch((q) => q.gte('day', fromDay));
    return sumByUser(rows);
  }

  Future<List<LeaderboardEntry>> _fetch(PostgrestFilterBuilder<List<Map<String, dynamic>>> Function(PostgrestFilterBuilder<List<Map<String, dynamic>>>) filter) async {
    try {
      final rows = await filter(_client.from('daily_leaderboard').select());
      return [
        for (final row in rows)
          LeaderboardEntry(
            userId: row['user_id'] as String,
            nickname: row['nickname'] as String? ?? 'Player',
            score: row['score'] as int,
            correct: row['correct'] as int,
            total: row['total'] as int,
          ),
      ];
    } catch (_) {
      throw const QuizException('Could not load the ranking. Check your connection.');
    }
  }
}
