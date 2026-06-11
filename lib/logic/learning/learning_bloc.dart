import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/database_service.dart';
import 'learning_event.dart';
import 'learning_state.dart';

class LearningBloc extends Bloc<LearningEvent, LearningState> {
  final DatabaseService _databaseService;

  LearningBloc(this._databaseService) : super(LearningInitial()) {
    on<LoadFlashcardsForToday>(_onLoadFlashcardsForToday);
    on<AnswerFlashcard>(_onAnswerFlashcard);
    on<ResetDemo>(_onResetDemo);
  }

  Future<void> _onLoadFlashcardsForToday(LoadFlashcardsForToday event, Emitter<LearningState> emit) async {
    emit(LearningLoading());
    try {
      final flashcards = await _databaseService.getFlashcardsForToday();

      if (flashcards.isEmpty) {
        emit(LearningFinished());
      } else {
        emit(LearningLoaded(flashcards));
      }
    } catch (e) {
      emit(LearningError("Błąd ładowania fiszek: $e"));
    }
  }

  Future<void> _onAnswerFlashcard(AnswerFlashcard event, Emitter<LearningState> emit) async {
    if (state is LearningLoaded) {
      try {
        // save changes (Leitner)
        await _databaseService.updateFlashcardProgress(event.flashcard, event.isCorrect);

        // Pull updated List
        final flashcards = await _databaseService.getFlashcardsForToday();

        if (flashcards.isEmpty) {
          emit(LearningFinished());
        } else {
          emit(LearningLoaded(flashcards));
        }
      } catch (e) {
        emit(LearningError("Błąd zapisu odpowiedzi: $e"));
      }
    }
  }

  Future<void> _onResetDemo(ResetDemo event, Emitter<LearningState> emit) async {
    emit(LearningLoading());
    await _databaseService.resetDemoData();
    add(LoadFlashcardsForToday());
  }
}