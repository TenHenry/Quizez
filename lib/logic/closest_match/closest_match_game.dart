import '../../data/models/game_term.dart';

/// Points for a place in the round: 1st = 1000, 2nd = 700, 3rd = 500, everybody else who wrote something = 300.
int pointsForRank(int rank) {
  const podium = [1000, 700, 500];
  return rank < podium.length ? podium[rank] : 300;
}

/// How one player did in a round.
class TermResult {
  final String playerId;
  final String text;

  /// Cosine similarity to the reference definition (0-1; can be slightly negative for unrelated texts).
  final double similarity;

  /// 0 = closest answer of the round.
  final int rank;
  final int points;

  const TermResult({required this.playerId, required this.text, required this.similarity, required this.rank, required this.points});
}

/// Outcome of a finished round.
class TermRoundResult {
  final String definition;

  /// Players who submitted a description, best first.
  final List<TermResult> results;

  /// Total scores after this round (everybody, including players who did not answer).
  final Map<String, int> scores;

  const TermRoundResult({required this.definition, required this.results, required this.scores});
}

class _Submission {
  final String text;
  final int elapsedMs;
  const _Submission(this.text, this.elapsedMs);
}

/// Rules of the "Closest Match" mode. Runs on the host's device, like [QuizGame].
///
/// Every round shows a term; the players describe it in their own words. The host compares the descriptions
/// with the reference definition (see [ClosestMatchScorer]) and this class turns the similarities into places and points.
/// If two players are equally close, the one who submitted earlier wins.
class ClosestMatchGame {
  ClosestMatchGame({required this.terms, required this.secondsPerRound, required Iterable<String> players}) {
    for (final id in players) {
      scores[id] = 0;
    }
  }

  static const maxTextLength = 300;

  /// Similarities closer than this are treated as equal, so the earlier submission decides.
  static const tieMargin = 0.005;

  final List<GameTerm> terms;
  final int secondsPerRound;
  final Map<String, int> scores = {};

  int _index = -1;
  final Map<String, _Submission> _submissions = {};

  int get total => terms.length;
  int get index => _index;
  bool get hasNext => _index + 1 < terms.length;
  GameTerm get current => terms[_index];

  GameTerm nextTerm() {
    _index++;
    _submissions.clear();
    return current;
  }

  /// Records a description. Returns false when it is ignored (unknown player, other round, empty text, second submission).
  bool submitText({required String playerId, required int roundIndex, required String text, required int elapsedMs}) {
    if (!scores.containsKey(playerId)) return false;
    if (roundIndex != _index) return false;
    if (_submissions.containsKey(playerId)) return false;

    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;

    _submissions[playerId] = _Submission(
      cleaned.length > maxTextLength ? cleaned.substring(0, maxTextLength) : cleaned,
      elapsedMs.clamp(0, secondsPerRound * 1000),
    );
    return true;
  }

  bool allSubmitted(Iterable<String> players) => players.every(_submissions.containsKey);

  /// Texts submitted in the current round (player id -> text), earliest submission first.
  Map<String, String> get submittedTexts {
    final ids = _submissions.keys.toList()..sort((a, b) => _submissions[a]!.elapsedMs.compareTo(_submissions[b]!.elapsedMs));
    return {for (final id in ids) id: _submissions[id]!.text};
  }

  /// Ranks the round. [similarities] maps player id -> similarity for every player in [submittedTexts].
  TermRoundResult finishRound(Map<String, double> similarities) {
    final ids = _submissions.keys.toList();

    // Closer answers first; (almost) equal similarity -> earlier submission first.
    ids.sort((a, b) {
      final sa = similarities[a] ?? 0;
      final sb = similarities[b] ?? 0;
      if ((sa - sb).abs() > tieMargin) return sb.compareTo(sa);
      return _submissions[a]!.elapsedMs.compareTo(_submissions[b]!.elapsedMs);
    });

    final results = <TermResult>[];
    for (var rank = 0; rank < ids.length; rank++) {
      final id = ids[rank];
      final points = pointsForRank(rank);
      scores[id] = scores[id]! + points;
      results.add(TermResult(
        playerId: id,
        text: _submissions[id]!.text,
        similarity: similarities[id] ?? 0,
        rank: rank,
        points: points,
      ));
    }

    return TermRoundResult(definition: current.definition, results: results, scores: Map.of(scores));
  }
}
