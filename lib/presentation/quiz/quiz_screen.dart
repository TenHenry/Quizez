import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/database_service.dart';
import '../../data/services/profile_service.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_event.dart';
import '../../logic/quiz/quiz_state.dart';
import 'quiz_finished_view.dart';
import 'quiz_lobby_view.dart';
import 'quiz_menu_view.dart';
import 'quiz_question_view.dart';
import 'quiz_reveal_view.dart';

/// Entry point of the Quiz mode: owns the [QuizBloc] and shows the view for the current state
/// (menu, lobby, question, answer, final ranking).
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return BlocProvider(
      create: (_) => QuizBloc(userId: userId, nickname: profile.nickname, database: context.read<DatabaseService>()),
      child: const _QuizFlow(),
    );
  }
}

class _QuizFlow extends StatelessWidget {
  const _QuizFlow();

  Future<bool> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave the game?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You will leave the room and lose your progress in this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<QuizBloc>();

    return BlocConsumer<QuizBloc, QuizState>(
      listener: (context, state) {
        if (state is QuizMenu && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        final inRoom = state is! QuizMenu;

        return PopScope(
          canPop: !inRoom,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmLeave(context)) {
              bloc.add(LeaveRoomRequested());
              navigator.pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Quiz')),
            body: SafeArea(child: _viewFor(state)),
          ),
        );
      },
    );
  }

  Widget _viewFor(QuizState state) {
    if (state is QuizMenu) return const QuizMenuView();
    if (state is QuizConnecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.black),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (state is QuizLobby) return QuizLobbyView(state: state);
    if (state is QuizQuestionActive) return QuizQuestionView(key: ValueKey(state.index), state: state);
    if (state is QuizReveal) return QuizRevealView(state: state);
    if (state is QuizFinished) return QuizFinishedView(state: state);
    return const SizedBox.shrink();
  }
}
