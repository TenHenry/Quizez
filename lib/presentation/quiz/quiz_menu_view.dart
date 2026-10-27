import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_config.dart';
import '../../logic/quiz/quiz_event.dart';
import 'quiz_setup_screen.dart';

/// Start of the Quiz mode: create a room or join one with a code.
class QuizMenuView extends StatelessWidget {
  const QuizMenuView({super.key, this.initialMode = QuizMode.multipleChoice});

  final QuizMode initialMode;

  void _createRoom(BuildContext context) {
    final bloc = context.read<QuizBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BlocProvider.value(value: bloc, child: QuizSetupScreen(initialMode: initialMode))),
    );
  }

  Future<void> _joinRoom(BuildContext context) async {
    final bloc = context.read<QuizBloc>();
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join a room', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 5,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: 'CODE', counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Join')),
        ],
      ),
    );

    if (code != null) bloc.add(JoinRoomRequested(code));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(initialMode == QuizMode.closestMatch ? Icons.track_changes : Icons.quiz, size: 72),
          const SizedBox(height: 16),
          const Text('Play with friends', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            initialMode == QuizMode.closestMatch
                ? 'Create a room and share its code, or join a friend\'s room.\nDescribe terms in your own words - the closest to the real definition wins.'
                : 'Create a room and share its code, or join a friend\'s room.\nThe faster you answer correctly, the more points you get.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _createRoom(context),
            icon: const Icon(Icons.add),
            label: const Text('Create a room', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _joinRoom(context),
            icon: const Icon(Icons.login, color: Colors.black),
            label: const Text('Join a room', style: TextStyle(fontSize: 16, color: Colors.black)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
