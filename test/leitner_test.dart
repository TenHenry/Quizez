import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/models/flashcard.dart';
import 'package:quizez/logic/learning/leitner.dart';

Flashcard card(int box, int index) => Flashcard()
  ..uuid = 'c$box-$index'
  ..question = 'q$index'
  ..answer = 'a$index'
  ..deckUuid = 'deck'
  ..box = box;

List<Flashcard> cards({int b1 = 0, int b2 = 0, int b3 = 0}) => [
      for (var i = 0; i < b1; i++) card(1, i),
      for (var i = 0; i < b2; i++) card(2, i),
      for (var i = 0; i < b3; i++) card(3, i),
    ];

int inBox(List<Flashcard> list, bool Function(int) test) => list.where((c) => test(c.box)).length;

void main() {
  group('nextBox', () {
    test('correct answer promotes the card', () {
      expect(nextBox(1, true), 2);
      expect(nextBox(4, true), 5);
    });

    test('correct answer never exceeds the last box', () {
      expect(nextBox(5, true), 5);
    });

    test('wrong answer sends the card back to box 1', () {
      expect(nextBox(5, false), 1);
      expect(nextBox(2, false), 1);
    });
  });

  group('selectSessionCards', () {
    test('uses the 12/5/3 quotas when every box is full', () {
      final session = selectSessionCards(cards(b1: 30, b2: 30, b3: 30), random: Random(1));

      expect(session.length, 20);
      expect(inBox(session, (b) => b == 1), 12);
      expect(inBox(session, (b) => b == 2), 5);
      expect(inBox(session, (b) => b >= 3), 3);
    });

    test('fills missing box 1 places from the other boxes', () {
      final session = selectSessionCards(cards(b1: 4, b2: 30, b3: 30), random: Random(1));

      expect(session.length, 20);
      expect(inBox(session, (b) => b == 1), 4);
    });

    test('returns every card when the deck has fewer than 20', () {
      final all = cards(b1: 3, b2: 2);
      final session = selectSessionCards(all, random: Random(1));

      expect(session.length, 5);
      expect(session.toSet(), all.toSet());
    });

    test('never returns the same card twice', () {
      final session = selectSessionCards(cards(b1: 5, b2: 30, b3: 30), random: Random(7));

      expect(session.toSet().length, session.length);
    });

    test('returns an empty list for an empty deck', () {
      expect(selectSessionCards([]), isEmpty);
    });
  });
}
