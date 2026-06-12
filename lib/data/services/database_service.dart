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

    final box1 = allCards.where((c) => c.box == 1).toList()..shuffle();
    final box2 = allCards.where((c) => c.box == 2).toList()..shuffle();
    final box3Plus = allCards.where((c) => c.box >= 3).toList()..shuffle();

    final sessionCards = <Flashcard>[];

    sessionCards.addAll(box1.take(12));
    sessionCards.addAll(box2.take(5));
    sessionCards.addAll(box3Plus.take(3));

    if (sessionCards.length < 20) {
      final remainingCards = allCards
          .where((c) => !sessionCards.contains(c))
          .toList()
        ..shuffle();

      final missingCount = 20 - sessionCards.length;
      sessionCards.addAll(remainingCards.take(missingCount));
    }

    sessionCards.shuffle();

    return sessionCards;
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

  Future<void> syncFromSupabase() async {
    final isar = await db;
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) return;

    try {
      final response = await _supabase.from('flashcards').select().eq('user_id', userId);

      final localCards = <Flashcard>[];

      for (var row in response) {
        localCards.add(
            Flashcard()
              ..id = row['id']
              ..question = row['question']
              ..answer = row['answer']
              ..box = row['box']
              ..nextReview = DateTime.parse(row['next_review'])
              ..isDifficult = row['is_difficult'] ?? false
              ..deckId = row['deck_id']
        );
      }

      await isar.writeTxn(() async {
        await isar.flashcards.putAll(localCards);
      });

    } catch (e) {
      print("Błąd synchronizacji z Supabase: $e");
    }
  }
}