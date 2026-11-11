import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/answer_log.dart';
import '../../data/models/quiz_question.dart';
import '../../data/services/database_service.dart';
import '../../data/services/quiz_question_service.dart';
import '../../data/services/quiz_room_service.dart';
import '../closest_match/closest_match_game.dart';
import '../closest_match/closest_match_scorer.dart';
import '../../data/models/game_term.dart';
import 'quiz_config.dart';
import 'quiz_event.dart';
import 'quiz_game.dart';
import 'quiz_state.dart';

/// Runs a multiplayer quiz room.
///
/// Every device shows the game from the messages it receives. The host's device additionally runs the [QuizGame]:
/// it sends the questions, collects the answers, scores them and sends the results back.
class QuizBloc extends Bloc<QuizEvent, QuizState> {
  QuizBloc({
    required this.userId,
    required this.nickname,
    DatabaseService? database,
    QuizQuestionService? questionService,
    ClosestMatchScorer? scorer,
    this.avatar,
  })  : _database = database,
        _scorer = scorer ?? ClosestMatchScorer(),
        _questionService = questionService ?? QuizQuestionService(),
        super(const QuizMenu()) {
    on<CreateRoomRequested>(_onCreateRoom);
    on<JoinRoomRequested>(_onJoinRoom);
    on<StartGameRequested>(_onStartGame);
    on<AnswerSelected>(_onAnswerSelected);
    on<LeaveRoomRequested>(_onLeave);
    on<PlayersUpdated>(_onPlayersUpdated);
    on<MessageReceived>(_onMessage);
    on<RoundTimedOut>(_onRoundTimedOut);
    on<AdvanceRequested>(_onAdvance);
    on<SubmitTextRequested>(_onSubmitText);
    on<SendEmoteRequested>(_onSendEmote);
  }

  final String userId;
  final String nickname;

  /// Emoji of this player's avatar, shown to the others in the room.
  final String? avatar;
  final QuizQuestionService _questionService;
  final ClosestMatchScorer _scorer;

  /// Where answers are logged for the statistics (null = not logged).
  final DatabaseService? _database;

  QuizRoomService? _room;
  StreamSubscription<List<RoomPlayer>>? _playersSub;
  StreamSubscription<RoomMessage>? _messagesSub;

  String _code = '';
  bool _isHost = false;
  QuizConfig? _config;

  /// Host only.
  QuizGame? _game;
  Timer? _timer;
  bool _roundOpen = false;
  ClosestMatchGame? _termGame; // Closest Match mode (host only)

  /// Nicknames of everybody who was in the room (kept after a player leaves, for the scoreboard).
  final Map<String, String> _names = {};
  final Map<String, String> _avatars = {};

  final _emoteController = StreamController<({String nickname, String glyph})>.broadcast();
  DateTime _lastEmoteAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Emotes sent by the players of the room (shown briefly on screen).
  Stream<({String nickname, String glyph})> get emotes => _emoteController.stream;

  // Details of the question on screen, needed again when the answer is revealed.
  int _questionIndex = 0;
  int _questionTotal = 0;
  String _questionText = '';
  String _questionCategory = '';
  List<String> _questionOptions = const [];
  int? _myChoice;

  // ---------------------------------------------------------------- joining

  Future<void> _onCreateRoom(CreateRoomRequested event, Emitter<QuizState> emit) async {
    emit(const QuizConnecting('Creating the room...'));
    _config = event.config;
    _isHost = true;
    _code = QuizRoomService.generateCode();

    final room = _newRoom();
    try {
      await room.join(_code, asHost: true);
    } catch (e) {
      await _closeRoom();
      emit(QuizMenu(error: e.toString()));
      return;
    }

    _listen(room);
    emit(QuizLobby(code: _code, players: room.players, isHost: true));
  }

  Future<void> _onJoinRoom(JoinRoomRequested event, Emitter<QuizState> emit) async {
    final code = event.code.trim().toUpperCase();
    if (code.length != 5) {
      emit(const QuizMenu(error: 'Enter the 5-character room code.'));
      return;
    }

    emit(const QuizConnecting('Joining the room...'));
    _isHost = false;
    _code = code;

    final room = _newRoom();
    try {
      await room.join(code, asHost: false);
      final host = await room.waitForHost();

      if (host == null) {
        await _closeRoom();
        emit(const QuizMenu(error: 'Room not found. Check the code.'));
        return;
      }
      if (host.started) {
        await _closeRoom();
        emit(const QuizMenu(error: 'This game has already started.'));
        return;
      }
      if (room.players.length > QuizRoomService.maxPlayers) {
        await _closeRoom();
        emit(const QuizMenu(error: 'This room is full.'));
        return;
      }
    } catch (e) {
      await _closeRoom();
      emit(QuizMenu(error: e.toString()));
      return;
    }

    _listen(room);
    emit(QuizLobby(code: _code, players: room.players, isHost: false));
  }

  QuizRoomService _newRoom() {
    final room = QuizRoomService(userId: userId, nickname: nickname, avatar: avatar);
    _room = room;
    return room;
  }

  void _listen(QuizRoomService room) {
    _playersSub = room.playersStream.listen((players) => add(PlayersUpdated(players)));
    _messagesSub = room.messages.listen((message) => add(MessageReceived(message)));
    add(PlayersUpdated(room.players)); // presence may have synced before we started listening
  }

  // ---------------------------------------------------------------- lobby

  void _onPlayersUpdated(PlayersUpdated event, Emitter<QuizState> emit) {
    for (final player in event.players) {
      _names[player.id] = player.nickname;
      if (player.avatar != null) _avatars[player.id] = player.avatar!;
    }

    final current = state;
    final hostPresent = event.players.any((p) => p.isHost);

    if (current is QuizLobby) {
      // The host's own presence may be missing for a moment right after the room was created.
      if (!_isHost && event.players.isNotEmpty && !hostPresent) {
        _abort(emit, 'The host closed the room.');
        return;
      }
      emit(QuizLobby(code: current.code, players: event.players, isHost: current.isHost, error: current.error));
    } else if (current is QuizQuestionActive ||
        current is QuizReveal ||
        current is QuizTermActive ||
        current is QuizTermResults ||
        current is QuizConnecting) {
      if (!_isHost && event.players.isNotEmpty && !hostPresent) {
        _abort(emit, 'The host left the game.');
      }
    }
  }

  Future<void> _onStartGame(StartGameRequested event, Emitter<QuizState> emit) async {
    final current = state;
    final room = _room;
    final config = _config;
    if (!_isHost || current is! QuizLobby || room == null || config == null) return;
    if (current.players.length < QuizConfig.minPlayers) return;

    if (config.mode == QuizMode.closestMatch) {
      await _startClosestMatch(emit, current, room, config);
      return;
    }

    emit(const QuizConnecting('Preparing questions...'));

    final List<QuizQuestion> questions;
    try {
      questions = config.source == QuizSource.ai
          ? await _questionService.generateWithAi(topic: config.topic, difficulty: config.difficulty == 0 ? 2 : config.difficulty, count: config.questionCount)
          : await _questionService.fromBank(
              category: config.category,
              difficulty: config.difficulty == 0 ? null : config.difficulty,
              count: config.questionCount,
            );
    } catch (e) {
      emit(QuizLobby(code: current.code, players: current.players, isHost: true, error: e.toString()));
      return;
    }

    await room.markStarted();
    _game = QuizGame(
      questions: questions,
      secondsPerQuestion: config.secondsPerQuestion,
      players: current.players.map((p) => p.id),
    );
    await room.send('start', {'mode': 'quiz', 'total': questions.length});
    _timer = Timer(const Duration(seconds: 3), () => add(AdvanceRequested()));
  }

  // ---------------------------------------------------------------- game (host side)

  Future<void> _onAdvance(AdvanceRequested event, Emitter<QuizState> emit) async {
    final game = _game;
    final room = _room;
    final termGame = _termGame;
    if (_isHost && termGame != null && room != null) {
      await _advanceClosestMatch(termGame, room);
      return;
    }
    if (!_isHost || game == null || room == null) return;

    if (!game.hasNext) {
      await room.send('finished', {'scores': game.scores});
      return;
    }

    final question = game.nextQuestion();
    _roundOpen = true;
    await room.send('question', {
      'index': game.index,
      'total': game.total,
      'text': question.text,
      'category': question.category ?? '',
      'options': question.options,
      'seconds': game.secondsPerQuestion,
    });

    final index = game.index;
    _timer = Timer(Duration(seconds: game.secondsPerQuestion + 2), () => add(RoundTimedOut(index)));
  }

  Future<void> _onRoundTimedOut(RoundTimedOut event, Emitter<QuizState> emit) async {
    if (_game?.index == event.index) await _endRound();
    if (_termGame?.index == event.index) await _endTermRound();
  }

  /// Host: scores the round and tells everybody the correct answer.
  Future<void> _endRound() async {
    final game = _game;
    final room = _room;
    if (game == null || room == null || !_roundOpen) return;

    _roundOpen = false;
    _timer?.cancel();
    final result = game.finishRound();

    await room.send('reveal', {
      'index': game.index,
      'correct': result.correctIndex,
      'gained': result.gained,
      'scores': result.scores,
      'last': !game.hasNext,
    });
    _timer = Timer(const Duration(seconds: 5), () => add(AdvanceRequested()));
  }

  // ---------------------------------------------------------------- messages (every device)

  Future<void> _onMessage(MessageReceived event, Emitter<QuizState> emit) async {
    final data = event.message.data;

    switch (event.message.event) {
      case 'start':
        _myChoice = null;
        emit(const QuizConnecting('Get ready!'));

      case 'question':
        _questionIndex = data['index'] as int;
        _questionTotal = data['total'] as int;
        _questionText = data['text'] as String;
        _questionCategory = data['category'] as String? ?? '';
        _questionOptions = List<String>.from(data['options'] as List);
        _myChoice = null;
        emit(QuizQuestionActive(
          index: _questionIndex,
          total: _questionTotal,
          text: _questionText,
          options: _questionOptions,
          seconds: data['seconds'] as int,
          receivedAt: DateTime.now(),
        ));

      case 'answer':
        final game = _game;
        if (!_isHost || game == null || !_roundOpen) return;
        game.submitAnswer(
          playerId: data['playerId'] as String,
          questionIndex: data['index'] as int,
          choice: data['choice'] as int,
          elapsedMs: data['elapsedMs'] as int,
        );
        final present = _room?.players.map((p) => p.id).toList() ?? const <String>[];
        if (present.isNotEmpty && game.allAnswered(present)) await _endRound();

      case 'reveal':
        final scores = _intMap(data['scores']);
        final gained = _intMap(data['gained']);
        await _logMyAnswer(correctIndex: data['correct'] as int);
        emit(QuizReveal(
          index: data['index'] as int,
          total: _questionTotal,
          text: _questionText,
          options: _questionOptions,
          correctIndex: data['correct'] as int,
          selected: _myChoice,
          ranking: _ranking(scores, gained),
          isLast: data['last'] == true,
        ));

      case 'term':
        emit(QuizTermActive(
          index: data['index'] as int,
          total: data['total'] as int,
          term: data['term'] as String,
          category: data['category'] as String? ?? '',
          seconds: data['seconds'] as int,
          receivedAt: DateTime.now(),
        ));

      case 'text':
        final termGame = _termGame;
        if (!_isHost || termGame == null || !_roundOpen) return;
        termGame.submitText(
          playerId: data['playerId'] as String,
          roundIndex: data['index'] as int,
          text: data['text'] as String,
          elapsedMs: data['elapsedMs'] as int,
        );
        final present = _room?.players.map((p) => p.id).toList() ?? const <String>[];
        if (present.isNotEmpty && termGame.allSubmitted(present)) await _endTermRound();

      case 'results':
        final scores = _intMap(data['scores']);
        final points = <String, int>{};
        final entries = <TermResultEntry>[];
        for (final item in data['entries'] as List) {
          final map = Map<String, dynamic>.from(item as Map);
          final id = map['id'] as String;
          points[id] = (map['points'] as num).toInt();
          entries.add(TermResultEntry(
            playerId: id,
            nickname: _names[id] ?? 'Player',
            text: map['text'] as String,
            closenessPercent: ((map['similarity'] as num).toDouble() * 100).round().clamp(0, 100),
            rank: (map['rank'] as num).toInt(),
            points: points[id]!,
          ));
        }
        emit(QuizTermResults(
          index: data['index'] as int,
          total: data['total'] as int,
          term: data['term'] as String,
          definition: data['definition'] as String,
          entries: entries,
          ranking: _ranking(scores, points),
          isLast: data['last'] == true,
          note: data['note'] as String?,
        ));

      case 'emote':
        final id = data['playerId'] as String? ?? '';
        final glyph = data['glyph'] as String? ?? '';
        if (glyph.isNotEmpty && glyph.runes.length <= 4) {
          _emoteController.add((nickname: _names[id] ?? 'Player', glyph: glyph));
        }

      case 'finished':
        _timer?.cancel();
        emit(QuizFinished(_ranking(_intMap(data['scores']), const {})));
    }
  }

  void _onAnswerSelected(AnswerSelected event, Emitter<QuizState> emit) {
    final current = state;
    if (current is! QuizQuestionActive || current.selected != null) return;

    _myChoice = event.choice;
    emit(current.withSelected(event.choice));
    _room?.send('answer', {
      'playerId': userId,
      'index': current.index,
      'choice': event.choice,
      'elapsedMs': DateTime.now().difference(current.receivedAt).inMilliseconds,
    });
  }

  // ---------------------------------------------------------------- Closest Match

  Future<void> _startClosestMatch(Emitter<QuizState> emit, QuizLobby lobby, QuizRoomService room, QuizConfig config) async {
    emit(const QuizConnecting('Preparing terms...'));

    final List<GameTerm> terms;
    try {
      terms = config.source == QuizSource.ai
          ? await _questionService.generateTermsWithAi(topic: config.topic, difficulty: config.difficulty == 0 ? 2 : config.difficulty, count: config.questionCount)
          : await _questionService.termsFromBank(category: config.category, count: config.questionCount);
    } catch (e) {
      emit(QuizLobby(code: lobby.code, players: lobby.players, isHost: true, error: e.toString()));
      return;
    }

    await room.markStarted();
    _termGame = ClosestMatchGame(
      terms: terms,
      secondsPerRound: config.secondsPerQuestion,
      players: lobby.players.map((p) => p.id),
    );
    await room.send('start', {'mode': 'closest', 'total': terms.length});
    _timer = Timer(const Duration(seconds: 3), () => add(AdvanceRequested()));
  }

  Future<void> _advanceClosestMatch(ClosestMatchGame game, QuizRoomService room) async {
    if (!game.hasNext) {
      await room.send('finished', {'scores': game.scores});
      return;
    }

    final term = game.nextTerm();
    _roundOpen = true;
    await room.send('term', {
      'index': game.index,
      'total': game.total,
      'term': term.term,
      'category': term.category ?? '',
      'seconds': game.secondsPerRound,
    });

    final index = game.index;
    _timer = Timer(Duration(seconds: game.secondsPerRound + 3), () => add(RoundTimedOut(index)));
  }

  /// Host: compares the descriptions with the reference definition, ranks them and tells everybody.
  Future<void> _endTermRound() async {
    final game = _termGame;
    final room = _room;
    if (game == null || room == null || !_roundOpen) return;

    _roundOpen = false;
    _timer?.cancel();

    final texts = game.submittedTexts;
    var similarities = <String, double>{};
    String? note;
    if (texts.isNotEmpty) {
      try {
        final scores = await _scorer.score(reference: game.current.definition, answers: texts);
        similarities = {for (final s in scores) s.playerId: s.similarity};
      } catch (e) {
        note = 'The descriptions could not be compared ($e). Faster answers ranked higher.';
      }
    }

    final result = game.finishRound(similarities);
    await room.send('results', {
      'index': game.index,
      'total': game.total,
      'term': game.current.term,
      'definition': result.definition,
      'entries': [
        for (final r in result.results)
          {'id': r.playerId, 'text': r.text, 'similarity': r.similarity, 'rank': r.rank, 'points': r.points},
      ],
      'scores': result.scores,
      'last': !game.hasNext,
      'note': note,
    });
    _timer = Timer(const Duration(seconds: 10), () => add(AdvanceRequested()));
  }

  void _onSubmitText(SubmitTextRequested event, Emitter<QuizState> emit) {
    final current = state;
    final text = event.text.trim();
    if (current is! QuizTermActive || current.submitted != null || text.isEmpty) return;

    emit(current.withSubmitted(text));
    _room?.send('text', {
      'playerId': userId,
      'index': current.index,
      'text': text,
      'elapsedMs': DateTime.now().difference(current.receivedAt).inMilliseconds,
    });
  }

  // ---------------------------------------------------------------- emotes

  void _onSendEmote(SendEmoteRequested event, Emitter<QuizState> emit) {
    final now = DateTime.now();
    if (_room == null || now.difference(_lastEmoteAt) < const Duration(seconds: 1)) return; // no spamming
    _lastEmoteAt = now;
    _room?.send('emote', {'playerId': userId, 'glyph': event.glyph});
  }

  // ---------------------------------------------------------------- leaving

  Future<void> _onLeave(LeaveRoomRequested event, Emitter<QuizState> emit) async {
    await _closeRoom();
    emit(const QuizMenu());
  }

  void _abort(Emitter<QuizState> emit, String reason) {
    _closeRoom();
    emit(QuizMenu(error: reason));
  }

  Future<void> _closeRoom() async {
    _timer?.cancel();
    _roundOpen = false;
    _game = null;
    _termGame = null;
    await _playersSub?.cancel();
    await _messagesSub?.cancel();
    _playersSub = null;
    _messagesSub = null;
    final room = _room;
    _room = null;
    await room?.dispose();
  }

  @override
  Future<void> close() async {
    await _emoteController.close();
    await _closeRoom();
    return super.close();
  }

  // ---------------------------------------------------------------- helpers

  /// Saves whether this player answered the finished round correctly (no answer counts as a miss).
  Future<void> _logMyAnswer({required int correctIndex}) async {
    final database = _database;
    if (database == null || _questionOptions.isEmpty) return;
    try {
      await database.logAnswer(
        source: AnswerLog.sourceQuiz,
        category: _questionCategory,
        correct: _myChoice == correctIndex,
      );
    } catch (e) {
      debugPrint('Could not log the answer: $e'); // statistics must never break a running game
    }
  }

  Map<String, int> _intMap(Object? raw) {
    if (raw is! Map) return {};
    return {for (final e in raw.entries) e.key.toString(): (e.value as num).toInt()};
  }

  List<RankingEntry> _ranking(Map<String, int> scores, Map<String, int> gained) {
    final entries = [
      for (final e in scores.entries)
        RankingEntry(
          playerId: e.key,
          nickname: _names[e.key] ?? 'Player',
          score: e.value,
          gained: gained[e.key] ?? 0,
          avatar: _avatars[e.key],
        ),
    ];
    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }
}
