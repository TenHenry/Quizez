import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_event.dart';
import '../../logic/quiz/quiz_state.dart';

/// Closest Match: a term and a text box to describe it in your own words before the time is up.
class QuizTermView extends StatefulWidget {
  const QuizTermView({super.key, required this.state});

  final QuizTermActive state;

  @override
  State<QuizTermView> createState() => _QuizTermViewState();
}

class _QuizTermViewState extends State<QuizTermView> {
  final _controller = TextEditingController();
  late final Timer _ticker;
  double _remaining = 1; // 1 = full time, 0 = time is up
  bool _autoSent = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _update());
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _update() {
    final elapsed = DateTime.now().difference(widget.state.receivedAt).inMilliseconds;
    final remaining = (1 - elapsed / (widget.state.seconds * 1000)).clamp(0.0, 1.0);
    if (!mounted) return;
    setState(() => _remaining = remaining);

    // When the time is up, whatever is typed is sent automatically.
    if (remaining <= 0 && !_autoSent && widget.state.submitted == null) {
      _autoSent = true;
      if (_controller.text.trim().isNotEmpty) _send();
    }
  }

  void _send() {
    context.read<QuizBloc>().add(SubmitTextRequested(_controller.text));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final sent = state.submitted != null;
    final timeUp = _remaining <= 0;
    final secondsLeft = (_remaining * state.seconds).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Round ${state.index + 1} / ${state.total}', style: const TextStyle(color: Colors.grey)),
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
          const SizedBox(height: 32),
          const Text('Describe this term in your own words:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(state.term, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          if (state.category.isNotEmpty)
            Text(state.category, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          if (sent)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Your description was sent', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(state.submitted!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Waiting for the others...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else ...[
            TextField(
              controller: _controller,
              enabled: !timeUp,
              minLines: 4,
              maxLines: 6,
              maxLength: 300,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'What is it? Write your own definition...'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: timeUp ? null : _send,
              child: Text(timeUp ? "Time's up!" : 'Send', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
