import 'package:equatable/equatable.dart';
import '../../data/models/flashcard.dart';

abstract class LearningEvent extends Equatable {
  const LearningEvent();

  @override
  List<Object> get props => [];
}

/// Starts a study session for a deck. With [hardOnly] only cards marked as difficult are used.
class LoadFlashcardsForToday extends LearningEvent {
  final String deckUuid;
  final bool hardOnly;
  const LoadFlashcardsForToday(this.deckUuid, {this.hardOnly = false});

  @override
  List<Object> get props => [deckUuid, hardOnly];
}

/// The player rated the current card ("Know" / "Don't know").
class AnswerCardEvent extends LearningEvent {
  final Flashcard flashcard;
  final bool isCorrect;

  const AnswerCardEvent(this.flashcard, this.isCorrect);

  @override
  List<Object> get props => [flashcard, isCorrect];
}

/// The player toggled the "difficult" flag of the current card during a session.
class ToggleDifficultEvent extends LearningEvent {
  final Flashcard flashcard;
  const ToggleDifficultEvent(this.flashcard);

  @override
  List<Object> get props => [flashcard];
}
