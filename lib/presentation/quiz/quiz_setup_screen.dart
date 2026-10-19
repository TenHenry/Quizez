import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/quiz_question_service.dart';
import '../../logic/quiz/quiz_bloc.dart';
import '../../logic/quiz/quiz_config.dart';
import '../../logic/quiz/quiz_event.dart';

/// The host chooses where the questions come from, the difficulty, the number of questions and the time per question.
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final _topicController = TextEditingController();

  QuizSource _source = QuizSource.bank;
  String? _category; // null = any
  int _difficulty = 0;
  int _questionCount = 10;
  int _seconds = 15;

  List<String> _categories = [];
  String? _categoriesError;
  String? _topicError;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await QuizQuestionService().getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesError = null;
      });
    } on QuizException catch (e) {
      if (!mounted) return;
      setState(() => _categoriesError = e.message);
    }
  }

  void _create() {
    if (_source == QuizSource.ai && _topicController.text.trim().length < 3) {
      setState(() => _topicError = 'Describe the topic (at least 3 characters)');
      return;
    }

    context.read<QuizBloc>().add(CreateRoomRequested(QuizConfig(
          source: _source,
          category: _category,
          topic: _topicController.text.trim(),
          difficulty: _source == QuizSource.ai && _difficulty == 0 ? 2 : _difficulty,
          questionCount: _questionCount,
          secondsPerQuestion: _seconds,
        )));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New room')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _Label('Questions from'),
          SegmentedButton<QuizSource>(
            segments: const [
              ButtonSegment(value: QuizSource.bank, label: Text('Question bank'), icon: Icon(Icons.library_books)),
              ButtonSegment(value: QuizSource.ai, label: Text('AI generated'), icon: Icon(Icons.auto_awesome)),
            ],
            selected: {_source},
            onSelectionChanged: (value) => setState(() => _source = value.first),
          ),
          const SizedBox(height: 24),
          if (_source == QuizSource.bank) ..._bankOptions() else ..._aiOptions(),
          const SizedBox(height: 24),
          const _Label('Difficulty'),
          Wrap(
            spacing: 8,
            children: [
              if (_source == QuizSource.bank) _choice('Any', 0, _difficulty, (v) => setState(() => _difficulty = v)),
              _choice('Easy', 1, _difficulty, (v) => setState(() => _difficulty = v)),
              _choice('Medium', 2, _difficulty, (v) => setState(() => _difficulty = v)),
              _choice('Hard', 3, _difficulty, (v) => setState(() => _difficulty = v)),
            ],
          ),
          const SizedBox(height: 24),
          const _Label('Number of questions'),
          Wrap(
            spacing: 8,
            children: [
              for (final n in QuizConfig.questionCounts) _choice('$n', n, _questionCount, (v) => setState(() => _questionCount = v)),
            ],
          ),
          const SizedBox(height: 24),
          const _Label('Time per question'),
          Wrap(
            spacing: 8,
            children: [
              for (final s in QuizConfig.secondsOptions) _choice('$s s', s, _seconds, (v) => setState(() => _seconds = v)),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _create, child: const Text('Create room', style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  List<Widget> _bankOptions() {
    return [
      const _Label('Category'),
      if (_categoriesError != null) ...[
        Text(_categoriesError!, style: const TextStyle(color: Colors.red)),
        TextButton(onPressed: _loadCategories, child: const Text('Try again')),
      ] else
        DropdownButtonFormField<String?>(
          initialValue: _category,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Any category')),
            for (final category in _categories) DropdownMenuItem<String?>(value: category, child: Text(category)),
          ],
          onChanged: (value) => setState(() => _category = value),
        ),
    ];
  }

  List<Widget> _aiOptions() {
    return [
      const _Label('Topic'),
      TextField(
        controller: _topicController,
        onChanged: (_) {
          if (_topicError != null) setState(() => _topicError = null);
        },
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: 'e.g. Human anatomy, World War II, Dart language',
          errorText: _topicError,
        ),
      ),
    ];
  }

  Widget _choice(String label, int value, int selected, ValueChanged<int> onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
      selectedColor: Colors.black,
      labelStyle: TextStyle(color: selected == value ? Colors.white : Colors.black),
      showCheckmark: false,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
