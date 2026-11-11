/// One multiple-choice question. Questions live in Supabase (ready-made bank) or come from AI generation;
/// they are not stored locally.
class QuizQuestion {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String? category;

  /// 1 = easy, 2 = medium, 3 = hard.
  final int difficulty;

  const QuizQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.category,
    this.difficulty = 2,
  });

  /// Reads a row of the `quiz_questions` table or one item returned by the AI function.
  /// Returns null when the data is not a valid question (so broken items can simply be skipped).
  static QuizQuestion? tryParse(Object? json) {
    if (json is! Map) return null;

    final text = json['question'];
    final rawOptions = json['options'];
    final correct = json['correct_index'];
    if (text is! String || text.trim().isEmpty) return null;
    if (rawOptions is! List || rawOptions.length < 2) return null;
    if (correct is! int || correct < 0 || correct >= rawOptions.length) return null;

    final options = rawOptions.map((o) => o.toString().trim()).toList();
    if (options.any((o) => o.isEmpty) || options.toSet().length != options.length) return null;

    final difficulty = json['difficulty'];
    final category = json['category'];
    return QuizQuestion(
      text: text.trim(),
      options: options,
      correctIndex: correct,
      category: category is String ? category : null,
      difficulty: difficulty is int && difficulty >= 1 && difficulty <= 3 ? difficulty : 2,
    );
  }
}
