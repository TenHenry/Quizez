import 'package:equatable/equatable.dart';
import '../../data/services/quiz_room_service.dart';

abstract class QuizState extends Equatable {
  const QuizState();

  @override
  List<Object?> get props => [];
}

/// No room: the player can create or join one. [error] explains why the previous attempt ended.
class QuizMenu extends QuizState {
  final String? error;
  const QuizMenu({this.error});

  @override
  List<Object?> get props => [error];
}

class QuizConnecting extends QuizState {
  final String message;
  const QuizConnecting(this.message);

  @override
  List<Object?> get props => [message];
}

class QuizLobby extends QuizState {
  final String code;
  final List<RoomPlayer> players;
  final bool isHost;

  /// Problem shown in the lobby, e.g. questions could not be loaded.
  final String? error;

  const QuizLobby({required this.code, required this.players, required this.isHost, this.error});

  @override
  List<Object?> get props => [code, players.map((p) => p.id).toList(), isHost, error];
}

class QuizQuestionActive extends QuizState {
  final int index;
  final int total;
  final String text;
  final List<String> options;
  final int seconds;

  /// When the question reached this device - the countdown and the answer time are measured from it.
  final DateTime receivedAt;

  /// Option chosen by this player (null = not answered yet).
  final int? selected;

  const QuizQuestionActive({
    required this.index,
    required this.total,
    required this.text,
    required this.options,
    required this.seconds,
    required this.receivedAt,
    this.selected,
  });

  QuizQuestionActive withSelected(int choice) => QuizQuestionActive(
        index: index,
        total: total,
        text: text,
        options: options,
        seconds: seconds,
        receivedAt: receivedAt,
        selected: choice,
      );

  @override
  List<Object?> get props => [index, selected, receivedAt];
}

/// One line of the scoreboard.
class RankingEntry {
  final String playerId;
  final String nickname;
  final int score;

  /// Points gained in the round that was just played (0 on the final ranking).
  final int gained;

  /// Emoji of the player's avatar (null = none).
  final String? avatar;

  const RankingEntry({required this.playerId, required this.nickname, required this.score, this.gained = 0, this.avatar});
}

/// The answer of the finished round and the scoreboard.
class QuizReveal extends QuizState {
  final int index;
  final int total;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int? selected;
  final List<RankingEntry> ranking;
  final bool isLast;

  const QuizReveal({
    required this.index,
    required this.total,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.selected,
    required this.ranking,
    required this.isLast,
  });

  @override
  List<Object?> get props => [index, selected, ranking.map((r) => '${r.playerId}:${r.score}').toList()];
}

/// Closest Match: a term to describe in your own words.
class QuizTermActive extends QuizState {
  final int index;
  final int total;
  final String term;
  final String category;
  final int seconds;
  final DateTime receivedAt;

  /// What this player sent (null = nothing sent yet).
  final String? submitted;

  const QuizTermActive({
    required this.index,
    required this.total,
    required this.term,
    required this.category,
    required this.seconds,
    required this.receivedAt,
    this.submitted,
  });

  QuizTermActive withSubmitted(String text) => QuizTermActive(
        index: index,
        total: total,
        term: term,
        category: category,
        seconds: seconds,
        receivedAt: receivedAt,
        submitted: text,
      );

  @override
  List<Object?> get props => [index, submitted, receivedAt];
}

/// One player's description in the results of a Closest Match round.
class TermResultEntry {
  final String playerId;
  final String nickname;
  final String text;

  /// 0-100 (how close the description is to the reference definition).
  final int closenessPercent;
  final int rank;
  final int points;

  const TermResultEntry({
    required this.playerId,
    required this.nickname,
    required this.text,
    required this.closenessPercent,
    required this.rank,
    required this.points,
  });
}

/// Closest Match: the reference definition, the players' descriptions with their places, and the scoreboard.
class QuizTermResults extends QuizState {
  final int index;
  final int total;
  final String term;
  final String definition;
  final List<TermResultEntry> entries;
  final List<RankingEntry> ranking;
  final bool isLast;

  /// Set when the descriptions could not be compared (then only the speed decided).
  final String? note;

  const QuizTermResults({
    required this.index,
    required this.total,
    required this.term,
    required this.definition,
    required this.entries,
    required this.ranking,
    required this.isLast,
    this.note,
  });

  @override
  List<Object?> get props => [index, entries.map((e) => '${e.playerId}:${e.points}').toList()];
}

class QuizFinished extends QuizState {
  final List<RankingEntry> ranking;
  const QuizFinished(this.ranking);

  @override
  List<Object?> get props => [ranking.map((r) => '${r.playerId}:${r.score}').toList()];
}
