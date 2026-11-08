// Data model for 1More. Everything here serializes to plain JSON so the
// host can broadcast the full game state to other players.

enum CardType { num, add, x2, sc, flip3, freeze, neg }

int _int(dynamic v) => (v as num).toInt();

class GameCard {
  final int id;
  final CardType t;
  final int v;
  const GameCard(this.id, this.t, [this.v = 0]);

  bool get isNumber => t == CardType.num;
  bool get isModifier => t == CardType.add || t == CardType.x2;
  bool get isAction => !isNumber && !isModifier;

  String get label {
    switch (t) {
      case CardType.num:
        return '$v';
      case CardType.add:
        return '+$v';
      case CardType.x2:
        return '×2';
      case CardType.sc:
        return 'Second Chance';
      case CardType.flip3:
        return 'Flip 3';
      case CardType.freeze:
        return 'Freeze';
      case CardType.neg:
        return 'Negative';
    }
  }

  Map<String, dynamic> toJson() => {'i': id, 't': t.index, 'v': v};

  static GameCard fromJson(dynamic j) {
    final m = j as Map;
    return GameCard(_int(m['i']), CardType.values[_int(m['t'])], _int(m['v']));
  }
}

enum PStatus { active, stayed, bust, frozen }

List<GameCard> _cards(dynamic j) =>
    (j as List).map((e) => GameCard.fromJson(e)).toList();

class RoundHand {
  List<GameCard> nums;
  List<GameCard> mods;
  List<GameCard> acts;
  int sc;
  bool neg;
  PStatus status;
  int drawn;
  GameCard? bust;

  RoundHand({
    List<GameCard>? nums,
    List<GameCard>? mods,
    List<GameCard>? acts,
    this.sc = 0,
    this.neg = false,
    this.status = PStatus.active,
    this.drawn = 0,
    this.bust,
  })  : nums = nums ?? [],
        mods = mods ?? [],
        acts = acts ?? [];

  bool get active => status == PStatus.active;

  List<GameCard> get allCards => [...nums, ...mods, ...acts, if (bust != null) bust!];

  Map<String, dynamic> toJson() => {
        'n': nums.map((c) => c.toJson()).toList(),
        'm': mods.map((c) => c.toJson()).toList(),
        'a': acts.map((c) => c.toJson()).toList(),
        'sc': sc,
        'neg': neg,
        'st': status.index,
        'dr': drawn,
        if (bust != null) 'b': bust!.toJson(),
      };

  static RoundHand fromJson(dynamic j) {
    final m = j as Map;
    return RoundHand(
      nums: _cards(m['n']),
      mods: _cards(m['m']),
      acts: _cards(m['a']),
      sc: _int(m['sc']),
      neg: m['neg'] as bool,
      status: PStatus.values[_int(m['st'])],
      drawn: _int(m['dr']),
      bust: m['b'] == null ? null : GameCard.fromJson(m['b']),
    );
  }
}

/// Player types: human (on this device), remote (another device),
/// easy / medium / hard (computer).
class Player {
  String name;
  String type;
  String? clientId;
  int total;
  RoundHand hand;

  Player({required this.name, required this.type, this.clientId, this.total = 0, RoundHand? hand})
      : hand = hand ?? RoundHand();

  bool get isCpu => type == 'easy' || type == 'medium' || type == 'hard';

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        if (clientId != null) 'cid': clientId,
        'total': total,
        'hand': hand.toJson(),
      };

  static Player fromJson(dynamic j) {
    final m = j as Map;
    return Player(
      name: m['name'] as String,
      type: m['type'] as String,
      clientId: m['cid'] as String?,
      total: _int(m['total']),
      hand: RoundHand.fromJson(m['hand']),
    );
  }
}

class Score {
  final int value;
  final String calc;
  const Score(this.value, this.calc);
}

/// Round scoring: numbers, ×2 on numbers only, then + cards, then the
/// seven-numbers bonus, then a Negative flips the sign. A bust scores 0,
/// unless the player carries a Negative: then the pre-bust total is deducted.
Score scoreOf(RoundHand h) {
  if (h.status == PStatus.bust && !h.neg) return const Score(0, 'Busted (duplicate)');
  final sum = h.nums.fold<int>(0, (a, c) => a + c.v);
  var v = sum;
  final parts = <String>['Numbers $sum'];
  if (h.mods.any((c) => c.t == CardType.x2)) {
    v *= 2;
    parts.add('×2 = $v');
  }
  final adds = h.mods.where((c) => c.t == CardType.add).fold<int>(0, (a, c) => a + c.v);
  if (adds > 0) {
    v += adds;
    parts.add('+$adds');
  }
  if (h.nums.length >= 7) {
    v += 15;
    parts.add('+15 bonus');
  }
  if (h.neg) {
    v = -v;
    parts.add('× negative');
  }
  if (h.status == PStatus.bust) parts.insert(0, 'Duplicate with Negative ·');
  return Score(v, parts.join(' '));
}

enum DType { draw, turn, target }

/// What the game is waiting for, and from whom.
class Decision {
  final DType type;
  final int player;
  final String? kind; // give | freeze | neg | flip3
  final List<int> candidates;
  final GameCard? card;

  const Decision(this.type, this.player, {this.kind, this.candidates = const [], this.card});

  Map<String, dynamic> toJson() => {
        'ty': type.index,
        'p': player,
        if (kind != null) 'k': kind,
        'c': candidates,
        if (card != null) 'card': card!.toJson(),
      };

  static Decision fromJson(dynamic j) {
    final m = j as Map;
    return Decision(
      DType.values[_int(m['ty'])],
      _int(m['p']),
      kind: m['k'] as String?,
      candidates: (m['c'] as List).map(_int).toList(),
      card: m['card'] == null ? null : GameCard.fromJson(m['card']),
    );
  }
}

class FlipTask {
  final int target;
  int remaining;
  FlipTask(this.target, this.remaining);
  Map<String, dynamic> toJson() => {'t': target, 'r': remaining};
  static FlipTask fromJson(dynamic j) => FlipTask(_int((j as Map)['t']), _int(j['r']));
}

class RoundResult {
  final int player;
  final int value;
  final String calc;
  final PStatus status;
  const RoundResult(this.player, this.value, this.calc, this.status);
  Map<String, dynamic> toJson() => {'p': player, 'v': value, 'c': calc, 's': status.index};
  static RoundResult fromJson(dynamic j) {
    final m = j as Map;
    return RoundResult(_int(m['p']), _int(m['v']), m['c'] as String, PStatus.values[_int(m['s'])]);
  }
}

class GameState {
  List<Player> players;
  int target;
  List<GameCard> deck;
  List<GameCard> discard;
  int round;
  int starter;
  String phase; // deal | play | roundEnd | gameOver
  int pos;
  List<int> order;
  Decision? pending;
  List<FlipTask> flips;
  bool advanceAfter;
  List<String> log;
  List<RoundResult> results;
  int? winner;
  bool tie;
  int? lastCardId;
  int version;

  GameState({
    required this.players,
    required this.target,
    required this.deck,
    List<GameCard>? discard,
    this.round = 1,
    this.starter = 0,
    this.phase = 'deal',
    this.pos = 0,
    List<int>? order,
    this.pending,
    List<FlipTask>? flips,
    this.advanceAfter = false,
    List<String>? log,
    List<RoundResult>? results,
    this.winner,
    this.tie = false,
    this.lastCardId,
    this.version = 0,
  })  : discard = discard ?? [],
        order = order ?? [],
        flips = flips ?? [],
        log = log ?? [],
        results = results ?? [];

  /// [hideDeck] sends the remaining deck sorted, so other devices see what
  /// is left (public information) but not the draw order.
  Map<String, dynamic> toJson({bool hideDeck = false}) {
    final d = [...deck];
    if (hideDeck) {
      d.sort((a, b) => a.t.index != b.t.index ? a.t.index - b.t.index : a.v - b.v);
    }
    return {
      'players': players.map((p) => p.toJson()).toList(),
      'target': target,
      'deck': d.map((c) => c.toJson()).toList(),
      'discard': discard.map((c) => c.toJson()).toList(),
      'round': round,
      'starter': starter,
      'phase': phase,
      'pos': pos,
      'order': order,
      if (pending != null) 'pending': pending!.toJson(),
      'flips': flips.map((f) => f.toJson()).toList(),
      'adv': advanceAfter,
      'log': log,
      'results': results.map((r) => r.toJson()).toList(),
      if (winner != null) 'winner': winner,
      'tie': tie,
      if (lastCardId != null) 'last': lastCardId,
      'ver': version,
    };
  }

  static GameState fromJson(dynamic j) {
    final m = j as Map;
    return GameState(
      players: (m['players'] as List).map(Player.fromJson).toList(),
      target: _int(m['target']),
      deck: _cards(m['deck']),
      discard: _cards(m['discard']),
      round: _int(m['round']),
      starter: _int(m['starter']),
      phase: m['phase'] as String,
      pos: _int(m['pos']),
      order: (m['order'] as List).map(_int).toList(),
      pending: m['pending'] == null ? null : Decision.fromJson(m['pending']),
      flips: (m['flips'] as List).map(FlipTask.fromJson).toList(),
      advanceAfter: m['adv'] as bool,
      log: (m['log'] as List).map((e) => e as String).toList(),
      results: (m['results'] as List).map(RoundResult.fromJson).toList(),
      winner: m['winner'] == null ? null : _int(m['winner']),
      tie: m['tie'] as bool,
      lastCardId: m['last'] == null ? null : _int(m['last']),
      version: _int(m['ver']),
    );
  }

  int cardsInPlay() =>
      deck.length + discard.length + players.fold<int>(0, (a, p) => a + p.hand.allCards.length);
}
