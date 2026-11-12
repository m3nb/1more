import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engine/engine.dart';
import '../engine/model.dart';
import '../game/controller.dart';
import 'room_link.dart';

const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String newRoomCode() {
  final r = Random.secure();
  return List.generate(5, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
}

String newClientId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(36).toRadixString(36)).join();
}

String normalizeCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class LobbySeat {
  final String name;
  final String type; // human (host), remote, or a persona key
  final String? cid;
  const LobbySeat(this.name, this.type, [this.cid]);

  Map<String, dynamic> toJson() => {'n': name, 't': type, if (cid != null) 'c': cid};
  static LobbySeat fromJson(dynamic j) {
    final m = j as Map;
    return LobbySeat(m['n'] as String, m['t'] as String, m['c'] as String?);
  }
}

/// A room: the lobby before the game, and the game controller after.
class OnlineSession extends ChangeNotifier {
  final bool isHost;
  final String code;
  final String myId;
  final String myName;
  late final RoomLink link;

  List<LobbySeat> seats = [];
  int target = 200;
  bool connected = false;
  String? note;
  String? fatal;
  GameController? controller;
  Timer? _joinRetry;
  bool _closed = false;

  OnlineSession._(this.isHost, this.code, this.myName) : myId = newClientId() {
    link = RoomLink(code, myId);
    link.onMessage = _onMessage;
    link.onStatus = (ok, n) {
      connected = ok;
      note = n;
      _notify();
    };
  }

  static Future<OnlineSession> host(String name) async {
    final s = OnlineSession._(true, newRoomCode(), name);
    s.seats = [LobbySeat(name, 'human', s.myId)];
    await s.link.connect();
    s.connected = true;
    await s._sendLobby();
    return s;
  }

  static Future<OnlineSession> join(String code, String name) async {
    final s = OnlineSession._(false, normalizeCode(code), name);
    await s.link.connect();
    s.connected = true;
    s.note = 'Looking for the host…';
    s._sendJoin();
    return s;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  bool get started => controller != null;
  bool get amInLobby => seats.any((x) => x.cid == myId);

  // ---------------- guest ----------------

  void _sendJoin() {
    var tries = 0;
    link.send('join', {'name': myName});
    _joinRetry?.cancel();
    _joinRetry = Timer.periodic(const Duration(seconds: 3), (t) {
      if (amInLobby || started || _closed) {
        t.cancel();
        return;
      }
      if (++tries > 10) {
        t.cancel();
        fatal = 'No room found with code $code. Check the code and that the host is still in the lobby.';
        _notify();
        return;
      }
      link.send('join', {'name': myName});
    });
  }

  // ---------------- host ----------------

  Future<void> _sendLobby() =>
      link.send('lobby', {'seats': seats.map((s) => s.toJson()).toList(), 'target': target});

  void addCpu(String persona) {
    if (!isHost || started || seats.length >= 8) return;
    final base = kPersonas[persona]?.name ?? 'CPU';
    final taken = seats.map((s) => s.name).toSet();
    var name = base;
    for (var n = 2; taken.contains(name); n++) {
      name = '$base $n';
    }
    seats.add(LobbySeat(name, persona));
    _sendLobby();
    _notify();
  }

  void removeSeat(int i) {
    if (!isHost || started || i == 0 || i >= seats.length) return;
    final s = seats.removeAt(i);
    if (s.cid != null) link.send('kicked', {'cid': s.cid});
    _sendLobby();
    _notify();
  }

  void setTarget(int t) {
    if (!isHost || started) return;
    target = t;
    _sendLobby();
    _notify();
  }

  void startGame() {
    if (!isHost || started || seats.length < 2) return;
    final players = [for (final s in seats) Player(name: s.name, type: s.type, clientId: s.cid)];
    controller = HostController(this, Engine.newGame(players, target));
    (controller as HostController).broadcast();
    _notify();
  }

  void _onMessage(Map<String, dynamic> m) {
    final kind = m['k'];
    final from = m['from'] as String?;
    if (from == null) return;
    if (isHost) {
      switch (kind) {
        case 'join':
          if (started) {
            // Someone who reloaded or reconnected gets their seat back.
            (controller as HostController).rejoin(from, m['name'] as String? ?? '');
            return;
          }
          if (!seats.any((s) => s.cid == from)) {
            if (seats.length >= 8) {
              link.send('full', {'cid': from});
              return;
            }
            var name = (m['name'] as String? ?? 'Friend').trim();
            if (name.isEmpty) name = 'Friend';
            if (name.length > 16) name = name.substring(0, 16);
            seats.add(LobbySeat(name, 'remote', from));
            _notify();
          }
          _sendLobby();
          break;
        case 'leave':
          if (!started) {
            seats.removeWhere((s) => s.cid == from);
            _sendLobby();
            _notify();
          }
          break;
        case 'act':
          if (started) (controller as HostController).remoteAct(from, m);
          break;
        case 'reclaim':
          if (started) (controller as HostController).reclaim(from);
          break;
      }
    } else {
      switch (kind) {
        case 'lobby':
          seats = (m['seats'] as List).map(LobbySeat.fromJson).toList();
          target = (m['target'] as num).toInt();
          note = null;
          _notify();
          break;
        case 'state':
          final st = GameState.fromJson(m['state']);
          if (controller == null) {
            controller = GuestController(this);
            _joinRetry?.cancel();
          }
          (controller as GuestController).receive(st);
          note = null;
          _notify();
          break;
        case 'kicked':
          if (m['cid'] == myId) {
            fatal = 'The host removed you from the room.';
            _notify();
          }
          break;
        case 'full':
          if (m['cid'] == myId) {
            fatal = 'This room is full (8 players).';
            _notify();
          }
          break;
        case 'closed':
          fatal = 'The host closed the room.';
          if (controller is GuestController) (controller as GuestController).hostGone();
          _notify();
          break;
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _joinRetry?.cancel();
    try {
      await link.send(isHost ? 'closed' : 'leave');
    } catch (_) {}
    _closed = true;
    await link.close();
  }
}

/// The host runs the engine and sends the whole state after every change.
class HostController extends EngineController {
  final OnlineSession session;
  HostController(this.session, Engine engine) : super(engine);

  @override
  String? get roomCode => session.code;

  @override
  String? get connectionNote => session.connected ? null : (session.note ?? 'Offline');

  void broadcast() {
    session.link.send('state', {'state': engine.s.toJson(hideDeck: true)});
  }

  @override
  void changed() {
    broadcast();
    super.changed();
  }

  void remoteAct(String from, Map<String, dynamic> m) {
    final player = (m['player'] as num?)?.toInt();
    if (player == null || player < 0 || player >= engine.s.players.length) return;
    final p = engine.s.players[player];
    if (p.type != 'remote' || p.clientId != from) return;
    final ok = engine.apply(player, m['type'] as String? ?? '', target: (m['target'] as num?)?.toInt());
    if (ok) {
      changed();
    } else {
      broadcast(); // resync a confused guest
    }
  }

  @override
  bool get canTakeOverSeats => true;

  /// The computer plays the seat for now. The seat still belongs to its
  /// player (the client id stays), who can take it back at any time.
  @override
  void takeOverSeat(int i) {
    final p = engine.s.players[i];
    if (p.type != 'remote') return;
    engine.setPlayerType(i, 'sage');
    changed();
  }

  int _seatOf(String cid) => engine.s.players.indexWhere((p) => p.clientId == cid);

  void reclaim(String from) {
    final i = _seatOf(from);
    if (i >= 0 && engine.s.players[i].isCpu) {
      engine.setPlayerType(i, 'remote');
      changed();
    } else {
      broadcast();
    }
  }

  /// A device joining mid-game: if it is a player who reloaded (same name,
  /// new id), hand the seat to the new device.
  void rejoin(String from, String name) {
    var i = _seatOf(from);
    if (i < 0) {
      final wanted = name.trim().toLowerCase();
      i = engine.s.players.indexWhere((p) =>
          p.clientId != null && p.clientId != session.myId && p.name.trim().toLowerCase() == wanted);
      if (i >= 0) engine.s.players[i].clientId = from;
    }
    if (i >= 0 && engine.s.players[i].type != 'remote') {
      engine.setPlayerType(i, 'remote');
    }
    changed();
  }

  @override
  void leave() {
    session.close();
  }
}

/// A guest only renders what the host sends and forwards its own moves.
class GuestController extends GameController {
  final OnlineSession session;
  GameState? _state;
  bool _hostGone = false;
  GuestController(this.session);

  void receive(GameState s) {
    if (_state != null && s.version < _state!.version) return;
    _state = s;
    notifyListeners();
  }

  void hostGone() {
    _hostGone = true;
    notifyListeners();
  }

  @override
  GameState? get state => _state;

  @override
  bool canControl(int i) {
    final p = _state?.players[i];
    return p != null && p.type == 'remote' && p.clientId == session.myId && !_hostGone;
  }

  @override
  void act(int player, String type, {int? target}) {
    if (!canControl(player)) return;
    session.link.send('act', {'player': player, 'type': type, if (target != null) 'target': target});
  }

  @override
  bool get canAdvanceRound => false;

  @override
  void nextRound() {}

  @override
  void reclaimSeat() {
    session.link.send('reclaim');
  }

  @override
  String? get roomCode => session.code;

  @override
  String? get connectionNote =>
      _hostGone ? 'The host left the game.' : (session.connected ? null : (session.note ?? 'Offline'));

  @override
  void leave() {
    session.close();
  }
}
