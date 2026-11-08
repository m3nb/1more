import 'package:flutter/material.dart';

import '../engine/ai.dart';
import '../engine/model.dart';
import '../game/controller.dart';
import 'card_view.dart';
import 'theme.dart';

const _typeName = {
  'human': 'Human',
  'remote': 'Online',
  'easy': 'CPU · Easy',
  'medium': 'CPU · Medium',
  'hard': 'CPU · Hard',
};

const _kindTitle = {
  'freeze': 'Who gets frozen?',
  'neg': 'Who gets the Negative?',
  'flip3': 'Who flips 3 cards?',
  'give': 'Who gets your extra Second Chance?',
};

class GameScreen extends StatefulWidget {
  final GameController controller;
  final String? myClientId;
  const GameScreen({super.key, required this.controller, this.myClientId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get ctl => widget.controller;

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave the game?'),
        content: const Text('The current scores will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && mounted) {
      ctl.leave();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: ctl,
            builder: (context, _) {
              final s = ctl.state;
              if (s == null) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(ctl.connectionNote ?? 'Waiting for the host…'),
                  ]),
                );
              }
              return Column(children: [
                _topBar(s),
                Expanded(child: _table(s)),
                _bottom(s),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar(GameState s) {
    Widget stat(String v, String l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.1)),
          Text(l, style: const TextStyle(fontSize: 11, color: C.inkSoft, letterSpacing: .6)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(children: [
        const Text('1More', style: TextStyle(color: C.saffron, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(width: 16),
        stat('${s.round}', 'ROUND'),
        const SizedBox(width: 16),
        stat('${s.target}', 'TARGET'),
        if (ctl.roomCode != null) ...[
          const SizedBox(width: 16),
          stat(ctl.roomCode!, 'ROOM'),
        ],
        const Spacer(),
        if (ctl.connectionNote != null)
          Flexible(
            child: Text(ctl.connectionNote!,
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.coral, fontSize: 12)),
          ),
        IconButton(onPressed: _confirmLeave, icon: const Icon(Icons.close), tooltip: 'Leave game'),
      ]),
    );
  }

  Widget _table(GameState s) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      final seats = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < s.players.length; i++)
            SizedBox(
              width: wide
                  ? (box.maxWidth - 300 - 32 - 12) / (box.maxWidth > 1250 ? 3 : 2) - 12
                  : (box.maxWidth >= 600 ? (box.maxWidth - 32 - 12) / 2 : box.maxWidth - 32),
              child: _seat(s, i),
            ),
        ],
      );
      final side = Column(children: [_deckPanel(s), const SizedBox(height: 12), _logPanel(s, wide)]);
      if (wide) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 16), child: seats)),
            const SizedBox(width: 12),
            SizedBox(width: 300, child: SingleChildScrollView(child: side)),
          ]),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(children: [seats, const SizedBox(height: 12), side]),
      );
    });
  }

  bool _isMine(Player p) => widget.myClientId != null && p.clientId == widget.myClientId;

  Widget _pill(String t, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(color: C.stockInk, fontSize: 11, fontWeight: FontWeight.w800)),
      );

  Widget _seat(GameState s, int i) {
    final p = s.players[i];
    final h = p.hand;
    final v = scoreOf(h).value;
    final isTurn = s.pending?.player == i && (s.phase == 'deal' || s.phase == 'play');
    final nums = [...h.nums]..sort((a, b) => a.v - b.v);
    final extras = [...h.mods, ...h.acts];
    return Panel(
      padding: const EdgeInsets.all(12),
      border: isTurn ? C.saffron : null,
      fill: isTurn
          ? C.saffron.withValues(alpha: 0.08)
          : (h.status == PStatus.bust ? C.coral.withValues(alpha: 0.07) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(p.name + (_isMine(p) ? ' (you)' : ''),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(_typeName[p.type] ?? p.type, style: const TextStyle(color: C.inkSoft, fontSize: 11)),
              if (isTurn) _pill('Turn', C.saffron),
              if (h.status == PStatus.stayed) _pill('Stayed', C.stock),
              if (h.status == PStatus.bust) _pill('Busted', C.coral),
              if (h.status == PStatus.frozen) _pill('Frozen', C.ice),
              if (h.neg) _pill('Negative', C.plum),
              if (h.sc > 0) _pill('Second Chance', C.mint),
              if (h.nums.length >= 7 && h.status != PStatus.bust) _pill('+15', C.mint),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${p.total}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
            Text('of ${s.target}', style: const TextStyle(color: C.inkSoft, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: nums.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('No numbers yet', style: TextStyle(color: C.inkSoft, fontSize: 13)),
                )
              : Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in nums) CardView(c, fresh: c.id == s.lastCardId),
                ]),
        ),
        if (extras.isNotEmpty || h.bust != null) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in extras) CardView(c, fresh: c.id == s.lastCardId),
            if (h.bust != null) CardView(h.bust!, duplicate: true, fresh: h.bust!.id == s.lastCardId),
          ]),
        ],
        const Divider(color: C.line, height: 20),
        Row(children: [
          for (var k = 0; k < 7; k++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: k < h.nums.length ? C.mint : C.line),
            ),
          const Spacer(),
          const Text('Round points ', style: TextStyle(fontSize: 13)),
          Text('$v',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: v < 0 ? C.plum : C.ink)),
        ]),
      ]),
    );
  }

  Widget _deckPanel(GameState s) => Panel(
        child: Row(children: [
          Container(
            width: 46,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(colors: [C.saffron, Color(0xFFD9962A)]),
              boxShadow: const [BoxShadow(color: Color(0xFFB07B20), offset: Offset(3, 3))],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.deck.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('cards in deck', style: TextStyle(color: C.inkSoft, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${s.discard.length} used, reshuffled when the deck runs out',
                  style: const TextStyle(color: C.inkSoft, fontSize: 12)),
            ]),
          ),
        ]),
      );

  Widget _logPanel(GameState s, bool wide) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Label('Latest'),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: wide ? 360 : 180),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var k = 0; k < s.log.length && k < 40; k++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(s.log[k],
                        style: TextStyle(fontSize: 13, color: k == 0 ? C.ink : C.inkSoft)),
                  ),
              ],
            ),
          ),
        ]),
      );

  // ---------------- bottom: actions or results ----------------

  Widget _bottom(GameState s) {
    Widget content;
    if (s.phase == 'roundEnd' || s.phase == 'gameOver') {
      content = _results(s);
    } else {
      content = _actions(s);
    }
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xF5091E1F),
        border: Border(top: BorderSide(color: C.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: content,
    );
  }

  Widget _actions(GameState s) {
    final d = s.pending;
    if (d == null) return const SizedBox(height: 48);
    final p = s.players[d.player];
    final mine = ctl.canControl(d.player);
    if (!mine) {
      return Row(children: [
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: p.name, style: const TextStyle(color: C.saffron, fontWeight: FontWeight.w800)),
            TextSpan(text: p.isCpu ? ' is thinking…' : ' is playing…'),
          ])),
        ),
        if (ctl.canTakeOverSeats && p.type == 'remote')
          TextButton(onPressed: () => ctl.takeOverSeat(d.player), child: const Text('Let CPU play this seat')),
      ]);
    }
    final name = TextSpan(text: p.name, style: const TextStyle(color: C.saffron, fontWeight: FontWeight.w800));
    switch (d.type) {
      case DType.draw:
        return Row(children: [
          Expanded(child: Text.rich(TextSpan(children: [name, const TextSpan(text: ', your first draw is mandatory.')]))),
          FilledButton(onPressed: () => ctl.act(d.player, 'draw'), child: const Text('Draw')),
        ]);
      case DType.turn:
        final h = p.hand;
        final risk = h.sc > 0
            ? 'You hold a Second Chance, so a duplicate won\'t bust you.'
            : 'Chance of a duplicate on your next draw: about ${(dupChance(s, d.player) * 100).round()}%';
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text.rich(TextSpan(children: [
                  name,
                  TextSpan(text: ', you have ${scoreOf(h).value} this round. Draw or stay?'),
                ])),
                Text(risk, style: const TextStyle(color: C.inkSoft, fontSize: 12)),
              ]),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.stock),
                onPressed: () => ctl.act(d.player, 'stay'),
                child: const Text('Stay'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => ctl.act(d.player, 'draw'), child: const Text('Draw')),
            ]),
          ],
        );
      case DType.target:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [name, TextSpan(text: ': ${_kindTitle[d.kind] ?? 'Choose a player'}')])),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in d.candidates)
              OutlinedButton(
                onPressed: () => ctl.act(d.player, 'target', target: k),
                child: Text('${s.players[k].name}${k == d.player ? ' (you)' : ''} · ${valueOf(s, k)}'),
              ),
          ]),
        ]);
    }
  }

  Widget _results(GameState s) {
    final rows = [...s.results]..sort((a, b) => s.players[b.player].total - s.players[a.player].total);
    const statusName = {
      PStatus.stayed: 'Stayed',
      PStatus.frozen: 'Frozen',
      PStatus.bust: 'Busted',
      PStatus.active: '—',
    };
    final over = s.phase == 'gameOver';
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (over)
            Center(
              child: Text('${s.players[s.winner!].name} wins!',
                  style: const TextStyle(color: C.saffron, fontSize: 32, fontWeight: FontWeight.w900)),
            )
          else
            Text('Round ${s.round} results',
                style: const TextStyle(color: C.saffron, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(
            over
                ? 'Target was ${s.target}.'
                : (s.tie ? 'Tie at the top above the target. One more round to settle it.' : 'Target: ${s.target} points.'),
            style: const TextStyle(color: C.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.players[r.player].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${statusName[r.status]} · ${r.calc}', style: const TextStyle(color: C.inkSoft, fontSize: 12)),
                  ]),
                ),
                SizedBox(
                  width: 60,
                  child: Text('${r.value > 0 ? '+' : ''}${r.value}',
                      textAlign: TextAlign.end, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                SizedBox(
                  width: 60,
                  child: Text('${s.players[r.player].total}',
                      textAlign: TextAlign.end, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: over
                ? FilledButton(
                    onPressed: () {
                      ctl.leave();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Back to menu'))
                : (ctl.canAdvanceRound
                    ? FilledButton(onPressed: ctl.nextRound, child: const Text('Next round'))
                    : const Text('Waiting for the host to start the next round…',
                        style: TextStyle(color: C.inkSoft))),
          ),
        ]),
      ),
    );
  }
}
