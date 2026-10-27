import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/quiz/quiz_state.dart';
import 'scoreboard.dart';

/// Closest Match: the reference definition, every description with its closeness, and the scoreboard.
class QuizTermResultsView extends StatelessWidget {
  const QuizTermResultsView({super.key, required this.state});

  final QuizTermResults state;

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Round ${state.index + 1} / ${state.total}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(state.term, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('Reference definition', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(state.definition, textAlign: TextAlign.center),
            ],
          ),
        ),
        if (state.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.note!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        if (state.entries.isEmpty)
          const Text('Nobody sent a description this round.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
        else
          for (final entry in state.entries) _EntryCard(entry: entry, isMe: entry.playerId == myId),
        const SizedBox(height: 16),
        const Text('Scoreboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SizedBox(
          height: 64.0 * state.ranking.length,
          child: Scoreboard(entries: state.ranking, myId: myId, showGained: true),
        ),
        const SizedBox(height: 8),
        Text(
          state.isLast ? 'Final results are coming...' : 'Next round in a moment...',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.isMe});

  final TermResultEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final winner = entry.rank == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: winner ? Colors.amber : Colors.transparent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${entry.rank + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(isMe ? '${entry.nickname} (you)' : entry.nickname, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('+${entry.points}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(entry.text),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entry.closenessPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: winner ? Colors.amber : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entry.closenessPercent}% close', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
