import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/card_import.dart';
import '../../data/models/deck.dart';
import '../../data/models/flashcard.dart';
import '../../data/services/database_service.dart';
import '../../data/services/sync_service.dart';
import '../../logic/learning/learning_bloc.dart';
import '../../logic/learning/learning_event.dart';
import '../learning/flashcards_screen.dart';

/// One deck: its cards (add, edit, delete, mark as difficult, import) and buttons that start a study session.
class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key, required this.deck});

  final Deck deck;

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late final DatabaseService _db;
  late final SyncService _sync;
  List<Flashcard> _cards = [];
  bool _deleted = false;

  Deck get deck => widget.deck;
  DeckStats get _stats => DeckStats.fromCards(_cards);

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _sync = context.read<SyncService>();
    _sync.isSyncing.addListener(_onSyncChanged);
    _loadCards();
  }

  @override
  void dispose() {
    _sync.isSyncing.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (!_sync.isSyncing.value && mounted) _loadCards();
  }

  Future<void> _loadCards() async {
    final cards = await _db.getCards(deck.uuid);
    if (!mounted) return;
    setState(() => _cards = cards);
  }

  // ---------------------------------------------------------------- study

  Future<void> _startSession({bool hardOnly = false}) async {
    context.read<LearningBloc>().add(LoadFlashcardsForToday(deck.uuid, hardOnly: hardOnly));
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FlashcardsScreen(deckUuid: deck.uuid, hardOnly: hardOnly)),
    );
    if (mounted) _loadCards(); // boxes changed during the session
  }

  // ---------------------------------------------------------------- cards

  Future<void> _showCardDialog({Flashcard? card}) async {
    final questionController = TextEditingController(text: card?.question);
    final answerController = TextEditingController(text: card?.answer);
    final editing = card != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(editing ? 'Edit card' : 'Add a card to: ${deck.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: questionController, decoration: const InputDecoration(hintText: 'Question...')),
            const SizedBox(height: 12),
            TextField(controller: answerController, decoration: const InputDecoration(hintText: 'Answer...')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (questionController.text.trim().isNotEmpty && answerController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(editing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    final question = questionController.text;
    final answer = answerController.text;
    if (saved != true) return;

    if (editing) {
      await _db.updateFlashcard(card, question: question, answer: answer);
    } else {
      await _db.addNewFlashcard(question, answer, deck.uuid);
    }
    _loadCards();
  }

  Future<void> _deleteCard(Flashcard card) async {
    final confirmed = await _confirm('Delete this card?', card.question);
    if (!confirmed) return;
    await _db.deleteFlashcard(card);
    _loadCards();
  }

  Future<void> _toggleDifficult(Flashcard card) async {
    await _db.setFlashcardDifficult(card, !card.isDifficult);
    _loadCards();
  }

  // ---------------------------------------------------------------- import

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import cards', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('One card per line:\nquestion;answer', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Capital of France;Paris'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Import')),
        ],
      ),
    );
    if (text == null) return;

    final result = parseCards(text);
    if (result.cards.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('No valid lines found. Use: question;answer'), backgroundColor: Colors.red));
      return;
    }

    final added = await _db.addFlashcards(result.cards, deck.uuid);
    _loadCards();
    messenger.showSnackBar(SnackBar(
      content: Text('Imported $added cards${result.skipped > 0 ? ' (${result.skipped} lines skipped)' : ''}.'),
      backgroundColor: Colors.green,
    ));
  }

  // ---------------------------------------------------------------- deck

  Future<void> _renameDeck() async {
    final name = await showRenameDeckDialog(context, deck.name);
    if (name == null) return;
    await _db.renameDeck(deck, name);
    if (mounted) setState(() {});
  }

  Future<void> _deleteDeck() async {
    final confirmed = await _confirm('Delete deck "${deck.name}"?', 'The deck and all its cards will be removed.');
    if (!confirmed) return;
    await _db.deleteDeck(deck);
    _deleted = true;
    if (mounted) Navigator.pop(context, _deleted);
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(
        title: Text(deck.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _showImportDialog();
                case 'rename':
                  _renameDeck();
                case 'delete':
                  _deleteDeck();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Import cards')),
              PopupMenuItem(value: 'rename', child: Text('Rename deck')),
              PopupMenuItem(value: 'delete', child: Text('Delete deck', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BoxSummary(stats: stats),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: stats.total == 0 ? null : () => _startSession(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start learning'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: stats.difficult == 0 ? null : () => _startSession(hardOnly: true),
                  icon: const Icon(Icons.flag, color: Colors.orange),
                  label: Text('Difficult cards only (${stats.difficult})', style: const TextStyle(color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cards.isEmpty
                ? const Center(child: Text('No cards yet. Tap + to add one!', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) => _CardTile(
                      card: _cards[index],
                      onTap: () => _showCardDialog(card: _cards[index]),
                      onToggleDifficult: () => _toggleDifficult(_cards[index]),
                      onDelete: () => _deleteCard(_cards[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCardDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog asking for a deck name. Returns the trimmed name or null when cancelled.
Future<String?> showRenameDeckDialog(BuildContext context, String currentName) async {
  final controller = TextEditingController(text: currentName);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename deck', style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Deck name')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) Navigator.pop(dialogContext, controller.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return name;
}

class _BoxSummary extends StatelessWidget {
  const _BoxSummary({required this.stats});

  final DeckStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${stats.total} cards', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < stats.perBox.length; i++)
                  Column(
                    children: [
                      Text('${stats.perBox[i]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Box ${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.onTap,
    required this.onToggleDifficult,
    required this.onDelete,
  });

  final Flashcard card;
  final VoidCallback onTap;
  final VoidCallback onToggleDifficult;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        title: Text(card.question, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${card.answer}\nBox ${card.box}', maxLines: 3, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: card.isDifficult ? 'Unmark as difficult' : 'Mark as difficult',
              icon: Icon(card.isDifficult ? Icons.flag : Icons.flag_outlined, color: card.isDifficult ? Colors.orange : Colors.grey),
              onPressed: onToggleDifficult,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
