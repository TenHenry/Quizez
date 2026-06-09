import 'package:isar/isar.dart';

part 'flashcard.g.dart';

@collection
class Flashcard {
  Id id = Isar.autoIncrement;

  late String question;
  late String answer;

  // Letiner Parameter
  int box = 1;
  DateTime nextReview = DateTime.now();
  bool isDifficult = false;
}