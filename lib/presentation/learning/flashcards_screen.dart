import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/flashcard.dart';
import '../../logic/learning/learning_bloc.dart';
import '../../logic/learning/learning_event.dart';
import '../../logic/learning/learning_state.dart';

/// Study session: the card flips on tap, then the player rates it with "Know" / "Don't know".
/// [deckUuid] and [hardOnly] are only used by the "Study again" button of the summary.
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, required this.deckUuid, this.hardOnly = false});

  final String deckUuid;
  final bool hardOnly;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  bool get _isFlipped => _flip.value > 0.5 || _flip.status == AnimationStatus.forward;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_flip.isAnimating || _flip.value == 1) return;
    _flip.forward();
  }

  void _answer(Flashcard card, bool isCorrect) {
    _flip.value = 0; // next card starts face up
    context.read<LearningBloc>().add(AnswerCardEvent(card, isCorrect));
  }

  void _studyAgain() {
    _flip.value = 0;
    context.read<LearningBloc>().add(LoadFlashcardsForToday(widget.deckUuid, hardOnly: widget.hardOnly));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.hardOnly ? 'Difficult cards' : 'Flashcard Game')),
      body: BlocBuilder<LearningBloc, LearningState>(
        builder: (context, state) {
          if (state is LearningLoading || state is LearningInitial) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          } else if (state is LearningError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          } else if (state is LearningFinished) {
            return _buildFinishedScreen(context, state);
          } else if (state is LearningLoaded) {
            return _buildSession(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ---------------------------------------------------------------- session

  Widget _buildSession(BuildContext context, LearningLoaded state) {
    final card = state.flashcards.first;
    final answered = state.total - state.flashcards.length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${answered + 1} / ${state.total}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: answered / state.total,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Box: ${card.box}', style: const TextStyle(color: Colors.grey)),
              TextButton.icon(
                onPressed: () => context.read<LearningBloc>().add(ToggleDifficultEvent(card)),
                icon: Icon(card.isDifficult ? Icons.flag : Icons.flag_outlined, color: card.isDifficult ? Colors.orange : Colors.grey),
                label: Text(card.isDifficult ? 'Difficult' : 'Mark as difficult', style: TextStyle(color: card.isDifficult ? Colors.orange : Colors.grey)),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: GestureDetector(onTap: _reveal, child: _buildFlipCard(card)),
            ),
          ),
          SizedBox(
            height: 64,
            child: AnimatedBuilder(
              animation: _flip,
              builder: (context, _) => _isFlipped
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _answer(card, false),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text("Don't know", style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _answer(card, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Know', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// Card that rotates around the vertical axis; the answer side is drawn after the half-turn.
  Widget _buildFlipCard(Flashcard card) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final angle = _flip.value * pi;
        final showBack = angle > pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Transform(
            alignment: Alignment.center,
            // The back side is mirrored by the rotation, so it is flipped back to stay readable.
            transform: Matrix4.rotationY(showBack ? pi : 0),
            child: Container(
              width: double.infinity,
              height: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: showBack
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(card.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            const Divider(height: 32),
                            Text(card.answer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(card.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            const Text('(Tap to reveal)', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- summary

  Widget _buildFinishedScreen(BuildContext context, LearningFinished state) {
    if (state.total == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.hardOnly ? 'No difficult cards in this deck.' : 'This deck has no cards yet.',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to deck', style: TextStyle(color: Colors.black))),
            ],
          ),
        ),
      );
    }

    final percent = (state.correct * 100 / state.total).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Session complete!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$percent% known', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              children: [
                _ScoreBox(label: 'Know', value: state.correct, color: Colors.green),
                const SizedBox(width: 16),
                _ScoreBox(label: "Don't know", value: state.incorrect, color: Colors.red),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _studyAgain, child: const Text('Study again', style: TextStyle(fontSize: 16))),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to deck', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
