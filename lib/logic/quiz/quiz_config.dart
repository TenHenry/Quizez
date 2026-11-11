/// Where the questions of a game come from.
enum QuizSource { bank, ai }

/// Game type played in a room.
enum QuizMode { multipleChoice, closestMatch }

/// Settings chosen by the host when creating a room.
class QuizConfig {
  final QuizMode mode;
  final QuizSource source;

  /// Question bank category (null = any category). Used with [QuizSource.bank].
  final String? category;

  /// Topic described by the host. Used with [QuizSource.ai].
  final String topic;

  /// 0 = any (bank only), 1 = easy, 2 = medium, 3 = hard.
  final int difficulty;

  final int questionCount;
  final int secondsPerQuestion;

  const QuizConfig({
    this.mode = QuizMode.multipleChoice,
    required this.source,
    this.category,
    this.topic = '',
    this.difficulty = 0,
    this.questionCount = 10,
    this.secondsPerQuestion = 15,
  });

  static const questionCounts = [5, 10, 15];
  static const secondsOptions = [10, 15, 20];

  /// Closest Match: number of rounds and seconds to write a description.
  static const roundCounts = [3, 5, 8];
  static const writeSecondsOptions = [30, 45, 60];

  /// Lobby needs at least this many players. Set to 1 during alpha so the mode can be tried alone;
  /// the thesis assumes 2+ players.
  static const minPlayers = 1;
}
