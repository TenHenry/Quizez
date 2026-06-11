import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/flashcard.dart';
import '../../logic/learning/learning_bloc.dart';
import '../../logic/learning/learning_event.dart';
import '../../logic/learning/learning_state.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool isFlipped = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Flashcard Game', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<LearningBloc, LearningState>(
        builder: (context, state) {
          if (state is LearningLoading || state is LearningInitial) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          else if (state is LearningError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          }
          else if (state is LearningFinished) {
            return _buildFinishedScreen(context);
          }
          else if (state is LearningLoaded) {
            final currentCard = state.flashcards.first;
            return _buildFlashcard(context, currentCard);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // Fishcard
  Widget _buildFlashcard(BuildContext context, Flashcard card) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          GestureDetector(
            onTap: () => setState(() => isFlipped = true),
            child: Container(
              height: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pudełko: ${card.box}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Text(
                    card.question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (isFlipped) ...[
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(
                      card.answer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, color: Colors.blueGrey),
                    ),
                  ] else ...[
                    const Text('(Naciśnij, aby odkryć)', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          if (isFlipped)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() => isFlipped = false);
                    context.read<LearningBloc>().add(AnswerFlashcard(card, false));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                  child: const Text('Nie znam', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => isFlipped = false);
                    context.read<LearningBloc>().add(AnswerFlashcard(card, true));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                  child: const Text('Znam', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildFinishedScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('Koniec na dziś!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Wszystkie fiszki zostały powtórzone.', style: TextStyle(color: Colors.grey)),

          ElevatedButton(
            onPressed: () => context.read<LearningBloc>().add(ResetDemo()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            child: const Text('Zresetuj bazę (Demo)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}