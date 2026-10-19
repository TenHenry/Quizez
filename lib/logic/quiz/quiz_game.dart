import '../../data/models/quiz_question.dart';

/// Points for one answer: a correct answer gives 500, plus up to 500 more for answering fast.
int pointsFor({required bool correct, required int elapsedMs, required int totalMs}) {
  if (!correct) return 0;
  final remaining = (1 - elapsedMs / totalMs).clamp(0.0, 1.0);
  return 500 + (500 * remaining).round();
}

/// A player's place in the ranking.
class Standing {
  final String playerId;
  final int score;
  const Standing(this.playerId, this.score);
}

/// What happened in one finished round.
class RoundResult {
  final int correctIndex;

  /// Points gained in this round, per player (0 for wrong or missing answers).
  final Map<String, int> gained;

  /// Chosen option per player (players who did not answer are missing).
  final Map<String, int> choices;

  /// Total scores after this round.
  final Map<String, int> scores;

  const RoundResult({required this.correctIndex, required this.gained, required this.choices, required this.scores});
}

class _Answer {
  final int choice;
  final int elapsedMs;
  const _Answer(this.choice, this.elapsedMs);
}

/// Rules of one quiz game. It runs on the host's device only - the host decides who answered correctly and how many points they get.
class QuizGame {
  QuizGame({required this.questions, required this.secondsPerQuestion, required Iterable<String> players}) {
    for (final id in players) {
      scores[id] = 0;
    }
  }

  final List<QuizQuestion> questions;
  final int secondsPerQuestion;
  final Map<String, int> scores = {};

  int _index = -1;
  final Map<String, _Answer> _answers = {};

  int get total => questions.length;
  int get index => _index;
  bool get hasNext => _index + 1 < questions.length;
  QuizQuestion get current => questions[_index];
  int get answeredCount => _answers.length;

  /// Moves to the next question and forgets the answers of the previous one.
  QuizQuestion nextQuestion() {
    _index++;
    _answers.clear();
    return current;
  }

  /// Records an answer. Returns false when it is ignored (unknown player, answer for another round, second answer).
  bool submitAnswer({required String playerId, required int questionIndex, required int choice, required int elapsedMs}) {
    if (!scores.containsKey(playerId)) return false;
    if (questionIndex != _index) return false;
    if (_answers.containsKey(playerId)) return false;
    if (choice < 0 || choice >= current.options.length) return false;

    _answers[playerId] = _Answer(choice, elapsedMs.clamp(0, secondsPerQuestion * 1000));
    return true;
  }

  /// True when every one of [players] has answered the current question.
  bool allAnswered(Iterable<String> players) => players.every(_answers.containsKey);

  /// Adds a player who joined after the start with 0 points (not used by the lobby, kept for reconnects).
  void ensurePlayer(String playerId) => scores.putIfAbsent(playerId, () => 0);

  /// Scores the current round.
  RoundResult finishRound() {
    final gained = <String, int>{};
    final choices = <String, int>{};

    for (final id in scores.keys.toList()) {
      final answer = _answers[id];
      if (answer == null) {
        gained[id] = 0;
        continue;
      }
      choices[id] = answer.choice;
      final points = pointsFor(
        correct: answer.choice == current.correctIndex,
        elapsedMs: answer.elapsedMs,
        totalMs: secondsPerQuestion * 1000,
      );
      gained[id] = points;
      scores[id] = scores[id]! + points;
    }

    return RoundResult(
      correctIndex: current.correctIndex,
      gained: gained,
      choices: choices,
      scores: Map.of(scores),
    );
  }

  /// Players sorted by score (highest first).
  List<Standing> ranking() {
    final standings = [for (final e in scores.entries) Standing(e.key, e.value)];
    standings.sort((a, b) => b.score.compareTo(a.score));
    return standings;
  }
}
