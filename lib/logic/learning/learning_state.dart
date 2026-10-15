import 'package:equatable/equatable.dart';
import '../../data/models/flashcard.dart';

abstract class LearningState extends Equatable {
  const LearningState();

  @override
  List<Object> get props => [];
}

class LearningInitial extends LearningState {}

class LearningLoading extends LearningState {}

class LearningLoaded extends LearningState {
  final List<Flashcard> flashcards;

  const LearningLoaded(this.flashcards);

  @override
  List<Object> get props => [flashcards];
}

class LearningFinished extends LearningState {}

class LearningError extends LearningState {
  final String message;

  const LearningError(this.message);

  @override
  List<Object> get props => [message];
}