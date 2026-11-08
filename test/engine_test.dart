import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_more/engine/ai.dart';
import 'package:one_more/engine/engine.dart';
import 'package:one_more/engine/model.dart';

GameCard n(int id, int v) => GameCard(id, CardType.num, v);

/// Build a game whose deck is drawn in exactly the given order.
Engine rigged(List<GameCard> drawOrder, {int players = 2, int target = 200}) {
  final s = GameState(
    players: List.generate(players, (i) => Player(name: 'P$i', type: 'human')),
    target: target,
    deck: drawOrder.reversed.toList(),
  );
  final e = Engine(s, Random(1));
  e.startRound();
  return e;
}

void main() {
  test('deck has 93 cards with the right mix', () {
    final d = buildDeck(Random(3));
    expect(d.length, kDeckSize);
    for (var v = 1; v <= 12; v++) {
      expect(d.where((c) => c.isNumber && c.v == v).length, v);
    }
    expect(d.where((c) => c.isNumber && c.v == 0).length, 1);
    expect(d.where((c) => c.t == CardType.add).length, 5);
    expect(d.where((c) => c.t == CardType.x2).length, 1);
    for (final t in [CardType.sc, CardType.flip3, CardType.freeze, CardType.neg]) {
      expect(d.where((c) => c.t == t).length, 2);
    }
  });

  group('scoring', () {
    test('×2 doubles numbers only, then + cards', () {
      final h = RoundHand(nums: [n(1, 5), n(2, 8), n(3, 10)], mods: [
        const GameCard(4, CardType.x2),
        const GameCard(5, CardType.add, 4),
      ]);
      expect(scoreOf(h).value, 50);
    });

    test('seven different numbers add 15', () {
      final h = RoundHand(nums: [for (var v = 1; v <= 7; v++) n(v, v)]);
      expect(scoreOf(h).value, 28 + 15);
    });

    test('Negative flips the sign; two cancel', () {
      final h = RoundHand(nums: [n(1, 5), n(2, 8)], neg: true);
      expect(scoreOf(h).value, -13);
      h.neg = false;
      expect(scoreOf(h).value, 13);
    });

    test('bust scores 0', () {
      final h = RoundHand(nums: [n(1, 5)], status: PStatus.bust, bust: n(2, 5));
      expect(scoreOf(h).value, 0);
    });

    test('bust with Negative deducts the pre-bust total', () {
      final h = RoundHand(
        nums: [n(1, 5), n(2, 8), n(3, 10)],
        mods: [const GameCard(4, CardType.x2)],
        neg: true,
        status: PStatus.bust,
        bust: n(5, 8),
      );
      expect(scoreOf(h).value, -46);
    });
  });

  group('turns', () {
    test('first draw is mandatory, then draw or stay', () {
      final e = rigged([n(1, 3), n(2, 4), n(3, 5)]);
      expect(e.s.pending!.type, DType.draw);
      expect(e.apply(0, 'stay'), isFalse);
      expect(e.apply(0, 'draw'), isTrue);
      expect(e.apply(1, 'draw'), isTrue);
      expect(e.s.phase, 'play');
      expect(e.s.pending!.type, DType.turn);
      expect(e.s.pending!.player, 0);
    });

    test('duplicate busts the player', () {
      final e = rigged([n(1, 7), n(2, 2), n(3, 7)]);
      e.apply(0, 'draw');
      e.apply(1, 'draw');
      e.apply(0, 'draw');
      expect(e.s.players[0].hand.status, PStatus.bust);
    });

    test('Second Chance absorbs a duplicate', () {
      final e = rigged([n(1, 7), n(2, 2), const GameCard(3, CardType.sc), n(4, 9), n(5, 7)]);
      e.apply(0, 'draw'); // 7
      e.apply(1, 'draw'); // 2
      e.apply(0, 'draw'); // SC
      e.apply(1, 'draw'); // 9
      e.apply(0, 'draw'); // 7 again
      final h = e.s.players[0].hand;
      expect(h.status, PStatus.active);
      expect(h.sc, 0);
      expect(h.nums.map((c) => c.v), [7]);
    });

    test('Freeze asks for a target and freezes them', () {
      final e = rigged([const GameCard(1, CardType.freeze), n(2, 4)]);
      e.apply(0, 'draw');
      expect(e.s.pending!.type, DType.target);
      expect(e.s.pending!.kind, 'freeze');
      e.apply(0, 'target', target: 1);
      expect(e.s.players[1].hand.status, PStatus.frozen);
    });

    test('Flip 3 draws three cards for the target', () {
      final e = rigged([n(1, 1), const GameCard(2, CardType.flip3), n(3, 3), n(4, 4), n(5, 5)]);
      e.apply(0, 'draw'); // 1
      e.apply(1, 'draw'); // flip 3 -> choose
      e.apply(1, 'target', target: 0);
      expect(e.s.players[0].hand.nums.map((c) => c.v).toList(), [1, 3, 4, 5]);
    });

    test('Negative on a player who later busts deducts their total', () {
      final e = rigged([n(1, 10), const GameCard(2, CardType.neg), n(3, 10), n(4, 6)]);
      e.apply(0, 'draw'); // 10
      e.apply(1, 'draw'); // neg
      e.apply(1, 'target', target: 0);
      e.apply(0, 'draw'); // 10 again -> bust with negative
      expect(scoreOf(e.s.players[0].hand).value, -10);
    });
  });

  test('state survives a JSON round trip', () {
    final e = Engine.newGame(
      [Player(name: 'A', type: 'human'), Player(name: 'B', type: 'hard')],
      250,
      rng: Random(5),
    );
    final copy = GameState.fromJson(jsonDecode(jsonEncode(e.s.toJson())));
    expect(jsonEncode(copy.toJson()), jsonEncode(e.s.toJson()));
  });

  test('full CPU games finish and never lose a card', () {
    for (var seed = 0; seed < 60; seed++) {
      final rng = Random(seed);
      final players = [
        for (var i = 0; i < 2 + seed % 7; i++) Player(name: 'C$i', type: ['easy', 'medium', 'hard'][i % 3])
      ];
      final e = Engine.newGame(players, kTargets[seed % kTargets.length], rng: rng);
      var steps = 0;
      while (e.s.phase != 'gameOver') {
        expect(++steps, lessThan(20000), reason: 'seed $seed did not finish');
        if (e.s.phase == 'roundEnd') {
          e.nextRound();
          continue;
        }
        final m = decideAi(e.s, rng);
        expect(e.apply(e.s.pending!.player, m.type, target: m.target), isTrue);
        if (e.s.phase == 'deal' || e.s.phase == 'play') {
          expect(e.s.cardsInPlay(), kDeckSize, reason: 'seed $seed');
        }
      }
      expect(e.s.winner, isNotNull);
      expect(e.s.players[e.s.winner!].total, greaterThanOrEqualTo(e.s.target));
    }
  });
}
