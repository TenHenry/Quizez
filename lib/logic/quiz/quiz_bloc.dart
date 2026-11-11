import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/quiz_question.dart';
import '../../data/services/quiz_question_service.dart';
import '../../data/services/quiz_room_service.dart';
import 'quiz_config.dart';
import 'quiz_event.dart';
import 'quiz_game.dart';
import 'quiz_state.dart';

/// Runs a multiplayer quiz room.
///
/// Every device shows the game from the messages it receives. The host's device additionally runs the [QuizGame]:
/// it sends the questions, collects the answers, scores them and sends the results back.
class QuizBloc extends Bloc<QuizEvent, QuizState> {
  QuizBloc({required this.userId, required this.nickname, QuizQuestionService? questionService})
      : _questionService = questionService ?? QuizQuestionService(),
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
  }

  final String userId;
  final String nickname;
  final QuizQuestionService _questionService;

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

  /// Nicknames of everybody who was in the room (kept after a player leaves, for the scoreboard).
  final Map<String, String> _names = {};

  // Details of the question on screen, needed again when the answer is revealed.
  int _questionIndex = 0;
  int _questionTotal = 0;
  String _questionText = '';
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
    final room = QuizRoomService(userId: userId, nickname: nickname);
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
    } else if (current is QuizQuestionActive || current is QuizReveal || current is QuizConnecting) {
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
    await room.send('start', {'total': questions.length});
    _timer = Timer(const Duration(seconds: 3), () => add(AdvanceRequested()));
  }

  // ---------------------------------------------------------------- game (host side)

  Future<void> _onAdvance(AdvanceRequested event, Emitter<QuizState> emit) async {
    final game = _game;
    final room = _room;
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
      'options': question.options,
      'seconds': game.secondsPerQuestion,
    });

    final index = game.index;
    _timer = Timer(Duration(seconds: game.secondsPerQuestion + 2), () => add(RoundTimedOut(index)));
  }

  Future<void> _onRoundTimedOut(RoundTimedOut event, Emitter<QuizState> emit) async {
    if (_game?.index == event.index) await _endRound();
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
    await _closeRoom();
    return super.close();
  }

  // ---------------------------------------------------------------- helpers

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
        ),
    ];
    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }
}
