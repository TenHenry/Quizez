import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import 'database_service.dart';

/// Offline-first synchronization between local Isar and Supabase.
///
/// - Local writes are saved immediately and flagged `pendingSync`.
/// - [requestSync] pushes pending records and pulls remote changes (last-write-wins by `updatedAt`).
/// - Sync is triggered after local writes, after login and when the connection comes back.
///   Failed attempts are harmless: the records stay pending and are sent on the next attempt.
class SyncService {
  SyncService(this._local) {
    _local.onLocalChange = requestSync;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) requestSync();
    });
  }

  final DatabaseService _local;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  SupabaseClient get _supabase => Supabase.instance.client;

  bool _running = false;
  bool _rerun = false;

  /// True while a synchronization is in progress (for UI indicators).
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  void dispose() {
    _connectivitySub.cancel();
    isSyncing.dispose();
  }

  /// Fire-and-forget sync request. Safe to call often - overlapping requests are merged.
  void requestSync() {
    unawaited(syncNow());
  }

  /// Runs a synchronization and returns true when it finished without errors.
  Future<bool> syncNow() async {
    if (_local.currentUserId == null) return false;
    if (_running) {
      _rerun = true;
      return true;
    }

    _running = true;
    isSyncing.value = true;
    var success = true;
    try {
      do {
        _rerun = false;
        await _push();
        await _pull();
      } while (_rerun);
    } catch (e) {
      success = false;
      debugPrint('Sync failed: $e');
    } finally {
      _running = false;
      isSyncing.value = false;
    }
    return success;
  }

  // ---------------------------------------------------------------- push

  Future<void> _push() async {
    final userId = _local.currentUserId!;
    final isar = await _local.db;

    // Decks first - flashcards reference them.
    final decks = await isar.decks.filter().pendingSyncEqualTo(true).findAll();
    if (decks.isNotEmpty) {
      await _supabase.from('decks').upsert([
        for (final d in decks)
          {
            'id': d.uuid,
            'user_id': userId,
            'name': d.name,
            'updated_at': d.updatedAt.toIso8601String(),
            'deleted': d.deleted,
          },
      ]);
      await _markDecksSynced(isar, decks);
    }

    final cards = await isar.flashcards.filter().pendingSyncEqualTo(true).findAll();
    if (cards.isNotEmpty) {
      await _supabase.from('flashcards').upsert([
        for (final c in cards)
          {
            'id': c.uuid,
            'user_id': userId,
            'deck_id': c.deckUuid,
            'question': c.question,
            'answer': c.answer,
            'box': c.box,
            'is_difficult': c.isDifficult,
            'updated_at': c.updatedAt.toIso8601String(),
            'deleted': c.deleted,
          },
      ]);
      await _markCardsSynced(isar, cards);
    }
  }

  /// Clears `pendingSync` only for records that were not modified again while the upload was running.
  Future<void> _markDecksSynced(Isar isar, List<Deck> pushed) async {
    final synced = <Deck>[];
    for (final item in pushed) {
      final latest = await isar.decks.getByUuid(item.uuid);
      if (latest != null && latest.updatedAt == item.updatedAt) synced.add(latest..pendingSync = false);
    }
    await isar.writeTxn(() => isar.decks.putAll(synced));
  }

  Future<void> _markCardsSynced(Isar isar, List<Flashcard> pushed) async {
    final synced = <Flashcard>[];
    for (final item in pushed) {
      final latest = await isar.flashcards.getByUuid(item.uuid);
      if (latest != null && latest.updatedAt == item.updatedAt) synced.add(latest..pendingSync = false);
    }
    await isar.writeTxn(() => isar.flashcards.putAll(synced));
  }

  // ---------------------------------------------------------------- pull

  Future<void> _pull() async {
    final userId = _local.currentUserId!;
    final isar = await _local.db;

    final remoteDecks = await _supabase.from('decks').select().eq('user_id', userId);
    final remoteCards = await _supabase.from('flashcards').select().eq('user_id', userId);

    final decksToSave = <Deck>[];
    for (final row in remoteDecks) {
      final local = await isar.decks.getByUuid(row['id'] as String);
      final remoteUpdated = DateTime.parse(row['updated_at'] as String).toUtc();

      if (local == null) {
        if (row['deleted'] == true) continue;
        decksToSave.add(Deck()
          ..uuid = row['id'] as String
          ..name = row['name'] as String
          ..updatedAt = remoteUpdated
          ..deleted = false
          ..pendingSync = false);
      } else if (!local.pendingSync && remoteUpdated.isAfter(local.updatedAt)) {
        decksToSave.add(local
          ..name = row['name'] as String
          ..updatedAt = remoteUpdated
          ..deleted = row['deleted'] == true);
      }
    }

    final cardsToSave = <Flashcard>[];
    for (final row in remoteCards) {
      final local = await isar.flashcards.getByUuid(row['id'] as String);
      final remoteUpdated = DateTime.parse(row['updated_at'] as String).toUtc();

      if (local == null) {
        if (row['deleted'] == true) continue;
        cardsToSave.add(Flashcard()
          ..uuid = row['id'] as String
          ..deckUuid = row['deck_id'] as String
          ..question = row['question'] as String
          ..answer = row['answer'] as String
          ..box = row['box'] as int
          ..isDifficult = row['is_difficult'] == true
          ..updatedAt = remoteUpdated
          ..deleted = false
          ..pendingSync = false);
      } else if (!local.pendingSync && remoteUpdated.isAfter(local.updatedAt)) {
        cardsToSave.add(local
          ..deckUuid = row['deck_id'] as String
          ..question = row['question'] as String
          ..answer = row['answer'] as String
          ..box = row['box'] as int
          ..isDifficult = row['is_difficult'] == true
          ..updatedAt = remoteUpdated
          ..deleted = row['deleted'] == true);
      }
    }

    if (decksToSave.isEmpty && cardsToSave.isEmpty) return;
    await isar.writeTxn(() async {
      await isar.decks.putAll(decksToSave);
      await isar.flashcards.putAll(cardsToSave);
    });
  }
}
