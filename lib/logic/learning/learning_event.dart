import 'package:equatable/equatable.dart';
import '../../data/models/flashcard.dart';

abstract class LearningEvent extends Equatable {
  const LearningEvent();

  @override
  List<Object> get props => [];
}

class LoadFlashcardsForToday extends LearningEvent {}

class AnswerFlashcard extends LearningEvent {
  final Flashcard flashcard;
  final bool isCorrect;

  const AnswerFlashcard(this.flashcard, this.isCorrect);

  @override
  List<Object> get props => [flashcard, isCorrect];
}