import 'package:equatable/equatable.dart';
import '../../data/models/flashcard.dart';

abstract class LearningState extends Equatable {
  const LearningState();

  @override
  List<Object> get props => [];
}

class LearningInitial extends LearningState {}

class LearningLoading extends LearningState {}

/// Session in progress: [flashcards] are the cards still to answer, [correct]/[incorrect] is the running score.
class LearningLoaded extends LearningState {
  final List<Flashcard> flashcards;
  final int correct;
  final int incorrect;
  final int total;

  const LearningLoaded(this.flashcards, {this.correct = 0, this.incorrect = 0, required this.total});

  @override
  List<Object> get props => [flashcards, correct, incorrect, total, flashcards.map((c) => c.isDifficult).toList()];
}

/// Session finished. [total] == 0 means there was nothing to study (empty deck).
class LearningFinished extends LearningState {
  final int correct;
  final int incorrect;

  const LearningFinished({this.correct = 0, this.incorrect = 0});

  int get total => correct + incorrect;

  @override
  List<Object> get props => [correct, incorrect];
}

class LearningError extends LearningState {
  final String message;

  const LearningError(this.message);

  @override
  List<Object> get props => [message];
}
