import 'package:equatable/equatable.dart';
import '../../data/services/quiz_room_service.dart';
import 'quiz_config.dart';

abstract class QuizEvent extends Equatable {
  const QuizEvent();

  @override
  List<Object?> get props => [];
}

/// The player creates a room and becomes its host.
class CreateRoomRequested extends QuizEvent {
  final QuizConfig config;
  const CreateRoomRequested(this.config);

  @override
  List<Object?> get props => [config];
}

class JoinRoomRequested extends QuizEvent {
  final String code;
  const JoinRoomRequested(this.code);

  @override
  List<Object?> get props => [code];
}

/// Host only: loads the questions and starts the game.
class StartGameRequested extends QuizEvent {}

class AnswerSelected extends QuizEvent {
  final int choice;
  const AnswerSelected(this.choice);

  @override
  List<Object?> get props => [choice];
}

/// Closest Match: the player sends the description of the term.
class SubmitTextRequested extends QuizEvent {
  final String text;
  const SubmitTextRequested(this.text);

  @override
  List<Object?> get props => [text];
}

/// The player sends an emote (an emoji bought in the shop) to the room.
class SendEmoteRequested extends QuizEvent {
  final String glyph;
  const SendEmoteRequested(this.glyph);

  @override
  List<Object?> get props => [glyph];
}

class LeaveRoomRequested extends QuizEvent {}

// ---- internal events (fired by the room connection and the host's timers)

class PlayersUpdated extends QuizEvent {
  final List<RoomPlayer> players;
  const PlayersUpdated(this.players);

  @override
  List<Object?> get props => [players.map((p) => p.id).toList()];
}

class MessageReceived extends QuizEvent {
  final RoomMessage message;
  const MessageReceived(this.message);
}

/// Host timer: time for the current question is over.
class RoundTimedOut extends QuizEvent {
  final int index;
  const RoundTimedOut(this.index);

  @override
  List<Object?> get props => [index];
}

/// Host timer: show the next question (or finish the game).
class AdvanceRequested extends QuizEvent {}
