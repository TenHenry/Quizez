import 'package:isar/isar.dart';

part 'deck.g.dart';

@collection
class Deck {
  Id id = Isar.autoIncrement;

  /// Globally unique id shared with Supabase (the local [id] is only used by Isar).
  @Index(unique: true, replace: true)
  late String uuid;

  late String name;

  /// Last modification time, used for last-write-wins merging during sync.
  DateTime updatedAt = DateTime.now().toUtc();

  /// Soft delete - the row stays until the deletion is synced.
  bool deleted = false;

  /// True when the local copy has changes that are not yet sent to Supabase.
  @Index()
  bool pendingSync = true;
}
