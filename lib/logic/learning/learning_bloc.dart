import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/flashcard.dart';
import '../../data/services/database_service.dart';
import 'learning_event.dart';
import 'learning_state.dart';

class LearningBloc extends Bloc<LearningEvent, LearningState> {
  final DatabaseService _databaseService;

  LearningBloc(this._databaseService) : super(LearningInitial()) {
    on<LoadFlashcardsForToday>(_onLoadFlashcardsForToday);
    on<AnswerFlashcard>(_onAnswerFlashcard);
  }

  Future<void> _onLoadFlashcardsForToday(LoadFlashcardsForToday event, Emitter<LearningState> emit) async {
    emit(LearningLoading());
    try {
      final flashcards = await _databaseService.getRandomSessionCards(event.deckId);

      if (flashcards.isEmpty) {
        emit(LearningFinished());
      } else {
        emit(LearningLoaded(flashcards));
      }
    } catch (e) {
      emit(LearningError("Błąd ładowania sesji: $e"));
    }
  }

  Future<void> _onAnswerFlashcard(AnswerFlashcard event, Emitter<LearningState> emit) async {
    if (state is LearningLoaded) {
      final currentCards = List<Flashcard>.from((state as LearningLoaded).flashcards);

      try {
        await _databaseService.updateFlashcardProgress(event.flashcard, event.isCorrect);

        currentCards.remove(event.flashcard);

        if (currentCards.isEmpty) {
          emit(LearningFinished());
        } else {
          emit(LearningLoaded(currentCards));
        }
      } catch (e) {
        emit(LearningError("Błąd zapisu odpowiedzi: $e"));
      }
    }
  }
}