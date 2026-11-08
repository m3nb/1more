import 'dart:math';

import 'model.dart';

class AiMove {
  final String type; // draw | stay | target
  final int? target;
  const AiMove(this.type, [this.target]);
}

/// Cards the next draw can come from. Everything else is face up, so this
/// is information any careful player has.
List<GameCard> drawPool(GameState s) => s.deck.isNotEmpty ? s.deck : s.discard;

double dupChance(GameState s, int i) {
  final pool = drawPool(s);
  if (pool.isEmpty) return 0;
  final h = s.players[i].hand;
  final dups = pool.where((c) => c.isNumber && h.nums.any((x) => x.v == c.v)).length;
  return dups / pool.length;
}

int valueOf(GameState s, int i) => scoreOf(s.players[i].hand).value;

int _withCard(RoundHand h, GameCard c) {
  final copy = RoundHand(
    nums: [...h.nums],
    mods: [...h.mods],
    acts: h.acts,
    sc: h.sc,
    neg: h.neg,
    status: h.status,
    drawn: h.drawn,
  );
  if (c.isNumber) {
    copy.nums.add(c);
  } else {
    copy.mods.add(c);
  }
  return scoreOf(copy).value;
}

double _expectedGain(GameState s, int i) {
  final h = s.players[i].hand;
  final v = scoreOf(h).value;
  final pool = drawPool(s);
  if (pool.isEmpty) return -1;
  var total = 0.0;
  for (final c in pool) {
    if (c.isNumber) {
      if (h.nums.any((x) => x.v == c.v)) {
        // With a Negative a bust keeps the (negative) score, so it costs nothing extra.
        total += h.sc > 0 ? -4 : (h.neg ? 0 : -v);
      } else {
        total += _withCard(h, c) - v;
      }
    } else if (c.isModifier) {
      total += _withCard(h, c) - v;
    } else {
      total += 1.5;
    }
  }
  return total / pool.length;
}

bool _wantsToDraw(GameState s, int i) {
  final p = s.players[i];
  final h = p.hand;
  final v = valueOf(s, i);
  if (h.drawn == 0) return true;

  var othersBest = 0;
  for (var k = 0; k < s.players.length; k++) {
    if (k == i) continue;
    othersBest = max(othersBest, s.players[k].total + max(0, valueOf(s, k)));
  }
  if (p.type != 'easy' && v > 0 && p.total + v >= s.target && p.total + v > othersBest) return false;

  switch (p.type) {
    case 'easy':
      if (h.neg) return false;
      if (h.sc > 0) return v < 40;
      return v < 14 + Random().nextInt(16);
    case 'medium':
      if (h.neg) return false;
      if (h.sc > 0) return v < 55;
      return dupChance(s, i) < 0.3 && v < 34;
    default:
      return _expectedGain(s, i) > 0;
  }
}

int _best(List<int> list, double Function(int) score) {
  var best = list.first;
  var bestScore = score(best);
  for (final k in list.skip(1)) {
    final sc = score(k);
    if (sc > bestScore) {
      best = k;
      bestScore = sc;
    }
  }
  return best;
}

int _pickTarget(GameState s, Decision d, Random rng) {
  final me = d.player;
  final p = s.players[me];
  final cands = d.candidates;
  final opp = cands.where((k) => k != me).toList();

  if (p.type == 'easy') {
    final pool = opp.isNotEmpty ? opp : cands;
    return pool[rng.nextInt(pool.length)];
  }
  switch (d.kind) {
    case 'give':
      return _best(opp.isNotEmpty ? opp : cands, (k) => -s.players[k].total.toDouble());
    case 'freeze':
      if (p.type == 'hard' &&
          cands.contains(me) &&
          valueOf(s, me) >= 25 &&
          dupChance(s, me) > 0.3 &&
          p.hand.sc == 0) {
        return me;
      }
      if (opp.isEmpty) return me;
      return _best(opp, (k) =>
          s.players[k].total * 0.4 - valueOf(s, k) * 1.2 + (s.players[k].hand.nums.length < 2 ? 8 : 0));
    case 'flip3':
      if (opp.isEmpty) return me;
      return _best(opp, (k) =>
          dupChance(s, k) * max(0, valueOf(s, k)) +
          s.players[k].total * 0.03 -
          (s.players[k].hand.sc > 0 ? 20 : 0));
    case 'neg':
      return _best(cands, (k) {
        final v = valueOf(s, k).toDouble();
        if (k == me) return -2 * v;
        return 2 * v * (1 + s.players[k].total / max(1, s.target));
      });
  }
  return opp.isNotEmpty ? opp.first : cands.first;
}

AiMove decideAi(GameState s, Random rng) {
  final d = s.pending!;
  switch (d.type) {
    case DType.draw:
      return const AiMove('draw');
    case DType.turn:
      return AiMove(_wantsToDraw(s, d.player) ? 'draw' : 'stay');
    case DType.target:
      return AiMove('target', _pickTarget(s, d, rng));
  }
}
