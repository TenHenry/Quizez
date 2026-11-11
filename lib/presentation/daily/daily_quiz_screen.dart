import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/daily_quiz_service.dart';
import '../../data/services/database_service.dart';
import '../../data/services/quiz_question_service.dart';
import '../../logic/daily/daily_quiz.dart';
import '../../logic/daily/daily_quiz_cubit.dart';
import 'ranking_screen.dart';

/// The daily quiz: the same questions for everybody, one attempt per day, results go to the ranking.
class DailyQuizScreen extends StatelessWidget {
  const DailyQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DailyQuizCubit(
        service: DailyQuizService(),
        questions: QuizQuestionService(),
        database: context.read<DatabaseService>(),
      )..load(),
      child: const _DailyFlow(),
    );
  }
}

class _DailyFlow extends StatelessWidget {
  const _DailyFlow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyQuizCubit, DailyState>(
      builder: (context, state) {
        final playing = state is DailyQuestion && !(state.revealed && state.index == state.total - 1);

        return PopScope(
          canPop: !playing,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            final leave = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Leave the daily quiz?', style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text('You can play it only once a day, and leaving now means you will not be able to finish it.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay', style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Leave'),
                  ),
                ],
              ),
            );
            if (leave == true) navigator.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Daily quiz'),
              actions: [
                IconButton(
                  tooltip: 'Ranking',
                  icon: const Icon(Icons.emoji_events_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RankingScreen())),
                ),
              ],
            ),
            body: SafeArea(child: _viewFor(context, state)),
          ),
        );
      },
    );
  }

  Widget _viewFor(BuildContext context, DailyState state) {
    if (state is DailyLoading) {
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
    if (state is DailyError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.read<DailyQuizCubit>().load(), child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (state is DailyIntro) return _Intro(state: state);
    if (state is DailyQuestion) return _QuestionView(key: ValueKey(state.index), state: state);
    if (state is DailyFinished) return _Finished(state: state);
    return const SizedBox.shrink();
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.state});

  final DailyIntro state;

  @override
  Widget build(BuildContext context) {
    final result = state.result;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.today, size: 72),
          const SizedBox(height: 16),
          Text(result == null ? 'Today\'s quiz' : 'Done for today!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            result == null
                ? '$dailyQuestionCount questions, $dailySecondsPerQuestion seconds each.\nEveryone gets the same questions - compete for a place in the ranking.\nYou can play once a day (the day changes at midnight UTC).'
                : 'You scored ${result.score} points (${result.correct}/${result.total} correct).\nCome back tomorrow for new questions.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (result == null)
            ElevatedButton.icon(
              onPressed: () => context.read<DailyQuizCubit>().start(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RankingScreen())),
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.black),
            label: const Text('See the ranking', style: TextStyle(fontSize: 16, color: Colors.black)),
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

class _QuestionView extends StatefulWidget {
  const _QuestionView({super.key, required this.state});

  final DailyQuestion state;

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  late final Timer _ticker;
  double _remaining = 1;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final elapsed = DateTime.now().difference(widget.state.receivedAt).inMilliseconds;
      final remaining = (1 - elapsed / (widget.state.seconds * 1000)).clamp(0.0, 1.0);
      if (mounted) setState(() => _remaining = remaining);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Color _optionColor(int i, DailyQuestion state) {
    if (!state.revealed) return Colors.white;
    if (i == state.question.correctIndex) return Colors.green.shade100;
    if (i == state.selected) return Colors.red.shade100;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final question = state.question;
    final low = _remaining < 0.3 && !state.revealed;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${state.index + 1} / ${state.total}', style: const TextStyle(color: Colors.grey)),
              Text('${state.score} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.revealed ? 0 : _remaining,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: low ? Colors.red : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          Text(question.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ElevatedButton(
                onPressed: state.revealed ? null : () => context.read<DailyQuizCubit>().answer(i),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: _optionColor(i, state),
                  disabledForegroundColor: Colors.black87,
                  side: BorderSide(color: state.revealed && i == question.correctIndex ? Colors.green : Colors.black12),
                  padding: const EdgeInsets.all(18),
                ),
                child: Text(question.options[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
          Text(
            state.revealed ? (state.selected == null ? "Time's up!" : (state.selected == question.correctIndex ? 'Correct!' : 'Wrong answer')) : ' ',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: state.selected == question.correctIndex ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});

  final DailyFinished state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
          const SizedBox(height: 8),
          const Text('Daily quiz complete!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${state.score} points', textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          Text('${state.correct} / ${state.total} correct', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          if (state.error != null) ...[
            Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: () => context.read<DailyQuizCubit>().retrySave(), child: const Text('Try saving again')),
          ] else if (!state.saved)
            const Text('Saving your result...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
          else
            const Text('Result saved. See how you compare!', textAlign: TextAlign.center, style: TextStyle(color: Colors.green)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: state.saved ? () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RankingScreen())) : null,
            child: const Text('See the ranking', style: TextStyle(fontSize: 16)),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}
