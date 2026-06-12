import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/deck.dart';
import '../../data/services/database_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    final databaseService = context.read<DatabaseService>();
    final decks = await databaseService.getAllDecks();
    setState(() {
      _decks = decks;
    });
  }

  void _showAddDeckDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stwórz nową talię', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nazwa talii, np. Anatomia, Historia...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await context.read<DatabaseService>().createNewDeck(controller.text);
                Navigator.pop(dialogContext);
                _loadDecks();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Stwórz', style: TextStyle(color: Colors.white)),
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
        title: Text('Dodaj fiszkę do: ${deck.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: questionController, decoration: const InputDecoration(hintText: 'Pytanie...')),
            const SizedBox(height: 12),
            TextField(controller: answerController, decoration: const InputDecoration(hintText: 'Odpowiedź...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anuluj', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (questionController.text.isNotEmpty && answerController.text.isNotEmpty) {
                await context.read<DatabaseService>().addNewFlashcard(
                  questionController.text,
                  answerController.text,
                  deck.id,
                );
                if (mounted) Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Dodaj', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeckOptions(Deck deck) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(deck.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.read<LearningBloc>().add(LoadFlashcardsForToday(deck.id));
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlashcardsScreen()));
              },
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('Rozpocznij naukę', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAddCardDialog(deck);
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Dodaj nową fiszkę', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Twoje Talie', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.black),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pobieranie bazy z chmury...')),
              );

              await context.read<DatabaseService>().syncFromSupabase();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Zsynchronizowano pomyślnie!'), backgroundColor: Colors.green),
                );
              }
            },
          ),
        ],
      ),
      body: _decks.isEmpty
          ? const Center(child: Text('Brak talii. Kliknij +, aby stworzyć nową!', style: TextStyle(color: Colors.grey)))
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
                subtitle: const Text('Kliknij, aby grać lub dodać karty', style: TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeckDialog,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}