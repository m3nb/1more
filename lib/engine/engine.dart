import 'dart:math';

import 'model.dart';

const int kDeckSize = 93;
const List<int> kTargets = [200, 250, 300, 350, 400];

/// 0 once, 1 once, 2 twice ... 12 twelve times (79 cards), one each of
/// +2 +4 +6 +8 +10 and ×2, and two of each action card.
List<GameCard> buildDeck(Random rng) {
  var id = 0;
  final d = <GameCard>[GameCard(++id, CardType.num, 0)];
  for (var v = 1; v <= 12; v++) {
    for (var i = 0; i < v; i++) {
      d.add(GameCard(++id, CardType.num, v));
    }
  }
  for (final v in [2, 4, 6, 8, 10]) {
    d.add(GameCard(++id, CardType.add, v));
  }
  d.add(GameCard(++id, CardType.x2));
  for (final t in [CardType.sc, CardType.flip3, CardType.freeze, CardType.neg]) {
    d.add(GameCard(++id, t));
    d.add(GameCard(++id, t));
  }
  d.shuffle(rng);
  return d;
}

/// The rules, as a state machine. The engine runs until it needs input
/// (state.pending), then waits for [apply]. Only the host runs an Engine;
/// other devices just render the state it broadcasts.
class Engine {
  final GameState s;
  final Random rng;

  Engine(this.s, [Random? rng]) : rng = rng ?? Random();

  static Engine newGame(List<Player> players, int target, {Random? rng}) {
    final r = rng ?? Random();
    final s = GameState(players: players, target: target, deck: buildDeck(r));
    final e = Engine(s, r);
    e.startRound();
    return e;
  }

  int get n => s.players.length;

  void _log(String t) {
    s.log.insert(0, t);
    if (s.log.length > 60) s.log.removeLast();
  }

  String _who(int chooser, int t) => chooser == t ? 'themselves' : s.players[t].name;

  void startRound() {
    for (final p in s.players) {
      p.hand = RoundHand();
    }
    s.results = [];
    s.tie = false;
    s.phase = 'deal';
    s.pos = 0;
    s.flips = [];
    s.advanceAfter = false;
    s.pending = null;
    s.lastCardId = null;
    s.order = List.generate(n, (k) => (s.starter + k) % n);
    _log('— Round ${s.round} —');
    _run();
    s.version++;
  }

  void nextRound() {
    if (s.phase != 'roundEnd') return;
    s.round++;
    s.starter = (s.starter + 1) % n;
    startRound();
  }

  /// Change who controls a seat (e.g. a disconnected friend becomes a CPU).
  void setPlayerType(int i, String type) {
    s.players[i].type = type;
    s.version++;
  }

  GameCard? _drawCard() {
    if (s.deck.isEmpty) {
      if (s.discard.isEmpty) return null;
      s.deck = [...s.discard]..shuffle(rng);
      s.discard = [];
      _log('Deck ran out. Used cards were reshuffled.');
    }
    return s.deck.removeLast();
  }

  /// Returns true when the action was legal and applied.
  bool apply(int player, String type, {int? target}) {
    final d = s.pending;
    if (d == null || d.player != player) return false;
    switch (d.type) {
      case DType.draw:
        if (type != 'draw') return false;
        s.pending = null;
        _draw(player);
        s.advanceAfter = true;
        break;
      case DType.turn:
        if (type == 'stay') {
          s.pending = null;
          s.players[player].hand.status = PStatus.stayed;
          _log('${s.players[player].name} stays on ${scoreOf(s.players[player].hand).value}.');
          s.advanceAfter = true;
        } else if (type == 'draw') {
          s.pending = null;
          _draw(player);
          s.advanceAfter = true;
        } else {
          return false;
        }
        break;
      case DType.target:
        if (type != 'target' || target == null || !d.candidates.contains(target)) return false;
        s.pending = null;
        _resolve(player, d.kind!, target, d.card!);
        break;
    }
    _run();
    s.version++;
    return true;
  }

  void _run() {
    var guard = 0;
    while (guard++ < 2000) {
      if (s.pending != null) return;
      if (s.phase == 'roundEnd' || s.phase == 'gameOver') return;

      // Flip 3 draws happen before the turn moves on.
      if (s.flips.isNotEmpty) {
        final f = s.flips.last;
        if (!s.players[f.target].hand.active || f.remaining <= 0) {
          s.flips.removeLast();
          continue;
        }
        f.remaining--;
        _draw(f.target);
        continue;
      }
      if (s.advanceAfter) {
        s.advanceAfter = false;
        s.pos++;
        continue;
      }
      if (s.phase == 'deal') {
        if (s.pos >= n) {
          s.phase = 'play';
          s.pos = 0;
          continue;
        }
        final i = s.order[s.pos];
        final h = s.players[i].hand;
        if (!h.active || h.drawn > 0) {
          s.pos++;
          continue;
        }
        s.pending = Decision(DType.draw, i);
        return;
      }
      if (s.phase == 'play') {
        if (!s.players.any((p) => p.hand.active)) {
          _endRound();
          return;
        }
        final i = s.order[s.pos % n];
        if (!s.players[i].hand.active) {
          s.pos++;
          continue;
        }
        s.pending = Decision(DType.turn, i);
        return;
      }
    }
  }

  void _draw(int i) {
    final p = s.players[i];
    final h = p.hand;
    final c = _drawCard();
    if (c == null) {
      h.status = PStatus.stayed;
      _log('No cards left. ${p.name} stays.');
      return;
    }
    h.drawn++;
    s.lastCardId = c.id;
    switch (c.t) {
      case CardType.num:
        if (h.nums.any((x) => x.v == c.v)) {
          if (h.sc > 0) {
            h.sc--;
            final k = h.acts.indexWhere((a) => a.t == CardType.sc);
            final scCard = h.acts.removeAt(k);
            s.discard
              ..add(scCard)
              ..add(c);
            _log('${p.name} drew a duplicate ${c.v}. Second Chance saved them.');
          } else {
            h.status = PStatus.bust;
            h.bust = c;
            if (h.neg) {
              _log('${p.name} drew a duplicate ${c.v} with a Negative: ${-scoreOf(h).value} deducted.');
            } else {
              _log('${p.name} drew a duplicate ${c.v}. Busted!');
            }
          }
        } else {
          h.nums.add(c);
          _log('${p.name} drew ${c.v}.');
          if (h.nums.length == 7) _log('${p.name} has seven different numbers: +15!');
        }
        break;
      case CardType.add:
      case CardType.x2:
        h.mods.add(c);
        _log('${p.name} drew ${c.label}.');
        break;
      case CardType.sc:
        _log('${p.name} drew Second Chance.');
        if (h.sc == 0) {
          h.sc = 1;
          h.acts.add(c);
        } else {
          final cands = [
            for (var k = 0; k < n; k++)
              if (k != i && s.players[k].hand.active && s.players[k].hand.sc == 0) k
          ];
          if (cands.isEmpty) {
            s.discard.add(c);
            _log('Nobody can take the extra Second Chance. Discarded.');
          } else {
            _ask(i, 'give', cands, c);
          }
        }
        break;
      case CardType.freeze:
        _log('${p.name} drew Freeze.');
        _ask(i, 'freeze', [for (var k = 0; k < n; k++) if (s.players[k].hand.active) k], c);
        break;
      case CardType.neg:
        _log('${p.name} drew Negative.');
        _ask(i, 'neg', [for (var k = 0; k < n; k++) if (s.players[k].hand.status != PStatus.bust) k], c);
        break;
      case CardType.flip3:
        _log('${p.name} drew Flip 3.');
        _ask(i, 'flip3', [for (var k = 0; k < n; k++) if (s.players[k].hand.active) k], c);
        break;
    }
  }

  void _ask(int chooser, String kind, List<int> cands, GameCard card) {
    if (cands.length == 1) {
      _resolve(chooser, kind, cands.first, card);
    } else {
      s.pending = Decision(DType.target, chooser, kind: kind, candidates: cands, card: card);
    }
  }

  void _resolve(int chooser, String kind, int t, GameCard card) {
    final tp = s.players[t];
    final name = s.players[chooser].name;
    switch (kind) {
      case 'give':
        tp.hand.sc = 1;
        tp.hand.acts.add(card);
        _log('$name gave the extra Second Chance to ${tp.name}.');
        break;
      case 'freeze':
        tp.hand.status = PStatus.frozen;
        tp.hand.acts.add(card);
        _log('$name froze ${_who(chooser, t)}. Locked at ${scoreOf(tp.hand).value}.');
        break;
      case 'neg':
        tp.hand.neg = !tp.hand.neg;
        tp.hand.acts.add(card);
        _log(tp.hand.neg
            ? '$name played Negative on ${_who(chooser, t)}.'
            : '$name played Negative on ${_who(chooser, t)}. Negative × negative = positive.');
        break;
      case 'flip3':
        tp.hand.acts.add(card);
        s.flips.add(FlipTask(t, 3));
        _log('$name made ${_who(chooser, t)} flip 3 cards.');
        break;
    }
  }

  void _endRound() {
    s.results = [];
    for (var i = 0; i < n; i++) {
      final p = s.players[i];
      final sc = scoreOf(p.hand);
      p.total += sc.value;
      s.results.add(RoundResult(i, sc.value, sc.calc, p.hand.status));
      s.discard.addAll(p.hand.allCards);
    }
    _log('Round ${s.round} is over.');
    final maxTotal = s.players.map((p) => p.total).reduce(max);
    final leaders = [for (var i = 0; i < n; i++) if (s.players[i].total == maxTotal) i];
    if (maxTotal >= s.target && leaders.length == 1) {
      s.phase = 'gameOver';
      s.winner = leaders.first;
      _log('${s.players[leaders.first].name} wins with $maxTotal!');
    } else {
      s.phase = 'roundEnd';
      s.tie = maxTotal >= s.target;
    }
  }
}
