import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/answer_log.dart';
import '../../data/models/quiz_question.dart';
import '../../data/services/daily_quiz_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/quiz_question_service.dart';
import '../quiz/quiz_game.dart';
import 'daily_quiz.dart';

abstract class DailyState extends Equatable {
  const DailyState();

  @override
  List<Object?> get props => [];
}

class DailyLoading extends DailyState {
  final String message;
  const DailyLoading([this.message = 'Loading...']);

  @override
  List<Object?> get props => [message];
}

/// Before the game: shows whether today's quiz was already played.
class DailyIntro extends DailyState {
  final DailyResult? result;
  const DailyIntro(this.result);

  @override
  List<Object?> get props => [result?.score];
}

/// A question. [revealed] = the answer was given (or time ran out) and the correct option is shown.
class DailyQuestion extends DailyState {
  final int index;
  final int total;
  final QuizQuestion question;
  final int seconds;
  final DateTime receivedAt;
  final int? selected;
  final bool revealed;
  final int score;

  const DailyQuestion({
    required this.index,
    required this.total,
    required this.question,
    required this.seconds,
    required this.receivedAt,
    required this.score,
    this.selected,
    this.revealed = false,
  });

  @override
  List<Object?> get props => [index, selected, revealed, score, receivedAt];
}

class DailyFinished extends DailyState {
  final int score;
  final int correct;
  final int total;

  /// True once the result is stored on the server.
  final bool saved;
  final String? error;

  const DailyFinished({required this.score, required this.correct, required this.total, this.saved = false, this.error});

  @override
  List<Object?> get props => [score, correct, total, saved, error];
}

class DailyError extends DailyState {
  final String message;
  const DailyError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Plays the daily quiz: 10 questions, the same for everybody, 15 seconds each, one attempt per day.
class DailyQuizCubit extends Cubit<DailyState> {
  DailyQuizCubit({
    required DailyQuizService service,
    required QuizQuestionService questions,
    DatabaseService? database,
    DateTime Function()? clock,
    this.feedbackDelay = const Duration(milliseconds: 1600),
    this.secondsPerQuestion = dailySecondsPerQuestion,
  })  : _service = service,
        _questions = questions,
        _database = database,
        _clock = clock ?? DateTime.now,
        super(const DailyLoading());

  final DailyQuizService _service;
  final QuizQuestionService _questions;
  final DatabaseService? _database;
  final DateTime Function() _clock;

  /// How long the correct answer stays on screen before the next question.
  final Duration feedbackDelay;
  final int secondsPerQuestion;

  List<QuizQuestion> _quiz = [];
  int _index = 0;
  int _score = 0;
  int _correct = 0;
  DateTime _receivedAt = DateTime.now();
  Timer? _timer;

  String get _today => dayKey(_clock());

  /// Checks whether today's quiz was already played.
  Future<void> load() async {
    emit(const DailyLoading());
    try {
      emit(DailyIntro(await _service.getMyResult(_today)));
    } catch (e) {
      emit(DailyError(e.toString()));
    }
  }

  Future<void> start() async {
    emit(const DailyLoading('Preparing today\'s questions...'));
    try {
      final bank = await _questions.allFromBank();
      _quiz = pickDailyQuestions(bank, _clock());
      if (_quiz.length < 3) throw const QuizException('The question bank is too small for a daily quiz.');
    } catch (e) {
      emit(DailyError(e.toString()));
      return;
    }

    _index = 0;
    _score = 0;
    _correct = 0;
    _showQuestion();
  }

  void _showQuestion() {
    _receivedAt = DateTime.now();
    emit(DailyQuestion(
      index: _index,
      total: _quiz.length,
      question: _quiz[_index],
      seconds: secondsPerQuestion,
      receivedAt: _receivedAt,
      score: _score,
    ));
    _timer = Timer(Duration(seconds: secondsPerQuestion), () => _reveal(null));
  }

  /// The player picked an option.
  void answer(int choice) {
    final current = state;
    if (current is! DailyQuestion || current.revealed) return;
    _reveal(choice);
  }

  void _reveal(int? choice) {
    final current = state;
    if (current is! DailyQuestion || current.revealed) return;
    _timer?.cancel();

    final question = _quiz[_index];
    final isCorrect = choice == question.correctIndex;
    if (isCorrect) {
      _correct++;
      _score += pointsFor(
        correct: true,
        elapsedMs: DateTime.now().difference(_receivedAt).inMilliseconds,
        totalMs: secondsPerQuestion * 1000,
      );
    }
    _logAnswer(question, isCorrect);

    emit(DailyQuestion(
      index: current.index,
      total: current.total,
      question: question,
      seconds: current.seconds,
      receivedAt: current.receivedAt,
      score: _score,
      selected: choice,
      revealed: true,
    ));
    _timer = Timer(feedbackDelay, _next);
  }

  void _next() {
    _index++;
    if (_index >= _quiz.length) {
      _finish();
    } else {
      _showQuestion();
    }
  }

  Future<void> _finish() async {
    emit(DailyFinished(score: _score, correct: _correct, total: _quiz.length));
    await _save();
  }

  /// Sends the result to the server (also used by the "Try again" button when saving failed).
  Future<void> _save() async {
    try {
      await _service.submitResult(day: _today, score: _score, correct: _correct, total: _quiz.length);
      emit(DailyFinished(score: _score, correct: _correct, total: _quiz.length, saved: true));
    } catch (e) {
      emit(DailyFinished(score: _score, correct: _correct, total: _quiz.length, error: e.toString()));
    }
  }

  Future<void> retrySave() => _save();

  void _logAnswer(QuizQuestion question, bool correct) {
    final database = _database;
    if (database == null) return;
    database
        .logAnswer(source: AnswerLog.sourceQuiz, category: question.category ?? 'Daily quiz', correct: correct)
        .catchError((_) {}); // statistics must never break the game
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
