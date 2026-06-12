import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

class DatabaseService {
  late Future<Isar> db;
  final _supabase = Supabase.instance.client;

  DatabaseService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    final dir = await getApplicationDocumentsDirectory();
    if (Isar.instanceNames.isEmpty) {
      return await Isar.open(
        [FlashcardSchema, DeckSchema],
        directory: dir.path,
      );
    }
    return Isar.getInstance()!;
  }


  Future<void> createNewDeck(String name) async {
    final isar = await db;
    final newDeck = Deck()..name = name;

    await isar.writeTxn(() async {
      await isar.decks.put(newDeck);
    });
  }

  Future<List<Deck>> getAllDecks() async {
    final isar = await db;
    return await isar.decks.where().findAll();
  }


  Future<List<Flashcard>> getRandomSessionCards(int deckId) async {
    final isar = await db;

    final allCards = await isar.flashcards
        .filter()
        .deckIdEqualTo(deckId)
        .findAll();

    allCards.shuffle();
    return allCards.take(20).toList();
  }


  Future<void> addNewFlashcard(String question, String answer, int deckId) async {
    final isar = await db;
    final newCard = Flashcard()
      ..question = question
      ..answer = answer
      ..box = 1
      ..nextReview = DateTime.now()
      ..isDifficult = false
      ..deckId = deckId;

    int generatedId;
    await isar.writeTxn(() async {
      generatedId = await isar.flashcards.put(newCard);
      newCard.id = generatedId;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('flashcards').insert({
          'id': newCard.id,
          'user_id': userId,
          'question': newCard.question,
          'answer': newCard.answer,
          'box': newCard.box,
          'next_review': newCard.nextReview.toIso8601String(),
          'is_difficult': newCard.isDifficult,
          'deck_id': deckId,
        });
      }
    } catch (e) {
      print("Nie udało się zapisać w Supabase: $e");
    }
  }

  // letiner algoritthm
  Future<void> updateFlashcardProgress(Flashcard card, bool isCorrect) async {
    final isar = await db;
    if (isCorrect) {
      if (card.box < 5) card.box++;
    } else {
      card.box = 1;
      card.isDifficult = true;
    }
    card.nextReview = DateTime.now();

    await isar.writeTxn(() async {
      await isar.flashcards.put(card);
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('flashcards').upsert({
          'id': card.id,
          'user_id': userId,
          'question': card.question,
          'answer': card.answer,
          'box': card.box,
          'next_review': card.nextReview.toIso8601String(),
          'is_difficult': card.isDifficult,
          'deck_id': card.deckId,
        });
      }
    } catch (e) {
      print("Błąd Supabase: $e");
    }
  }
}