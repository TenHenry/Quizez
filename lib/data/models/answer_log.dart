import 'package:isar/isar.dart';

part 'answer_log.g.dart';

/// One answered question (a flashcard rated "Know"/"Don't know" or a quiz question). Used for statistics.
/// Entries are only ever added, never edited, so synchronization is a simple "send what is missing".
@collection
class AnswerLog {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  /// [sourceFlashcards] or [sourceQuiz].
  late String source;

  /// Deck name for flashcards, question category (or AI topic) for the quiz.
  late String category;

  late bool correct;

  DateTime answeredAt = DateTime.now().toUtc();

  /// True when this entry is not yet sent to Supabase.
  @Index()
  bool pendingSync = true;

  static const sourceFlashcards = 'flashcards';
  static const sourceQuiz = 'quiz';
}
