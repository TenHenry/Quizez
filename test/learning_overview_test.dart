import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/models/deck.dart';
import 'package:quizez/data/services/database_service.dart';
import 'package:quizez/logic/home/learning_overview.dart';

DeckWithStats entry(String name, List<int> perBox, {int difficult = 0}) => (
      deck: Deck()
        ..uuid = name
        ..name = name,
      stats: DeckStats(total: perBox.fold(0, (a, b) => a + b), difficult: difficult, perBox: perBox),
    );

void main() {
  test('no decks gives an empty overview', () {
    final overview = LearningOverview.fromDecks([]);

    expect(overview.cards, 0);
    expect(overview.recommended, isNull);
    expect(overview.masteredPercent, 0);
  });

  test('sums cards, mastered and difficult cards over all decks', () {
    final overview = LearningOverview.fromDecks([
      entry('a', [2, 0, 0, 0, 3], difficult: 1),
      entry('b', [0, 1, 0, 0, 1], difficult: 2),
    ]);

    expect(overview.decks, 2);
    expect(overview.cards, 7);
    expect(overview.mastered, 4);
    expect(overview.difficult, 3);
    expect(overview.inProgress, 3);
    expect(overview.masteredPercent, 57);
  });

  test('recommends the deck with the most cards in boxes 1-2', () {
    final overview = LearningOverview.fromDecks([
      entry('few', [1, 0, 0, 0, 5]),
      entry('many', [4, 3, 0, 0, 0]),
    ]);

    expect(overview.recommended!.deck.name, 'many');
  });

  test('does not recommend a fully learned deck', () {
    final overview = LearningOverview.fromDecks([entry('done', [0, 0, 0, 0, 6])]);

    expect(overview.recommended, isNull);
  });
}
