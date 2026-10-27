import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/services/rewards_service.dart';

const fox = ShopItem(id: 'avatar_fox', kind: ShopItem.kindAvatar, name: 'Fox', price: 50, glyph: '🦊');
const confetti = ShopItem(id: 'anim_confetti', kind: ShopItem.kindAnimation, name: 'Confetti', price: 150, glyph: '🎉');
const cool = ShopItem(id: 'emote_cool', kind: ShopItem.kindEmote, name: 'Cool', price: 20, glyph: '😎');
const fire = ShopItem(id: 'emote_fire', kind: ShopItem.kindEmote, name: 'Fire', price: 20, glyph: '🔥');

void main() {
  test('Wallet.fromJson reads the database row', () {
    final wallet = Wallet.fromJson({
      'coins': 120,
      'last_claim': '2026-10-28',
      'equipped_avatar': 'avatar_fox',
      'equipped_animation': null,
    });

    expect(wallet.coins, 120);
    expect(wallet.lastClaimDay, '2026-10-28');
    expect(wallet.equippedAvatar, 'avatar_fox');
    expect(wallet.equippedAnimation, isNull);
  });

  test('avatarGlyph and animationId follow the equipped items', () {
    final snapshot = RewardsSnapshot(
      wallet: const Wallet(coins: 10, equippedAvatar: 'avatar_fox', equippedAnimation: 'anim_confetti'),
      items: const [fox, confetti, cool],
      owned: const {'avatar_fox', 'anim_confetti'},
    );

    expect(snapshot.avatarGlyph, '🦊');
    expect(snapshot.animationId, 'anim_confetti');
  });

  test('no equipped avatar gives no glyph', () {
    final snapshot = RewardsSnapshot(wallet: const Wallet(coins: 0), items: const [fox], owned: const {});

    expect(snapshot.avatarGlyph, isNull);
    expect(snapshot.animationId, isNull);
  });

  test('ownedEmotes lists only the emotes the user bought', () {
    final snapshot = RewardsSnapshot(
      wallet: const Wallet(coins: 0),
      items: const [fox, cool, fire],
      owned: const {'avatar_fox', 'emote_fire'},
    );

    expect(snapshot.ownedEmotes.map((e) => e.glyph), ['🔥']);
  });

  test('itemsOfKind filters the shop', () {
    final snapshot = RewardsSnapshot(wallet: const Wallet(coins: 0), items: const [fox, confetti, cool, fire], owned: const {});

    expect(snapshot.itemsOfKind(ShopItem.kindEmote).length, 2);
    expect(snapshot.itemsOfKind(ShopItem.kindAvatar).single.id, 'avatar_fox');
  });
}
