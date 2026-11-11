import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/database_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/rewards_service.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_config.dart';
import '../../logic/quiz/quiz_event.dart';
import '../../logic/quiz/quiz_state.dart';
import 'quiz_finished_view.dart';
import 'quiz_lobby_view.dart';
import 'quiz_menu_view.dart';
import 'quiz_question_view.dart';
import 'quiz_term_results_view.dart';
import 'quiz_term_view.dart';
import 'quiz_reveal_view.dart';

/// Entry point of the multiplayer modes (Quiz and Closest Match): owns the [QuizBloc] and shows the view
/// for the current state (menu, lobby, question or term, answer, final ranking).
/// [initialMode] is the game type preselected when the host creates a room.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key, this.initialMode = QuizMode.multipleChoice});

  final QuizMode initialMode;

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return BlocProvider(
      create: (_) => QuizBloc(
        userId: userId,
        nickname: profile.nickname,
        database: context.read<DatabaseService>(),
        avatar: context.read<RewardsService>().snapshot.value?.avatarGlyph,
      ),
      child: _QuizFlow(initialMode: initialMode),
    );
  }
}

class _QuizFlow extends StatelessWidget {
  const _QuizFlow({required this.initialMode});

  final QuizMode initialMode;

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
            appBar: AppBar(title: Text(initialMode == QuizMode.closestMatch ? 'Closest Match' : 'Quiz')),
            body: SafeArea(
              child: Stack(
                children: [
                  _viewFor(state),
                  if (inRoom) _EmoteOverlay(emotes: bloc.emotes),
                ],
              ),
            ),
            floatingActionButton: inRoom && state is! QuizFinished ? const _EmoteButton() : null,
          ),
        );
      },
    );
  }

  Widget _viewFor(QuizState state) {
    if (state is QuizMenu) return QuizMenuView(initialMode: initialMode);
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
    if (state is QuizTermActive) return QuizTermView(key: ValueKey(state.index), state: state);
    if (state is QuizTermResults) return QuizTermResultsView(state: state);
    if (state is QuizFinished) return QuizFinishedView(state: state);
    return const SizedBox.shrink();
  }
}

/// Button that opens the list of the emotes the player owns; a tap sends one to the room.
class _EmoteButton extends StatelessWidget {
  const _EmoteButton();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<QuizBloc>();

    return FloatingActionButton.small(
      heroTag: 'emotes',
      backgroundColor: Colors.white,
      onPressed: () {
        final emotes = context.read<RewardsService>().snapshot.value?.ownedEmotes ?? const [];

        showModalBottomSheet(
          context: context,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.all(24),
            child: emotes.isEmpty
                ? const Text(
                    'You have no emotes yet. Buy some in the shop (Settings -> Shop) and use them in games.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final emote in emotes)
                        InkWell(
                          onTap: () {
                            bloc.add(SendEmoteRequested(emote.glyph));
                            Navigator.pop(sheetContext);
                          },
                          child: Padding(padding: const EdgeInsets.all(8), child: Text(emote.glyph, style: const TextStyle(fontSize: 36))),
                        ),
                    ],
                  ),
          ),
        );
      },
      child: const Icon(Icons.emoji_emotions_outlined, color: Colors.black),
    );
  }
}

/// Shows the emotes sent by the players for a couple of seconds.
class _EmoteOverlay extends StatefulWidget {
  const _EmoteOverlay({required this.emotes});

  final Stream<({String nickname, String glyph})> emotes;

  @override
  State<_EmoteOverlay> createState() => _EmoteOverlayState();
}

class _EmoteOverlayState extends State<_EmoteOverlay> {
  final _visible = <({int id, String nickname, String glyph})>[];
  int _nextId = 0;
  StreamSubscription<({String nickname, String glyph})>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.emotes.listen((emote) {
      final item = (id: _nextId++, nickname: emote.nickname, glyph: emote.glyph);
      setState(() => _visible.add(item));
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _visible.removeWhere((e) => e.id == item.id));
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final emote in _visible)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                child: Text('${emote.nickname} ${emote.glyph}', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}
