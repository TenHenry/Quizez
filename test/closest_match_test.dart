import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/logic/closest_match/closest_match_scorer.dart';
import 'package:quizez/logic/closest_match/similarity.dart';

void main() {
  group('cosineSimilarity', () {
    test('identical direction gives 1', () => expect(cosineSimilarity([1, 2, 3], [2, 4, 6]), closeTo(1, 1e-9)));
    test('perpendicular vectors give 0', () => expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0, 1e-9)));
    test('opposite vectors give -1', () => expect(cosineSimilarity([1, 1], [-1, -1]), closeTo(-1, 1e-9)));
    test('zero vector gives 0 instead of dividing by zero', () => expect(cosineSimilarity([0, 0], [1, 1]), 0));
    test('different lengths are rejected', () => expect(() => cosineSimilarity([1], [1, 2]), throwsArgumentError));
  });

  group('ClosestMatchScorer', () {
    // Fake embedder: the text itself says which vector it maps to.
    Future<List<List<double>>> fakeEmbed(List<String> texts) async {
      const vectors = {
        'reference': [1.0, 0.0],
        'close': [0.9, 0.1],
        'far': [0.1, 0.9],
        'same': [0.9, 0.1],
      };
      return [for (final t in texts) vectors[t]!];
    }

    test('ranks the closest answer first', () async {
      final scorer = ClosestMatchScorer(embedder: fakeEmbed);

      final result = await scorer.score(reference: 'reference', answers: {'anna': 'far', 'ben': 'close'});

      expect(result.map((s) => s.playerId), ['ben', 'anna']);
      expect(result.first.similarity, greaterThan(result.last.similarity));
    });

    test('equal similarity keeps the input order', () async {
      final scorer = ClosestMatchScorer(embedder: fakeEmbed);

      final result = await scorer.score(reference: 'reference', answers: {'anna': 'same', 'ben': 'close'});

      expect(result.map((s) => s.playerId), ['anna', 'ben']);
    });

    test('no answers gives an empty list without calling the embedder', () async {
      final scorer = ClosestMatchScorer(embedder: (_) => throw StateError('must not be called'));

      expect(await scorer.score(reference: 'reference', answers: {}), isEmpty);
    });
  });
}
