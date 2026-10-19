import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/quiz/quiz_state.dart';
import 'scoreboard.dart';

/// Shows the correct answer, the points gained in the round and the current scoreboard.
class QuizRevealView extends StatelessWidget {
  const QuizRevealView({super.key, required this.state});

  final QuizReveal state;

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final mine = state.ranking.where((r) => r.playerId == myId).firstOrNull;
    final wasCorrect = state.selected == state.correctIndex;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Question ${state.index + 1} / ${state.total}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(state.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (var i = 0; i < state.options.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: i == state.correctIndex
                    ? Colors.green.shade100
                    : (i == state.selected ? Colors.red.shade100 : Colors.white),
                border: Border.all(color: i == state.correctIndex ? Colors.green : Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(state.options[i], textAlign: TextAlign.center),
            ),
          const SizedBox(height: 8),
          Text(
            state.selected == null
                ? 'No answer - 0 points'
                : (wasCorrect ? 'Correct! +${mine?.gained ?? 0} points' : 'Wrong answer - 0 points'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: wasCorrect ? Colors.green : Colors.red),
          ),
          const SizedBox(height: 16),
          Expanded(child: Scoreboard(entries: state.ranking, myId: myId, showGained: true)),
          Text(
            state.isLast ? 'Final results are coming...' : 'Next question in a moment...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
