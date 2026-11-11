import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_question_service.dart';

/// Something that can be bought in the shop.
class ShopItem {
  static const kindAvatar = 'avatar';
  static const kindAnimation = 'animation';
  static const kindEmote = 'emote';

  final String id;
  final String kind;
  final String name;
  final int price;

  /// Emoji that represents the item.
  final String glyph;

  const ShopItem({required this.id, required this.kind, required this.name, required this.price, required this.glyph});

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        kind: json['kind'] as String,
        name: json['name'] as String,
        price: json['price'] as int,
        glyph: json['glyph'] as String,
      );
}

/// Coins and equipped items of the signed-in user.
class Wallet {
  final int coins;

  /// Day (UTC, `yyyy-MM-dd`) of the last claimed daily reward.
  final String? lastClaimDay;
  final String? equippedAvatar;
  final String? equippedAnimation;

  const Wallet({required this.coins, this.lastClaimDay, this.equippedAvatar, this.equippedAnimation});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        coins: json['coins'] as int,
        lastClaimDay: json['last_claim'] as String?,
        equippedAvatar: json['equipped_avatar'] as String?,
        equippedAnimation: json['equipped_animation'] as String?,
      );
}

/// Everything about the user's rewards at one moment.
class RewardsSnapshot {
  final Wallet wallet;
  final List<ShopItem> items;

  /// Ids of the items the user owns.
  final Set<String> owned;

  const RewardsSnapshot({required this.wallet, required this.items, required this.owned});

  ShopItem? _item(String? id) => id == null ? null : items.where((i) => i.id == id).firstOrNull;

  /// Emoji of the equipped avatar (null = none).
  String? get avatarGlyph => _item(wallet.equippedAvatar)?.glyph;

  /// Id of the equipped win animation (null = none).
  String? get animationId => wallet.equippedAnimation;

  /// Emotes the user can send during games.
  List<ShopItem> get ownedEmotes => items.where((i) => i.kind == ShopItem.kindEmote && owned.contains(i.id)).toList();

  List<ShopItem> itemsOfKind(String kind) => items.where((i) => i.kind == kind).toList();
}

/// Coins, daily reward, shop and inventory. All changes go through functions in Supabase
/// (`claim_daily_reward`, `purchase_item`, `equip_item`), so coins cannot be edited from the app.
class RewardsService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Latest data (null until the first successful [refresh]).
  final ValueNotifier<RewardsSnapshot?> snapshot = ValueNotifier(null);

  /// Loads the wallet, the shop and the inventory. Returns false when it failed (e.g. offline or not set up).
  Future<bool> refresh() async {
    try {
      final walletJson = await _client.rpc('get_wallet');
      final itemRows = await _client.from('shop_items').select().order('price');
      final ownedRows = await _client.from('inventory').select('item_id');

      snapshot.value = RewardsSnapshot(
        wallet: Wallet.fromJson(Map<String, dynamic>.from(walletJson as Map)),
        items: [for (final row in itemRows) ShopItem.fromJson(row)],
        owned: {for (final row in ownedRows) row['item_id'] as String},
      );
      return true;
    } catch (e) {
      debugPrint('Rewards unavailable: $e');
      return false;
    }
  }

  /// Claims the daily reward and returns the coins gained.
  Future<int> claimDaily(int streakDays) async {
    final gained = await _call(() async => await _client.rpc('claim_daily_reward', params: {'streak': streakDays}));
    await refresh();
    return (gained as num).toInt();
  }

  Future<void> purchase(String itemId) async {
    await _call(() => _client.rpc('purchase_item', params: {'item': itemId}));
    await refresh();
  }

  Future<void> equip(String itemId) async {
    await _call(() => _client.rpc('equip_item', params: {'item': itemId}));
    await refresh();
  }

  /// Turns errors raised by the database functions into messages for the user.
  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw QuizException(e.message);
    } catch (_) {
      throw const QuizException('Something went wrong. Check your connection and try again.');
    }
  }
}
