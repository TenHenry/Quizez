import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/core/card_import.dart';

void main() {
  test('parses question;answer lines', () {
    final result = parseCards('Capital of France;Paris\nCapital of Spain;Madrid');

    expect(result.cards.length, 2);
    expect(result.cards.first.question, 'Capital of France');
    expect(result.cards.first.answer, 'Paris');
    expect(result.skipped, 0);
  });

  test('supports tabs and Windows line endings', () {
    final result = parseCards('a\tb\r\nc\td');

    expect(result.cards.length, 2);
  });

  test('splits only at the first separator', () {
    final result = parseCards('Q;answer; with semicolon');

    expect(result.cards.single.answer, 'answer; with semicolon');
  });

  test('skips lines without separator or with empty parts and ignores blank lines', () {
    final result = parseCards('no separator\n;empty question\nempty answer;\n\n  \nok;fine');

    expect(result.cards.length, 1);
    expect(result.skipped, 3);
  });
}
