typedef CardEntry = ({String question, String answer});

class ImportResult {
  final List<CardEntry> cards;

  /// Lines that could not be used (no separator or an empty question/answer).
  final int skipped;

  const ImportResult(this.cards, this.skipped);
}

/// Parses pasted text into flashcards: one card per line, `question;answer` or `question<TAB>answer`.
/// Only the first separator splits the line, so answers may contain semicolons.
ImportResult parseCards(String text) {
  final cards = <CardEntry>[];
  var skipped = 0;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final tab = line.indexOf('\t');
    final separator = tab != -1 ? tab : line.indexOf(';');
    if (separator == -1) {
      skipped++;
      continue;
    }

    final question = line.substring(0, separator).trim();
    final answer = line.substring(separator + 1).trim();
    if (question.isEmpty || answer.isEmpty) {
      skipped++;
    } else {
      cards.add((question: question, answer: answer));
    }
  }

  return ImportResult(cards, skipped);
}
