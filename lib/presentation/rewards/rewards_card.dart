import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/rewards_service.dart';
import '../../logic/daily/daily_quiz.dart';
import '../../logic/rewards/streak.dart';
import 'shop_screen.dart';

/// Home card: streak, coins, the daily reward and a way to the shop.
class RewardsCard extends StatefulWidget {
  const RewardsCard({super.key, required this.streak});

  final StreakInfo streak;

  @override
  State<RewardsCard> createState() => _RewardsCardState();
}

class _RewardsCardState extends State<RewardsCard> {
  bool _claiming = false;

  Future<void> _claim(RewardsService rewards) async {
    if (_claiming) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _claiming = true);
    try {
      final gained = await rewards.claimDaily(widget.streak.days);
      messenger.showSnackBar(SnackBar(content: Text('You got $gained coins!'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = context.read<RewardsService>();

    return ValueListenableBuilder<RewardsSnapshot?>(
      valueListenable: rewards.snapshot,
      builder: (context, snapshot, _) {
        if (snapshot == null) return const SizedBox.shrink(); // rewards are not set up or offline

        final streak = widget.streak;
        final canClaim = canClaimDailyReward(streak: streak, lastClaimDay: snapshot.wallet.lastClaimDay);
        final reward = dailyRewardCoins(streak.days);
        final claimedToday = snapshot.wallet.lastClaimDay == dayKey(DateTime.now());

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _Stat(emoji: '🔥', value: '${streak.days}', label: 'day streak')),
                    Expanded(child: _Stat(emoji: '🪙', value: '${snapshot.wallet.coins}', label: 'coins')),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
                      icon: const Icon(Icons.storefront_outlined, color: Colors.black),
                      label: const Text('Shop', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (canClaim)
                  ElevatedButton(
                    onPressed: _claiming ? null : () => _claim(rewards),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                    child: Text('Claim daily reward +$reward 🪙'),
                  )
                else
                  Text(
                    claimedToday
                        ? 'Today\'s reward claimed. Come back tomorrow!'
                        : 'Answer a question today to unlock your reward (+$reward 🪙).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
