import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/answer_log.dart';
import '../../data/services/database_service.dart';
import '../../data/services/sync_service.dart';
import '../../logic/stats/stats_calculator.dart';

/// Statistics: how many answers were given, how well, and which categories are the hardest.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.refresh});

  /// Notifies the screen that it became visible again, so the numbers are reloaded.
  final Listenable refresh;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final DatabaseService _db;
  late final SyncService _sync;

  List<AnswerLog> _logs = [];
  String? _source; // null = all
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _sync = context.read<SyncService>();
    _sync.isSyncing.addListener(_onChanged);
    widget.refresh.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _sync.isSyncing.removeListener(_onChanged);
    widget.refresh.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted && !_sync.isSyncing.value) _load();
  }

  Future<void> _load() async {
    final logs = await _db.getAnswerLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = computeStats(_logs, source: _source);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _sync.syncNow();
          await _load();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(value: AnswerLog.sourceFlashcards, label: Text('Flashcards')),
                ButtonSegment(value: AnswerLog.sourceQuiz, label: Text('Quiz')),
              ],
              selected: {_source},
              onSelectionChanged: (value) => setState(() => _source = value.first),
            ),
            const SizedBox(height: 16),
            if (_loaded && stats.total == 0)
              const _EmptyState()
            else ...[
              _SummaryRow(stats: stats),
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Hardest categories',
                subtitle: 'Share of correct answers (lowest first)',
                child: _CategoryChart(categories: stats.categories.take(6).toList()),
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Activity',
                subtitle: 'Answers per day, last 14 days',
                child: _ActivityChart(days: stats.days),
              ),
              const SizedBox(height: 16),
              _CategoryList(categories: stats.categories),
            ],
          ],
        ),
      ),
    );
  }
}

Color _accuracyColor(double accuracy) {
  if (accuracy < 0.5) return Colors.red;
  if (accuracy < 0.75) return Colors.orange;
  return Colors.green;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text('No answers yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'Study flashcards or play a quiz and your results will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final StatsOverview stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label) => Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        tile('${stats.total}', 'Answers'),
        tile('${stats.accuracyPercent}%', 'Correct'),
        tile('${stats.answersLast7Days}', 'Last 7 days'),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

const _hiddenTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

/// Bars with the accuracy of the hardest categories; the color tells how well it goes.
class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.categories});

  final List<CategoryStats> categories;

  String _short(String name) => name.length <= 8 ? name : '${name.substring(0, 7)}…';

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 25),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final c = categories[group.x];
              return BarTooltipItem(
                '${c.category}\n${c.accuracyPercent}% (${c.correct}/${c.total})',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: _hiddenTitles,
          rightTitles: _hiddenTitles,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 25,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${value.toInt()}%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= categories.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_short(categories[index].category), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < categories.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: categories[i].accuracy * 100,
                  color: _accuracyColor(categories[i].accuracy),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: Colors.grey.shade200),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Answers per day over the last two weeks.
class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});

  final List<DayStats> days;

  @override
  Widget build(BuildContext context) {
    final maxTotal = days.fold<int>(0, (m, d) => max(m, d.total));
    final maxY = max(5, ((maxTotal + 4) ~/ 5) * 5).toDouble(); // round up to a multiple of 5

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 5),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = days[group.x];
              return BarTooltipItem(
                '${d.day.day}.${d.day.month}\n${d.correct}/${d.total} correct',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: _hiddenTitles,
          rightTitles: _hiddenTitles,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${value.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length || index.isOdd) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text('${days[index].day.day}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].total.toDouble(),
                  color: Colors.black,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// All categories with their results, hardest first.
class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<CategoryStats> categories;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('All categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Hardest first', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(c.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${c.accuracyPercent}%  (${c.correct}/${c.total})', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.accuracy,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: _accuracyColor(c.accuracy),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
