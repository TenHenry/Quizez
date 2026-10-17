import '../../data/models/deck.dart';
import '../../data/services/database_service.dart';

/// A deck together with its statistics.
typedef DeckWithStats = ({Deck deck, DeckStats stats});

/// Numbers shown on the Home screen: totals over all decks and the deck worth studying next.
class LearningOverview {
  final int decks;
  final int cards;

  /// Cards that reached the last Leitner box.
  final int mastered;
  final int difficult;

  /// Deck with the most cards that still need work (null when there is nothing to study).
  final DeckWithStats? recommended;

  const LearningOverview({
    required this.decks,
    required this.cards,
    required this.mastered,
    required this.difficult,
    required this.recommended,
  });

  const LearningOverview.empty()
      : decks = 0,
        cards = 0,
        mastered = 0,
        difficult = 0,
        recommended = null;

  /// Cards that are not mastered yet.
  int get inProgress => cards - mastered;

  /// Share of mastered cards (0-100).
  int get masteredPercent => cards == 0 ? 0 : (mastered * 100 / cards).round();

  factory LearningOverview.fromDecks(List<DeckWithStats> decks) {
    var cards = 0;
    var mastered = 0;
    var difficult = 0;
    DeckWithStats? recommended;
    var bestScore = 0;

    for (final entry in decks) {
      final stats = entry.stats;
      cards += stats.total;
      mastered += stats.perBox.last;
      difficult += stats.difficult;

      // Cards in boxes 1-2 are the ones that need repetition the most.
      final score = stats.perBox[0] + stats.perBox[1];
      if (score > bestScore) {
        bestScore = score;
        recommended = entry;
      }
    }

    return LearningOverview(
      decks: decks.length,
      cards: cards,
      mastered: mastered,
      difficult: difficult,
      recommended: recommended,
    );
  }
}
