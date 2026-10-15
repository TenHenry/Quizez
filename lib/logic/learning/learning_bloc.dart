import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/database_service.dart';
import 'learning_event.dart';
import 'learning_state.dart';

class LearningBloc extends Bloc<LearningEvent, LearningState> {
  final DatabaseService _databaseService;

  LearningBloc(this._databaseService) : super(LearningInitial()) {
    on<LoadFlashcardsForToday>(_onLoadFlashcardsForToday);
    on<AnswerCardEvent>(_onAnswerCard);
    on<ToggleDifficultEvent>(_onToggleDifficult);
  }

  Future<void> _onLoadFlashcardsForToday(LoadFlashcardsForToday event, Emitter<LearningState> emit) async {
    emit(LearningLoading());
    try {
      final flashcards = await _databaseService.getSessionCards(event.deckUuid, hardOnly: event.hardOnly);

      if (flashcards.isEmpty) {
        emit(const LearningFinished());
      } else {
        emit(LearningLoaded(flashcards, total: flashcards.length));
      }
    } catch (e) {
      emit(LearningError('Could not load the session: $e'));
    }
  }

  Future<void> _onAnswerCard(AnswerCardEvent event, Emitter<LearningState> emit) async {
    final current = state;
    if (current is! LearningLoaded) return;

    try {
      await _databaseService.updateFlashcardProgress(event.flashcard, event.isCorrect);

      final remaining = List.of(current.flashcards)..remove(event.flashcard);
      final correct = current.correct + (event.isCorrect ? 1 : 0);
      final incorrect = current.incorrect + (event.isCorrect ? 0 : 1);

      if (remaining.isEmpty) {
        emit(LearningFinished(correct: correct, incorrect: incorrect));
      } else {
        emit(LearningLoaded(remaining, correct: correct, incorrect: incorrect, total: current.total));
      }
    } catch (e) {
      emit(LearningError('Could not save the answer: $e'));
    }
  }

  Future<void> _onToggleDifficult(ToggleDifficultEvent event, Emitter<LearningState> emit) async {
    final current = state;
    if (current is! LearningLoaded) return;

    try {
      await _databaseService.setFlashcardDifficult(event.flashcard, !event.flashcard.isDifficult);
      emit(LearningLoaded(
        List.of(current.flashcards),
        correct: current.correct,
        incorrect: current.incorrect,
        total: current.total,
      ));
    } catch (e) {
      emit(LearningError('Could not update the card: $e'));
    }
  }
}
