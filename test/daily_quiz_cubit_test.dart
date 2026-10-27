import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizez/data/models/quiz_question.dart';
import 'package:quizez/data/services/daily_quiz_service.dart';
import 'package:quizez/data/services/quiz_question_service.dart';
import 'package:quizez/logic/daily/daily_quiz_cubit.dart';

class MockDailyService extends Mock implements DailyQuizService {}

class MockQuestionService extends Mock implements QuizQuestionService {}

List<QuizQuestion> bank(int n) => [
      for (var i = 0; i < n; i++)
        QuizQuestion(text: 'Question $i', options: const ['a', 'b', 'c', 'd'], correctIndex: i % 4),
    ];

final fixedDay = DateTime.utc(2026, 10, 28, 12);

void main() {
  late MockDailyService service;
  late MockQuestionService questions;

  DailyQuizCubit cubit() => DailyQuizCubit(
        service: service,
        questions: questions,
        clock: () => fixedDay,
        feedbackDelay: Duration.zero,
        secondsPerQuestion: 60,
      );

  Future<void> settle() => Future.delayed(const Duration(milliseconds: 20));

  setUp(() {
    service = MockDailyService();
    questions = MockQuestionService();
    when(() => questions.allFromBank()).thenAnswer((_) async => bank(20));
    when(() => service.getMyResult('2026-10-28')).thenAnswer((_) async => null);
    when(() => service.submitResult(
          day: any(named: 'day'),
          score: any(named: 'score'),
          correct: any(named: 'correct'),
          total: any(named: 'total'),
        )).thenAnswer((_) async {});
  });

  test('load shows the intro without a result when the quiz was not played today', () async {
    final c = cubit();
    await c.load();

    expect(c.state, isA<DailyIntro>().having((s) => s.result, 'result', isNull));
    await c.close();
  });

  test('load shows today\'s result when the quiz was already played', () async {
    when(() => service.getMyResult('2026-10-28')).thenAnswer((_) async => const DailyResult(score: 4200, correct: 6, total: 10));
    final c = cubit();
    await c.load();

    expect(c.state, isA<DailyIntro>().having((s) => s.result?.score, 'score', 4200));
    await c.close();
  });

  test('start shows the first of ten questions', () async {
    final c = cubit();
    await c.start();

    final state = c.state as DailyQuestion;
    expect(state.index, 0);
    expect(state.total, 10);
    expect(state.revealed, isFalse);
    await c.close();
  });

  test('a correct answer scores points and reveals the answer', () async {
    final c = cubit();
    await c.start();

    c.answer((c.state as DailyQuestion).question.correctIndex);

    final state = c.state as DailyQuestion;
    expect(state.revealed, isTrue);
    expect(state.score, greaterThan(500));
    await c.close();
  });

  test('a wrong answer scores nothing and a second answer is ignored', () async {
    final c = cubit();
    await c.start();
    final first = c.state as DailyQuestion;
    final wrong = (first.question.correctIndex + 1) % 4;

    c.answer(wrong);
    c.answer(first.question.correctIndex);

    expect((c.state as DailyQuestion).score, 0);
    await c.close();
  });

  test('after the last question the result is saved once', () async {
    final c = cubit();
    await c.start();

    for (var i = 0; i < 10; i++) {
      final state = c.state as DailyQuestion;
      c.answer(i.isEven ? state.question.correctIndex : (state.question.correctIndex + 1) % 4);
      await settle();
    }

    final finished = c.state as DailyFinished;
    expect(finished.correct, 5);
    expect(finished.total, 10);
    expect(finished.saved, isTrue);
    verify(() => service.submitResult(day: '2026-10-28', score: finished.score, correct: 5, total: 10)).called(1);
    await c.close();
  });

  test('a failed save is reported and can be retried', () async {
    when(() => service.submitResult(
          day: any(named: 'day'),
          score: any(named: 'score'),
          correct: any(named: 'correct'),
          total: any(named: 'total'),
        )).thenThrow(const QuizException('Could not save the result.'));
    final c = cubit();
    await c.start();
    for (var i = 0; i < 10; i++) {
      c.answer(0);
      await settle();
    }

    expect((c.state as DailyFinished).saved, isFalse);
    expect((c.state as DailyFinished).error, isNotNull);

    when(() => service.submitResult(
          day: any(named: 'day'),
          score: any(named: 'score'),
          correct: any(named: 'correct'),
          total: any(named: 'total'),
        )).thenAnswer((_) async {});
    await c.retrySave();

    expect((c.state as DailyFinished).saved, isTrue);
    await c.close();
  });

  test('a too small bank gives an error', () async {
    when(() => questions.allFromBank()).thenAnswer((_) async => bank(2));
    final c = cubit();
    await c.start();

    expect(c.state, isA<DailyError>());
    await c.close();
  });
}
