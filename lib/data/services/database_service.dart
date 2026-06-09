import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/flashcard.dart';

class DatabaseService {
  late Future<Isar> db;

  DatabaseService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    final dir = await getApplicationDocumentsDirectory();
    if (Isar.instanceNames.isEmpty) {
      return await Isar.open(
        [FlashcardSchema],
        directory: dir.path,
      );
    }
    return Isar.getInstance()!;
  }

  // --- ALGORYTM LEITNERA ---
  Future<void> updateFlashcardProgress(Flashcard card, bool isCorrect) async {
    final isar = await db;

    if (isCorrect) {
      if (card.box < 5) card.box++;
    } else {
      card.box = 1;
      card.isDifficult = true;
    }

    final intervals = [0, 1, 3, 7, 14, 30];
    card.nextReview = DateTime.now().add(Duration(days: intervals[card.box]));

    await isar.writeTxn(() async {
      await isar.flashcards.put(card);
    });
  }

  Future<List<Flashcard>> getFlashcardsForToday() async {
    final isar = await db;
    return await isar.flashcards
        .filter()
        .nextReviewLessThan(DateTime.now())
        .findAll();
  }
}