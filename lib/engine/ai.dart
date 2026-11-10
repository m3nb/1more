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

/// Average change in round points from one more draw.
double expectedGain(GameState s, int i) {
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

// ---------------------------------------------------------------- draw / stay

bool _wantsToDraw(GameState s, int i) {
  final p = s.players[i];
  final h = p.hand;
  final v = valueOf(s, i);
  if (h.drawn == 0) return true;
  // A Negative makes every new card cost points, so everyone stops.
  if (h.neg) return false;

  var othersBest = 0;
  for (var k = 0; k < s.players.length; k++) {
    if (k == i) continue;
    othersBest = max(othersBest, s.players[k].total + max(0, valueOf(s, k)));
  }
  final winsNow = v > 0 && p.total + v >= s.target && p.total + v > othersBest;

  switch (p.type) {
    case 'rocky':
      // The gambler: only a near-certain bust or a big pile stops him.
      if (winsNow && v >= 30) return false;
      if (h.sc > 0) return v < 75;
      return v < 48 && dupChance(s, i) < 0.5;
    case 'sage':
      if (winsNow) return false;
      // Patient when ahead, a little braver when far behind.
      final leaderTotal = s.players.map((q) => q.total).reduce(max);
      final gap = leaderTotal - p.total;
      final bar = gap > s.target * 0.3 ? -1.5 : (p.total >= leaderTotal ? 1.0 : 0.0);
      return expectedGain(s, i) > bar;
    default:
      // The hunters play a steady middle game; their fun is in the targeting.
      if (winsNow) return false;
      if (h.sc > 0) return v < 55;
      return dupChance(s, i) < 0.3 && v < 34;
  }
}

// ---------------------------------------------------------------- targeting

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

/// The careful choice, used by Sage and as everyone's fallback.
int _strategicTarget(GameState s, Decision d) {
  final me = d.player;
  final cands = d.candidates;
  final opp = cands.where((k) => k != me).toList();
  switch (d.kind) {
    case 'give':
      return _best(opp.isNotEmpty ? opp : cands, (k) => -s.players[k].total.toDouble());
    case 'freeze':
      if (cands.contains(me) && valueOf(s, me) >= 25 && dupChance(s, me) > 0.3 && s.players[me].hand.sc == 0) {
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

/// Vex: everything goes at the player with the highest total.
int? _vexTarget(GameState s, Decision d) {
  final me = d.player;
  final opp = d.candidates.where((k) => k != me).toList();
  if (opp.isEmpty) return null;
  // Leaders first: highest total, then highest round points.
  opp.sort((a, b) {
    final t = s.players[b].total - s.players[a].total;
    return t != 0 ? t : valueOf(s, b) - valueOf(s, a);
  });
  final leader = opp.first;
  switch (d.kind) {
    case 'neg':
      // A Negative only hurts someone with positive points.
      for (final k in opp) {
        if (valueOf(s, k) > 0) return k;
      }
      return null;
    case 'flip3':
      return leader;
    case 'freeze':
      // Freezing locks points in, so only freeze a leader who has little yet.
      return valueOf(s, leader) <= 15 ? leader : null;
    case 'give':
      return opp.last; // never helps the leader
  }
  return null;
}

/// Hex: action cards go to the real people at the table.
int? _hexTarget(GameState s, Decision d) {
  final me = d.player;
  final people = d.candidates.where((k) => k != me && s.players[k].isPerson).toList();
  switch (d.kind) {
    case 'neg':
      final hurt = people.where((k) => valueOf(s, k) > 0).toList();
      return hurt.isEmpty ? null : _best(hurt, (k) => valueOf(s, k).toDouble());
    case 'flip3':
      if (people.isEmpty) return null;
      return _best(people, (k) => dupChance(s, k) * 100 + valueOf(s, k) * 0.2);
    case 'freeze':
      if (people.isEmpty) return null;
      return _best(people, (k) => -valueOf(s, k).toDouble());
    case 'give':
      final bots = d.candidates.where((k) => k != me && s.players[k].isCpu).toList();
      return bots.isEmpty ? null : bots.first;
  }
  return null;
}

/// Rocky: big swings, sometimes at himself.
int? _rockyTarget(GameState s, Decision d, Random rng) {
  final me = d.player;
  final opp = d.candidates.where((k) => k != me).toList();
  switch (d.kind) {
    case 'flip3':
      // Three free cards sound great to a gambler.
      if (d.candidates.contains(me) && dupChance(s, me) < 0.2) return me;
      return null;
    case 'freeze':
      // Like Vex: freeze whoever is closest to winning, but only while their
      // round points are still low, so the freeze locks in very little.
      if (opp.isEmpty) return null;
      final leader = _best(opp, (k) => (s.players[k].total + max(0, valueOf(s, k))).toDouble());
      return valueOf(s, leader) <= 15 ? leader : null;
    case 'give':
      return opp.isEmpty ? null : opp[rng.nextInt(opp.length)];
  }
  return null;
}

int _pickTarget(GameState s, Decision d, Random rng) {
  int? pick;
  switch (s.players[d.player].type) {
    case 'vex':
      pick = _vexTarget(s, d);
      break;
    case 'hex':
      pick = _hexTarget(s, d);
      break;
    case 'rocky':
      pick = _rockyTarget(s, d, rng);
      break;
  }
  if (pick != null && d.candidates.contains(pick)) return pick;
  return _strategicTarget(s, d);
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
