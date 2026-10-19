import 'package:flutter/material.dart';
import '../../logic/quiz/quiz_state.dart';

/// Ranked list of players with their scores. The current player is highlighted.
class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key, required this.entries, required this.myId, this.showGained = false});

  final List<RankingEntry> entries;
  final String? myId;

  /// Show "+points" gained in the last round next to the total.
  final bool showGained;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final isMe = entry.playerId == myId;

        return Card(
          color: isMe ? Colors.black : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            dense: true,
            leading: Text(i < _medals.length ? _medals[i] : '${i + 1}.', style: const TextStyle(fontSize: 20)),
            title: Text(
              isMe ? '${entry.nickname} (you)' : entry.nickname,
              style: TextStyle(fontWeight: FontWeight.w600, color: isMe ? Colors.white : Colors.black),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showGained && entry.gained > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('+${entry.gained}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                Text('${entry.score}', style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black)),
              ],
            ),
          ),
        );
      },
    );
  }
}
