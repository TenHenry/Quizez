import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_question_service.dart';

/// Turns texts into embedding vectors (Edge Function `embed-texts`, free model built into Supabase).
class EmbeddingService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Embeddings in the same order as [texts] (at most 10 texts, each up to 500 characters).
  Future<List<List<double>>> embed(List<String> texts) async {
    try {
      final response = await _client.functions.invoke('embed-texts', body: {'texts': texts});

      final data = response.data;
      final raw = data is Map ? data['embeddings'] : null;
      if (raw is! List || raw.length != texts.length) {
        throw const QuizException('The answers could not be compared. Try again.');
      }
      return [
        for (final vector in raw) [for (final n in vector as List) (n as num).toDouble()],
      ];
    } on QuizException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      throw QuizException(details is Map && details['error'] is String
          ? details['error'] as String
          : 'Answer comparison is not available right now.');
    } catch (_) {
      throw const QuizException('Answer comparison failed. Check your connection.');
    }
  }
}
