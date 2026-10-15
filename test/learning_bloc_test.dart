import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizez/data/models/flashcard.dart';
import 'package:quizez/data/services/database_service.dart';
import 'package:quizez/logic/learning/learning_bloc.dart';
import 'package:quizez/logic/learning/learning_event.dart';
import 'package:quizez/logic/learning/learning_state.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

Flashcard card(String id) => Flashcard()
  ..uuid = id
  ..question = 'q$id'
  ..answer = 'a$id'
  ..deckUuid = 'deck';

void main() {
  setUpAll(() => registerFallbackValue(card('fallback')));

  late MockDatabaseService db;
  late LearningBloc bloc;

  setUp(() {
    db = MockDatabaseService();
    bloc = LearningBloc(db);
    when(() => db.updateFlashcardProgress(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() => bloc.close());

  test('empty deck finishes immediately with nothing to study', () async {
    when(() => db.getSessionCards('deck', hardOnly: false)).thenAnswer((_) async => []);

    bloc.add(const LoadFlashcardsForToday('deck'));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<LearningLoading>(), isA<LearningFinished>().having((s) => s.total, 'total', 0)]),
    );
  });

  test('a session tracks the score and finishes after the last card', () async {
    final a = card('a');
    final b = card('b');
    when(() => db.getSessionCards('deck', hardOnly: false)).thenAnswer((_) async => [a, b]);

    bloc.add(const LoadFlashcardsForToday('deck'));
    await bloc.stream.firstWhere((s) => s is LearningLoaded);

    bloc.add(AnswerCardEvent(a, true));
    final afterFirst = await bloc.stream.firstWhere((s) => s is LearningLoaded) as LearningLoaded;
    expect(afterFirst.flashcards, [b]);
    expect(afterFirst.correct, 1);
    expect(afterFirst.total, 2);

    bloc.add(AnswerCardEvent(b, false));
    final finished = await bloc.stream.firstWhere((s) => s is LearningFinished) as LearningFinished;
    expect(finished.correct, 1);
    expect(finished.incorrect, 1);

    verify(() => db.updateFlashcardProgress(a, true)).called(1);
    verify(() => db.updateFlashcardProgress(b, false)).called(1);
  });

  test('hard-only mode is passed to the database', () async {
    when(() => db.getSessionCards('deck', hardOnly: true)).thenAnswer((_) async => [card('x')]);

    bloc.add(const LoadFlashcardsForToday('deck', hardOnly: true));
    await bloc.stream.firstWhere((s) => s is LearningLoaded);

    verify(() => db.getSessionCards('deck', hardOnly: true)).called(1);
  });

  test('a storage error becomes LearningError', () async {
    when(() => db.getSessionCards('deck', hardOnly: false)).thenThrow(Exception('boom'));

    bloc.add(const LoadFlashcardsForToday('deck'));
    await expectLater(bloc.stream, emitsInOrder([isA<LearningLoading>(), isA<LearningError>()]));
  });
}
