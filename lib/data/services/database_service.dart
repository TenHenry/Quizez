import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../logic/learning/leitner.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

/// Summary of one deck shown on the deck list.
class DeckStats {
  final int total;
  final int difficult;
  const DeckStats({required this.total, required this.difficult});
}

/// Local (Isar) storage. Every signed-in user gets a separate database, so accounts never see each other's data.
/// Each write marks the record as `pendingSync` and calls [onLocalChange] - the SyncService then pushes it to Supabase.
class DatabaseService {
  static const _uuid = Uuid();

  /// Set by SyncService, called after every local write.
  void Function()? onLocalChange;

  Future<Isar>? _opening;
  String? _openFor;

  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  /// Isar instance of the currently signed-in user (reopened when the user changes).
  Future<Isar> get db {
    final userId = currentUserId;
    if (userId == null) {
      return Future.error(StateError('No signed-in user'));
    }
    if (_opening != null && _openFor == userId) return _opening!;

    final previous = _opening;
    _openFor = userId;
    return _opening = _open(userId, previous);
  }

  Future<Isar> _open(String userId, Future<Isar>? previous) async {
    if (previous != null) {
      try {
        await (await previous).close();
      } catch (_) {
        // The previous instance was never opened successfully - nothing to close.
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [FlashcardSchema, DeckSchema],
      directory: dir.path,
      name: 'quizez_$userId',
    );
  }

  // ---------------------------------------------------------------- decks

  Future<Deck> createNewDeck(String name) async {
    final isar = await db;
    final deck = Deck()
      ..uuid = _uuid.v4()
      ..name = name.trim()
      ..updatedAt = _now()
      ..pendingSync = true;

    await isar.writeTxn(() => isar.decks.put(deck));
    onLocalChange?.call();
    return deck;
  }

  Future<List<Deck>> getAllDecks() async {
    final isar = await db;
    final decks = await isar.decks.filter().deletedEqualTo(false).findAll();
    decks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return decks;
  }

  Future<void> renameDeck(Deck deck, String name) async {
    final isar = await db;
    deck
      ..name = name.trim()
      ..updatedAt = _now()
      ..pendingSync = true;
    await isar.writeTxn(() => isar.decks.put(deck));
    onLocalChange?.call();
  }

  /// Soft delete: the deck and all its cards are marked as deleted and the deletion is synced.
  Future<void> deleteDeck(Deck deck) async {
    final isar = await db;
    final cards = await isar.flashcards.filter().deckUuidEqualTo(deck.uuid).deletedEqualTo(false).findAll();
    final now = _now();

    deck
      ..deleted = true
      ..updatedAt = now
      ..pendingSync = true;
    for (final card in cards) {
      card
        ..deleted = true
        ..updatedAt = now
        ..pendingSync = true;
    }

    await isar.writeTxn(() async {
      await isar.decks.put(deck);
      await isar.flashcards.putAll(cards);
    });
    onLocalChange?.call();
  }

  Future<DeckStats> getDeckStats(String deckUuid) async {
    final isar = await db;
    final cards = isar.flashcards.filter().deckUuidEqualTo(deckUuid).deletedEqualTo(false);
    final total = await cards.count();
    final difficult = await cards.isDifficultEqualTo(true).count();
    return DeckStats(total: total, difficult: difficult);
  }

  // ---------------------------------------------------------------- flashcards

  Future<List<Flashcard>> getCards(String deckUuid) async {
    final isar = await db;
    final cards = await isar.flashcards.filter().deckUuidEqualTo(deckUuid).deletedEqualTo(false).findAll();
    cards.sort((a, b) => a.question.toLowerCase().compareTo(b.question.toLowerCase()));
    return cards;
  }

  Future<Flashcard> addNewFlashcard(String question, String answer, String deckUuid) async {
    final isar = await db;
    final card = Flashcard()
      ..uuid = _uuid.v4()
      ..question = question.trim()
      ..answer = answer.trim()
      ..deckUuid = deckUuid
      ..updatedAt = _now()
      ..pendingSync = true;

    await isar.writeTxn(() => isar.flashcards.put(card));
    onLocalChange?.call();
    return card;
  }

  /// Adds many cards at once (used by import). Returns the number of cards added.
  Future<int> addFlashcards(List<({String question, String answer})> entries, String deckUuid) async {
    final isar = await db;
    final now = _now();
    final cards = [
      for (final entry in entries)
        Flashcard()
          ..uuid = _uuid.v4()
          ..question = entry.question.trim()
          ..answer = entry.answer.trim()
          ..deckUuid = deckUuid
          ..updatedAt = now
          ..pendingSync = true,
    ];

    await isar.writeTxn(() => isar.flashcards.putAll(cards));
    onLocalChange?.call();
    return cards.length;
  }

  Future<void> updateFlashcard(Flashcard card, {String? question, String? answer}) async {
    if (question != null) card.question = question.trim();
    if (answer != null) card.answer = answer.trim();
    await _saveCard(card);
  }

  Future<void> deleteFlashcard(Flashcard card) async {
    card.deleted = true;
    await _saveCard(card);
  }

  Future<void> setFlashcardDifficult(Flashcard card, bool isDifficult) async {
    card.isDifficult = isDifficult;
    await _saveCard(card);
  }

  // ---------------------------------------------------------------- learning

  /// Cards for one study session (see [selectSessionCards]). With [hardOnly] only cards marked as difficult are used.
  Future<List<Flashcard>> getSessionCards(String deckUuid, {bool hardOnly = false}) async {
    final isar = await db;
    var query = isar.flashcards.filter().deckUuidEqualTo(deckUuid).deletedEqualTo(false);
    final cards = await (hardOnly ? query.isDifficultEqualTo(true) : query).findAll();
    return selectSessionCards(cards);
  }

  Future<void> updateFlashcardProgress(Flashcard card, bool isCorrect) async {
    card.box = nextBox(card.box, isCorrect);
    if (!isCorrect) {
      card.isDifficult = true;
    } else if (card.box == maxBox) {
      card.isDifficult = false; // fully learned
    }
    await _saveCard(card);
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _saveCard(Flashcard card) async {
    final isar = await db;
    card
      ..updatedAt = _now()
      ..pendingSync = true;
    await isar.writeTxn(() => isar.flashcards.put(card));
    onLocalChange?.call();
  }

  DateTime _now() => DateTime.now().toUtc();
}
