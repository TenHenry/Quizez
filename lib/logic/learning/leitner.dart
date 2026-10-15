import 'dart:math';

import '../../data/models/flashcard.dart';

/// Number of cards in one study session (thesis, chapter 3.2: S = 20).
const int sessionSize = 20;

/// Target amount of cards taken from each subset: B1 (box 1), B2 (box 2), B3+ (box 3-5).
const int box1Quota = 12;
const int box2Quota = 5;
const int box3PlusQuota = 3;

const int maxBox = 5;

/// Moves a card between Leitner boxes: correct answer promotes it, wrong answer sends it back to box 1.
int nextBox(int box, bool isCorrect) => isCorrect ? min(box + 1, maxBox) : 1;

/// Weighted proportional selection of cards for one session (thesis, chapter 3.2).
///
/// Takes up to [box1Quota] cards from box 1, [box2Quota] from box 2 and [box3PlusQuota] from boxes 3+.
/// Missing places (e.g. when box 1 has fewer than 12 cards) are filled from the remaining cards,
/// lowest boxes first, until [sessionSize] is reached. The final list is shuffled.
List<Flashcard> selectSessionCards(List<Flashcard> allCards, {Random? random, int size = sessionSize}) {
  final rng = random ?? Random();

  List<Flashcard> shuffled(Iterable<Flashcard> cards) => cards.toList()..shuffle(rng);

  final box1 = shuffled(allCards.where((c) => c.box == 1));
  final box2 = shuffled(allCards.where((c) => c.box == 2));
  final box3Plus = shuffled(allCards.where((c) => c.box >= 3));

  final selected = <Flashcard>[
    ...box1.take(box1Quota),
    ...box2.take(box2Quota),
    ...box3Plus.take(box3PlusQuota),
  ];

  if (selected.length < size) {
    final chosen = selected.toSet();
    // Lowest boxes first, random order inside one box.
    final leftovers = <Flashcard>[
      for (var box = 1; box <= maxBox; box++)
        ...shuffled(allCards.where((c) => c.box == box && !chosen.contains(c))),
    ];
    selected.addAll(leftovers.take(size - selected.length));
  }

  return selected..shuffle(rng);
}
