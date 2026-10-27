/// A term with its reference definition, used by the "Closest Match" mode:
/// players describe the term in their own words and the closest description to [definition] wins the round.
class GameTerm {
  final String term;
  final String definition;
  final String? category;

  const GameTerm({required this.term, required this.definition, this.category});

  /// Reads a row of the `closest_terms` table or one item returned by the AI function.
  /// Returns null when the data is not usable.
  static GameTerm? tryParse(Object? json) {
    if (json is! Map) return null;

    final term = json['term'];
    final definition = json['definition'];
    if (term is! String || term.trim().isEmpty) return null;
    if (definition is! String || definition.trim().length < 10) return null;

    final category = json['category'];
    return GameTerm(
      term: term.trim(),
      definition: definition.trim(),
      category: category is String && category.trim().isNotEmpty ? category.trim() : null,
    );
  }
}
