import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/rewards_service.dart';

/// Shop: buy avatars, win animations and emotes with coins, and equip avatars and animations.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final RewardsService _rewards;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rewards = context.read<RewardsService>();
    _rewards.refresh();
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RewardsSnapshot?>(
      valueListenable: _rewards.snapshot,
      builder: (context, snapshot, _) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Shop'),
              actions: [
                if (snapshot != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text('🪙 ${snapshot.wallet.coins}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
              bottom: const TabBar(
                labelColor: Colors.black,
                indicatorColor: Colors.black,
                tabs: [Tab(text: 'Avatars'), Tab(text: 'Animations'), Tab(text: 'Emotes')],
              ),
            ),
            body: snapshot == null
                ? _Unavailable(onRetry: _rewards.refresh)
                : TabBarView(
                    children: [
                      _ItemList(snapshot: snapshot, kind: ShopItem.kindAvatar, busy: _busy, onBuy: _buy, onEquip: _equip),
                      _ItemList(snapshot: snapshot, kind: ShopItem.kindAnimation, busy: _busy, onBuy: _buy, onEquip: _equip),
                      _ItemList(snapshot: snapshot, kind: ShopItem.kindEmote, busy: _busy, onBuy: _buy, onEquip: _equip),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _buy(ShopItem item) => _run(() => _rewards.purchase(item.id), 'You bought ${item.name}!');

  void _equip(ShopItem item) => _run(() => _rewards.equip(item.id), '${item.name} equipped.');
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The shop is not available right now.\nCheck your connection and that rewards are set up in Supabase.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.snapshot, required this.kind, required this.busy, required this.onBuy, required this.onEquip});

  final RewardsSnapshot snapshot;
  final String kind;
  final bool busy;
  final void Function(ShopItem) onBuy;
  final void Function(ShopItem) onEquip;

  @override
  Widget build(BuildContext context) {
    final items = snapshot.itemsOfKind(kind);
    if (items.isEmpty) return const Center(child: Text('Nothing here yet.', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final owned = snapshot.owned.contains(item.id);
        final equipped = item.id == snapshot.wallet.equippedAvatar || item.id == snapshot.wallet.equippedAnimation;
        final canAfford = snapshot.wallet.coins >= item.price;

        Widget action;
        if (!owned) {
          action = ElevatedButton(
            onPressed: busy || !canAfford ? null : () => onBuy(item),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            child: Text('🪙 ${item.price}'),
          );
        } else if (kind == ShopItem.kindEmote) {
          action = const Chip(label: Text('Owned'), visualDensity: VisualDensity.compact);
        } else if (equipped) {
          action = const Chip(label: Text('Equipped'), backgroundColor: Color(0xFFC8E6C9), visualDensity: VisualDensity.compact);
        } else {
          action = OutlinedButton(onPressed: busy ? null : () => onEquip(item), child: const Text('Equip', style: TextStyle(color: Colors.black)));
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Text(item.glyph, style: const TextStyle(fontSize: 32)),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: !owned && !canAfford ? const Text('Not enough coins', style: TextStyle(color: Colors.grey, fontSize: 12)) : null,
            trailing: action,
          ),
        );
      },
    );
  }
}
