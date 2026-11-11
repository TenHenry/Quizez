import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/data/services/rewards_service.dart';
import 'package:quizez/logic/daily/daily_quiz.dart';
import 'package:quizez/logic/rewards/streak.dart';
import 'package:quizez/presentation/rewards/rewards_card.dart';
import 'package:quizez/presentation/rewards/shop_screen.dart';

const fox = ShopItem(id: 'avatar_fox', kind: ShopItem.kindAvatar, name: 'Fox', price: 50, glyph: '🦊');
const dragon = ShopItem(id: 'avatar_dragon', kind: ShopItem.kindAvatar, name: 'Dragon', price: 300, glyph: '🐲');
const cool = ShopItem(id: 'emote_cool', kind: ShopItem.kindEmote, name: 'Cool', price: 20, glyph: '😎');

RewardsService serviceWith(RewardsSnapshot snapshot) => RewardsService()..snapshot.value = snapshot;

Widget host(RewardsService service, Widget child) => RepositoryProvider.value(
      value: service,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('RewardsCard', () {
    final today = dayKey(DateTime.now());

    testWidgets('shows the streak and coins, and the claim button when the reward is available', (tester) async {
      final service = serviceWith(const RewardsSnapshot(wallet: Wallet(coins: 120), items: [], owned: {}));

      await tester.pumpWidget(host(service, const RewardsCard(streak: StreakInfo(days: 3, activeToday: true))));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('Claim daily reward +25 🪙'), findsOneWidget); // 10 + 3 * 5
    });

    testWidgets('asks for some activity when nothing was answered today', (tester) async {
      final service = serviceWith(const RewardsSnapshot(wallet: Wallet(coins: 0), items: [], owned: {}));

      await tester.pumpWidget(host(service, const RewardsCard(streak: StreakInfo(days: 2, activeToday: false))));

      expect(find.textContaining('Answer a question today'), findsOneWidget);
      expect(find.textContaining('Claim daily reward'), findsNothing);
    });

    testWidgets('says the reward was claimed when it was already collected today', (tester) async {
      final service = serviceWith(RewardsSnapshot(wallet: Wallet(coins: 40, lastClaimDay: today), items: const [], owned: const {}));

      await tester.pumpWidget(host(service, const RewardsCard(streak: StreakInfo(days: 1, activeToday: true))));

      expect(find.textContaining('reward claimed'), findsOneWidget);
      expect(find.textContaining('Claim daily reward'), findsNothing);
    });

    testWidgets('is hidden when the rewards are not available', (tester) async {
      await tester.pumpWidget(host(RewardsService(), const RewardsCard(streak: StreakInfo.none)));

      expect(find.byType(Card), findsNothing);
    });
  });

  group('ShopScreen', () {
    testWidgets('lets the user buy what they can afford and shows what they cannot', (tester) async {
      final service = serviceWith(const RewardsSnapshot(wallet: Wallet(coins: 100), items: [fox, dragon, cool], owned: {}));

      await tester.pumpWidget(RepositoryProvider.value(value: service, child: const MaterialApp(home: ShopScreen())));
      await tester.pump();

      expect(find.text('🪙 100'), findsOneWidget); // balance in the app bar
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '🪙 50')).onPressed, isNotNull);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '🪙 300')).onPressed, isNull);
      expect(find.text('Not enough coins'), findsOneWidget);
    });

    testWidgets('shows Equip for an owned avatar and Equipped for the worn one', (tester) async {
      final service = serviceWith(const RewardsSnapshot(
        wallet: Wallet(coins: 0, equippedAvatar: 'avatar_fox'),
        items: [fox, dragon],
        owned: {'avatar_fox', 'avatar_dragon'},
      ));

      await tester.pumpWidget(RepositoryProvider.value(value: service, child: const MaterialApp(home: ShopScreen())));
      await tester.pump();

      expect(find.text('Equipped'), findsOneWidget);
      expect(find.text('Equip'), findsOneWidget);
    });

    testWidgets('emotes are in their own tab and cannot be equipped', (tester) async {
      final service = serviceWith(const RewardsSnapshot(wallet: Wallet(coins: 0), items: [fox, cool], owned: {'emote_cool'}));

      await tester.pumpWidget(RepositoryProvider.value(value: service, child: const MaterialApp(home: ShopScreen())));
      await tester.pump();
      await tester.tap(find.text('Emotes'));
      await tester.pumpAndSettle();

      expect(find.text('Cool'), findsOneWidget);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Equip'), findsNothing);
    });
  });
}
