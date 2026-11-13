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

  /// A player whose seat the computer took over asks for it back.
  void reclaimSeat() {}

  void leave() {}
}

/// Runs an Engine on this device and plays the CPU seats.
class EngineController extends GameController {
  final Engine engine;
  final bool fast;
  final Random _rng = Random();
  Timer? _timer;
  bool _disposed = false;

  EngineController(this.engine, {this.fast = false}) {
    scheduleCpu();
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
    notifyListeners();
    scheduleCpu();
  }

  void scheduleCpu() {
    _timer?.cancel();
    final d = engine.s.pending;
    if (d == null) return;
    final p = engine.s.players[d.player];
    if (!p.isCpu) return;
    _timer = Timer(Duration(milliseconds: fast ? 250 : 800), () {
      if (_disposed || engine.s.pending != d) return;
      final m = decideAi(engine.s, _rng);
      if (engine.apply(d.player, m.type, target: m.target)) changed();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
