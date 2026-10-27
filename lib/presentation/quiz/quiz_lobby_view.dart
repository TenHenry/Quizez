import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_config.dart';
import '../../logic/quiz/quiz_event.dart';
import '../../logic/quiz/quiz_state.dart';

/// Waiting room: room code, list of players and (for the host) the start button.
class QuizLobbyView extends StatelessWidget {
  const QuizLobbyView({super.key, required this.state});

  final QuizLobby state;

  @override
  Widget build(BuildContext context) {
    final canStart = state.isHost && state.players.length >= QuizConfig.minPlayers;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Room code', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: state.code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: Text(
              state.code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 8),
            ),
          ),
          const Text('Tap the code to copy it', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          Text('Players (${state.players.length}/8)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final player in state.players)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: player.avatar == null ? Colors.black : Colors.grey.shade200,
                        child: Text(
                          player.avatar ?? (player.nickname.isEmpty ? '?' : player.nickname[0].toUpperCase()),
                          style: TextStyle(color: Colors.white, fontSize: player.avatar == null ? 16 : 22),
                        ),
                      ),
                      title: Text(player.nickname),
                      trailing: player.isHost ? const Chip(label: Text('Host'), visualDensity: VisualDensity.compact) : null,
                    ),
                  ),
              ],
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            ),
          if (state.isHost)
            ElevatedButton(
              onPressed: canStart ? () => context.read<QuizBloc>().add(StartGameRequested()) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Start game', style: TextStyle(fontSize: 16)),
            )
          else
            const Text('Waiting for the host to start...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
