import '../../data/services/embedding_service.dart';
import 'similarity.dart';

/// How close a player's answer is to the reference definition (higher = closer).
class AnswerScore {
  final String playerId;
  final double similarity;
  const AnswerScore(this.playerId, this.similarity);
}

/// Turns texts into vectors. Replaceable in tests.
typedef Embedder = Future<List<List<double>>> Function(List<String> texts);

/// Ranks players' own-words answers by how close their meaning is to the reference definition.
class ClosestMatchScorer {
  ClosestMatchScorer({Embedder? embedder}) : _embed = embedder ?? EmbeddingService().embed;

  final Embedder _embed;

  /// [answers] maps player id -> text. Returns the players sorted from the closest answer to the farthest.
  /// Players with identical similarity keep their input order, so the caller can break ties (e.g. by time).
  Future<List<AnswerScore>> score({required String reference, required Map<String, String> answers}) async {
    if (answers.isEmpty) return [];

    final ids = answers.keys.toList();
    final vectors = await _embed([reference, ...ids.map((id) => answers[id]!)]);
    final referenceVector = vectors.first;

    final scores = [
      for (var i = 0; i < ids.length; i++) AnswerScore(ids[i], cosineSimilarity(referenceVector, vectors[i + 1])),
    ];

    // Stable by index: List.sort is not stable, so compare the original position on equal similarity.
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    scores.sort((a, b) {
      final bySimilarity = b.similarity.compareTo(a.similarity);
      return bySimilarity != 0 ? bySimilarity : order[a.playerId]!.compareTo(order[b.playerId]!);
    });
    return scores;
  }
}
