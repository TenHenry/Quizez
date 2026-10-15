import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/deck.dart';
import '../../data/services/database_service.dart';
import '../../data/services/sync_service.dart';
import '../../logic/learning/learning_bloc.dart';
import '../../logic/learning/learning_event.dart';
import '../learning/flashcards_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  List<Deck> _decks = [];
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = context.read<SyncService>();
    _loadDecks();
    // Reload the list whenever a background synchronization finishes (e.g. data pulled after sign-in).
    _syncService.isSyncing.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    _syncService.isSyncing.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (!_syncService.isSyncing.value && mounted) _loadDecks();
  }

  Future<void> _loadDecks() async {
    final databaseService = context.read<DatabaseService>();
    final decks = await databaseService.getAllDecks();
    if (!mounted) return;
    setState(() {
      _decks = decks;
    });
  }

  void _showAddDeckDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a new deck', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Deck name, e.g. Anatomy, History...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final navigator = Navigator.of(dialogContext);
                final service = context.read<DatabaseService>();
                await service.createNewDeck(controller.text);
                navigator.pop();
                _loadDecks();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog(Deck deck) {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add a card to: ${deck.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: questionController, decoration: const InputDecoration(hintText: 'Question...')),
            const SizedBox(height: 12),
            TextField(controller: answerController, decoration: const InputDecoration(hintText: 'Answer...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (questionController.text.trim().isNotEmpty && answerController.text.trim().isNotEmpty) {
                final navigator = Navigator.of(dialogContext);
                await context.read<DatabaseService>().addNewFlashcard(
                      questionController.text,
                      answerController.text,
                      deck.uuid,
                    );
                navigator.pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeckOptions(Deck deck) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(deck.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.read<LearningBloc>().add(LoadFlashcardsForToday(deck.uuid));
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlashcardsScreen()));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start learning'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _showAddCardDialog(deck);
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Add a new card', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], elevation: 0),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final syncService = context.read<SyncService>();
    messenger.showSnackBar(const SnackBar(content: Text('Synchronizing...')));

    final ok = await syncService.syncNow();
    await _loadDecks();

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Synchronized successfully!' : 'Synchronization failed. Changes will be sent when you are online.'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your decks'),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _syncNow),
        ],
      ),
      body: _decks.isEmpty
          ? const Center(child: Text('No decks yet. Tap + to create one!', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showDeckOptions(deck),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      leading: const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.folder, color: Colors.white)),
                      title: Text(deck.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Tap to study or add cards', style: TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeckDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
