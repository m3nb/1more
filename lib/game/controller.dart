import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engine/ai.dart';
import '../engine/engine.dart';
import '../engine/model.dart';

/// What the game screen talks to. Local games, online hosts and online
/// guests each implement it.
abstract class GameController extends ChangeNotifier {
  GameState? get state;

  /// Can this device make the pending decision for seat [i]?
  bool canControl(int i);

  void act(int player, String type, {int? target});

  /// Whether this device may start the next round.
  bool get canAdvanceRound;
  void nextRound();

  /// Online only: the room code and a connection note.
  String? get roomCode => null;
  String? get connectionNote => null;

  /// Host only: hand a stuck remote seat to the computer.
  bool get canTakeOverSeats => false;
  void takeOverSeat(int i) {}

  /// Whether this device may start a new game at the same table.
  bool get canRestart => false;
  void restart() {}

  /// Online host only: take everyone back to the room to change players or settings.
  bool get canReturnToRoom => false;
  void returnToRoom() {}

  /// A player whose seat the computer took over asks for it back.
  void reclaimSeat() {}

  /// Quick reactions shown over a player's seat (online games).
  bool get canEmote => false;
  String? emoteFor(Player p) => null;
  void sendEmote(String e) {}

  /// Seconds left for the current decision, when a turn timer is running.
  int? get secondsLeft => null;

  /// Redraw without a state change (an emote arrived, say).
  void poke() => notifyListeners();

  void leave() {}
}

/// Runs an Engine on this device and plays the CPU seats.
class EngineController extends GameController {
  final Engine engine;
  final bool fast;

  /// 0 = no turn timer. Otherwise a player who waits this long is moved on:
  /// a forced first card is drawn, a turn becomes Stay.
  final int turnSeconds;
  Timer? _turnTimer;
  Decision? _turnFor;
  DateTime? _deadline;
  final Random _rng = Random();
  Timer? _timer;
  bool _disposed = false;
  int _lastEvent = 0;
  int? _lastCard;

  EngineController(this.engine, {this.fast = false, this.turnSeconds = 0}) {
    scheduleTurn();
    scheduleCpu();
  }

  @override
  int? get secondsLeft {
    final d = _deadline;
    if (d == null) return null;
    final ms = d.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  int? get millisLeft {
    final d = _deadline;
    if (d == null) return null;
    return max(0, d.difference(DateTime.now()).inMilliseconds);
  }

  /// Starts the clock when a new decision is waiting on a person.
  void scheduleTurn() {
    final d = engine.s.pending;
    if (identical(d, _turnFor)) return;
    _turnFor = d;
    _turnTimer?.cancel();
    _deadline = null;
    if (turnSeconds <= 0 || d == null) return;
    if (engine.s.players[d.player].isCpu) return;
    _deadline = DateTime.now().add(Duration(seconds: turnSeconds));
    _turnTimer = Timer(Duration(seconds: turnSeconds), () {
      if (_disposed || !identical(engine.s.pending, d)) return;
      final name = engine.s.players[d.player].name;
      var type = 'stay';
      int? target;
      if (d.type == DType.draw) {
        type = 'draw';
      } else if (d.type == DType.target) {
        type = 'target';
        target = decideAi(engine.s, _rng).target;
      }
      if (engine.apply(d.player, type, target: target)) {
        engine.s.log.insert(0, '$name ran out of time.');
        changed();
      }
    });
  }

  @override
  GameState get state => engine.s;

  @override
  bool canControl(int i) => engine.s.players[i].type == 'human';

  @override
  void act(int player, String type, {int? target}) {
    if (!canControl(player)) return;
    if (engine.apply(player, type, target: target)) changed();
  }

  @override
  bool get canAdvanceRound => true;

  @override
  void nextRound() {
    engine.nextRound();
    changed();
  }

  @override
  bool get canRestart => true;

  @override
  void restart() {
    engine.newMatch();
    changed();
  }

  /// Called after every state change.
  @mustCallSuper
  void changed() {
    if (_disposed) return;
    scheduleTurn();
    notifyListeners();
    scheduleCpu();
  }

  void scheduleCpu() {
    _timer?.cancel();
    final d = engine.s.pending;
    if (d == null) return;
    final p = engine.s.players[d.player];
    if (!p.isCpu) return;
    // Leave room for the on-screen moment (bust, save, action card, ×2).
    var pause = 0;
    final s = engine.s;
    if (s.evId != _lastEvent) {
      _lastEvent = s.evId;
      pause = s.evType == 'saved' ? 2600 : 1400;
    }
    if (s.lastCardId != _lastCard) {
      _lastCard = s.lastCardId;
      final special = s.players.any((q) =>
          q.hand.acts.any((c) => c.id == _lastCard) ||
          q.hand.mods.any((c) => c.id == _lastCard && c.t == CardType.x2));
      if (special && pause == 0) pause = 1500;
    }
    if (fast) pause = pause ~/ 3;
    _timer = Timer(Duration(milliseconds: (fast ? 250 : 900) + pause), () {
      if (_disposed || engine.s.pending != d) return;
      final m = decideAi(engine.s, _rng);
      if (engine.apply(d.player, m.type, target: m.target)) changed();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _turnTimer?.cancel();
    super.dispose();
  }
}
