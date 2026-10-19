import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_event.dart';
import '../../logic/quiz/quiz_state.dart';
import 'scoreboard.dart';

/// Final ranking of the game.
class QuizFinishedView extends StatelessWidget {
  const QuizFinishedView({super.key, required this.state});

  final QuizFinished state;

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final winner = state.ranking.firstOrNull;
    final iWon = winner != null && winner.playerId == myId;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
          const SizedBox(height: 8),
          Text(iWon ? 'You won!' : 'Game over', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          if (winner != null && !iWon)
            Text('${winner.nickname} won the game', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(child: Scoreboard(entries: state.ranking, myId: myId)),
          ElevatedButton(
            onPressed: () => context.read<QuizBloc>().add(LeaveRoomRequested()),
            child: const Text('Back to menu', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
