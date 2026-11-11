import 'package:flutter/material.dart';
import '../../data/services/daily_quiz_service.dart';
import '../../logic/daily/daily_quiz.dart';
import '../../logic/daily/leaderboard.dart';

/// Ranking of the daily quiz: today and the last 7 days.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

enum _Period { today, week }

class _RankingScreenState extends State<RankingScreen> {
  final _service = DailyQuizService();

  _Period _period = _Period.today;
  List<LeaderboardEntry> _ranking = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final ranking = _period == _Period.today
          ? await _service.dayRanking(dayKey(now))
          : await _service.rankingSince(dayKey(now.subtract(const Duration(days: 6))));
      if (!mounted) return;
      setState(() {
        _ranking = ranking;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final myId = _service.userId;
    final myPlace = placeOf(_ranking, myId);

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.today, label: Text('Today')),
                ButtonSegment(value: _Period.week, label: Text('Last 7 days')),
              ],
              selected: {_period},
              onSelectionChanged: (value) {
                setState(() => _period = value.first);
                _load();
              },
            ),
          ),
          if (myPlace != null)
            Text('Your place: $myPlace / ${_ranking.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: _body(myId)),
        ],
      ),
    );
  }

  Widget _body(String myId) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.black));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_ranking.isEmpty) {
      return const Center(child: Text('Nobody has played yet. Be the first!', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ranking.length,
        itemBuilder: (context, i) {
          final entry = _ranking[i];
          final isMe = entry.userId == myId;

          return Card(
            color: isMe ? Colors.black : Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Text(i < _medals.length ? _medals[i] : '${i + 1}.', style: TextStyle(fontSize: 20, color: isMe ? Colors.white : Colors.black)),
              title: Text(
                isMe ? '${entry.nickname} (you)' : entry.nickname,
                style: TextStyle(fontWeight: FontWeight.w600, color: isMe ? Colors.white : Colors.black),
              ),
              subtitle: Text('${entry.correct}/${entry.total} correct', style: TextStyle(color: isMe ? Colors.white70 : Colors.grey)),
              trailing: Text('${entry.score}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isMe ? Colors.white : Colors.black)),
            ),
          );
        },
      ),
    );
  }
}
