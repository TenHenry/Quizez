import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/deck.dart';
import '../../data/services/database_service.dart';
import '../../data/services/sync_service.dart';
import 'deck_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  late final DatabaseService _db;
  late final SyncService _syncService;
  List<Deck> _decks = [];
  Map<String, DeckStats> _stats = {};

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
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
    final decks = await _db.getAllDecks();
    final stats = {for (final deck in decks) deck.uuid: await _db.getDeckStats(deck.uuid)};
    if (!mounted) return;
    setState(() {
      _decks = decks;
      _stats = stats;
    });
  }

  Future<void> _showAddDeckDialog() async {
    // Controllers of dialogs are intentionally not disposed manually: the dialog is still animating out
    // when showDialog completes, and disposing earlier causes "used after being disposed" errors.
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a new deck', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Deck name, e.g. Anatomy, History...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            // Closes the dialog right away; the (slower) save happens afterwards, so a second tap cannot pop another route.
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null) return;

    await _db.createNewDeck(name);
    _loadDecks();
  }

  Future<void> _openDeck(Deck deck) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeckScreen(deck: deck)));
    if (mounted) _loadDecks();
  }

  Future<void> _renameDeck(Deck deck) async {
    final name = await showRenameDeckDialog(context, deck.name);
    if (name == null) return;
    await _db.renameDeck(deck, name);
    _loadDecks();
  }

  Future<void> _deleteDeck(Deck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete deck "${deck.name}"?', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('The deck and all its cards will be removed.'),
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
    if (confirmed != true) return;
    await _db.deleteDeck(deck);
    _loadDecks();
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Synchronizing...')));

    final ok = await _syncService.syncNow();
    await _loadDecks();

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Synchronized successfully!' : 'Synchronization failed. Changes will be sent when you are online.'),
        backgroundColor: ok ? Colors.green : Colors.orange,
      ),
    );
  }

  String _subtitle(Deck deck) {
    final stats = _stats[deck.uuid];
    if (stats == null) return '';
    final cards = '${stats.total} ${stats.total == 1 ? 'card' : 'cards'}';
    return stats.difficult > 0 ? '$cards · ${stats.difficult} difficult' : cards;
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
                    onTap: () => _openDeck(deck),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 20, right: 8, top: 12, bottom: 12),
                      leading: const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.folder, color: Colors.white)),
                      title: Text(deck.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text(_subtitle(deck), style: const TextStyle(color: Colors.grey)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => value == 'rename' ? _renameDeck(deck) : _deleteDeck(deck),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
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
