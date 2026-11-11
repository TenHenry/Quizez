import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_question_service.dart';

/// A player present in a room.
class RoomPlayer {
  final String id;
  final String nickname;
  final bool isHost;

  /// Only meaningful for the host: the game already started, so nobody new can join.
  final bool started;

  /// Emoji of the avatar bought in the shop (null = none).
  final String? avatar;

  const RoomPlayer({required this.id, required this.nickname, required this.isHost, this.started = false, this.avatar});
}

/// A game message sent through the room channel.
class RoomMessage {
  final String event;
  final Map<String, dynamic> data;
  const RoomMessage(this.event, this.data);
}

/// One quiz room = one Supabase Realtime channel.
/// Presence tells who is in the room, Broadcast carries the game messages. The host's device runs the game.
class QuizRoomService {
  QuizRoomService({required this.userId, required this.nickname, this.avatar});

  static const maxPlayers = 8;

  /// Game messages that are passed on through [messages].
  static const events = ['start', 'question', 'answer', 'reveal', 'term', 'text', 'results', 'emote', 'finished'];

  final String userId;
  final String nickname;
  final String? avatar;

  RealtimeChannel? _channel;
  List<RoomPlayer> _players = [];
  bool _isHost = false;
  bool _started = false;

  final _playersController = StreamController<List<RoomPlayer>>.broadcast();
  final _messagesController = StreamController<RoomMessage>.broadcast();

  List<RoomPlayer> get players => _players;
  Stream<List<RoomPlayer>> get playersStream => _playersController.stream;
  Stream<RoomMessage> get messages => _messagesController.stream;

  /// Short code without characters that are easy to mix up (0/O, 1/I).
  static String generateCode([Random? random]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = random ?? Random.secure();
    return List.generate(5, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
  }

  /// Connects to the room and announces this player. Completes when the player is in.
  Future<void> join(String code, {required bool asHost}) async {
    _isHost = asHost;
    _started = false;

    final channel = Supabase.instance.client.channel(
      'quiz-${code.toUpperCase()}',
      opts: RealtimeChannelConfig(self: true, key: userId),
    );
    _channel = channel;

    channel.onPresenceSync((_) => _syncPlayers());
    for (final event in events) {
      channel.onBroadcast(
        event: event,
        callback: (payload) => _messagesController.add(RoomMessage(event, _unwrap(payload))),
      );
    }

    final connected = Completer<void>();
    channel.subscribe((status, error) async {
      if (connected.isCompleted) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await _track();
          connected.complete();
        } catch (_) {
          connected.completeError(const QuizException('Could not join the room.'));
        }
      } else {
        connected.completeError(const QuizException('Could not connect to the room. Check your connection.'));
      }
    });

    await connected.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const QuizException('Connecting to the room timed out.'),
    );
  }

  /// Waits until the room state is known and returns the host, or null when nobody hosts this code.
  Future<RoomPlayer?> waitForHost() async {
    for (var i = 0; i < 12; i++) {
      final host = _players.where((p) => p.isHost).firstOrNull;
      if (host != null) return host;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  /// Host only: marks the game as started, so late joiners are turned away.
  Future<void> markStarted() async {
    _started = true;
    await _track();
  }

  Future<void> send(String event, Map<String, dynamic> payload) async {
    await _channel?.sendBroadcastMessage(event: event, payload: payload);
  }

  Future<void> leave() async {
    final channel = _channel;
    _channel = null;
    _players = [];
    if (channel == null) return;
    try {
      await channel.untrack();
      await Supabase.instance.client.removeChannel(channel);
    } catch (_) {
      // Leaving is best effort - the server drops the presence when the connection closes anyway.
    }
  }

  Future<void> dispose() async {
    await leave();
    await _playersController.close();
    await _messagesController.close();
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _track() async {
    await _channel?.track({'id': userId, 'nickname': nickname, 'host': _isHost, 'started': _started, 'avatar': avatar});
  }

  void _syncPlayers() {
    final channel = _channel;
    if (channel == null) return;

    final players = <RoomPlayer>[];
    for (final state in channel.presenceState()) {
      if (state.presences.isEmpty) continue;
      final payload = state.presences.last.payload;
      players.add(RoomPlayer(
        id: payload['id'] as String? ?? state.key,
        nickname: payload['nickname'] as String? ?? 'Player',
        isHost: payload['host'] == true,
        started: payload['started'] == true,
        avatar: payload['avatar'] as String?,
      ));
    }
    players.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      return a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase());
    });

    _players = players;
    if (!_playersController.isClosed) _playersController.add(players);
  }

  /// Depending on the library version the callback gets either the message or an envelope around it.
  Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    final inner = raw['payload'];
    if (raw.containsKey('event') && inner is Map) return Map<String, dynamic>.from(inner);
    return raw;
  }
}
