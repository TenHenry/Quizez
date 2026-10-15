import 'package:isar/isar.dart';

part 'deck.g.dart';

@collection
class Deck {
  Id id = Isar.autoIncrement;
  late String name;
}