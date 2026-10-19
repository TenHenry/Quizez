import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_event.dart';
import '../../logic/quiz/quiz_state.dart';

/// A question with four options and a countdown.
class QuizQuestionView extends StatefulWidget {
  const QuizQuestionView({super.key, required this.state});

  final QuizQuestionActive state;

  @override
  State<QuizQuestionView> createState() => _QuizQuestionViewState();
}

class _QuizQuestionViewState extends State<QuizQuestionView> {
  late final Timer _ticker;
  double _remaining = 1; // 1 = full time, 0 = time is up

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _update());
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _update() {
    final elapsed = DateTime.now().difference(widget.state.receivedAt).inMilliseconds;
    final remaining = (1 - elapsed / (widget.state.seconds * 1000)).clamp(0.0, 1.0);
    if (mounted) setState(() => _remaining = remaining);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final answered = state.selected != null;
    final timeUp = _remaining <= 0;
    final secondsLeft = (_remaining * state.seconds).ceil();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${state.index + 1} / ${state.total}', style: const TextStyle(color: Colors.grey)),
              Text('${secondsLeft}s', style: TextStyle(fontWeight: FontWeight.bold, color: _remaining < 0.3 ? Colors.red : Colors.black)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _remaining,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: _remaining < 0.3 ? Colors.red : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          Text(state.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: state.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final selected = state.selected == i;
                return ElevatedButton(
                  onPressed: answered || timeUp ? null : () => context.read<QuizBloc>().add(AnswerSelected(i)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected ? Colors.black : Colors.white,
                    foregroundColor: selected ? Colors.white : Colors.black,
                    disabledBackgroundColor: selected ? Colors.black : Colors.grey.shade200,
                    disabledForegroundColor: selected ? Colors.white : Colors.grey,
                    side: const BorderSide(color: Colors.black12),
                    padding: const EdgeInsets.all(18),
                  ),
                  child: Text(state.options[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                );
              },
            ),
          ),
          Text(
            answered ? 'Answer locked in. Waiting for the others...' : (timeUp ? "Time's up!" : ' '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
