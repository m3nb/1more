import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/ai.dart';
import '../engine/model.dart';
import '../game/controller.dart';
import 'card_view.dart';
import 'scoreboard.dart';
import 'theme.dart';

String typeLabel(String t) {
  if (t == 'human') return 'Human';
  if (t == 'remote') return 'Online';
  return kPersonas[t]?.title ?? 'Computer';
}

const _kindHelp = {
  'freeze': 'They leave the round with the points they have now.',
  'neg': 'Their round points flip to negative.',
  'flip3': 'They must draw 3 cards in a row.',
  'give': 'You already hold one, so this one goes to another player.',
};

/// A card that turns over from its back as it appears.
class _FlipIn extends StatelessWidget {
  final double width;
  final Widget child;
  const _FlipIn({super.key, required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    final back = Container(
      width: width,
      height: width * 1.4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.saffron, Color(0xFFD9962A)],
        ),
        border: Border.all(color: C.stock, width: 4),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final angle = (1 - t) * pi;
        return Transform.scale(
          scale: 0.45 + 0.55 * t,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: angle > pi / 2 ? back : child,
          ),
        );
      },
    );
  }
}

class GameScreen extends StatefulWidget {
  final GameController controller;
  final String? myClientId;
  const GameScreen({super.key, required this.controller, this.myClientId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get ctl => widget.controller;

  // An action card that resolved by itself is shown briefly so nobody misses it.
  int? _seenCard;
  GameCard? _flash;
  String _flashWho = '';
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    ctl.addListener(_onState);
  }

  @override
  void dispose() {
    ctl.removeListener(_onState);
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onState() {
    final s = ctl.state;
    if (s == null) return;
    final id = s.lastCardId;
    if (id == null || id == _seenCard) return;
    _seenCard = id;
    final d = s.pending;
    if (d != null && d.type == DType.target && d.card?.id == id) return; // the chooser overlay shows it
    for (final p in s.players) {
      for (final c in p.hand.acts) {
        if (c.id == id) {
          _flashTimer?.cancel();
          _flash = c;
          _flashWho = p.name;
          _flashTimer = Timer(const Duration(milliseconds: 1700), () {
            if (mounted) setState(() => _flash = null);
          });
          if (mounted) setState(() {});
          return;
        }
      }
    }
  }

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
              final playing = s.phase == 'deal' || s.phase == 'play';
              final d = s.pending;
              Widget? overlay;
              if (playing && d != null && d.type == DType.target && d.card != null) {
                overlay = Positioned.fill(child: _reveal(s, d.card!, d));
              } else if (_flash != null) {
                overlay = Positioned.fill(child: IgnorePointer(child: _reveal(s, _flash!, null)));
              }
              return Stack(children: [
                Column(children: [
                  _topBar(s),
                  Scoreboard(state: s, myClientId: widget.myClientId),
                  const SizedBox(height: 8),
                  Expanded(child: _table(s)),
                  _bottom(s),
                ]),
                if (overlay != null) overlay,
              ]);
            },
          ),
        ),
      ),
    );
  }

  // ---------------- big action card ----------------

  Widget _reveal(GameState s, GameCard card, Decision? d) {
    final w = MediaQuery.of(context).size.width;
    final cw = (w * 0.42).clamp(130.0, 210.0).toDouble();
    final chooser = d == null ? null : s.players[d.player];
    final mine = d != null && ctl.canControl(d.player);
    String line;
    if (d == null) {
      line = '$_flashWho drew it';
    } else if (mine) {
      line = '${chooser!.name}, pick a player';
    } else {
      line = '${chooser!.name} is choosing…';
    }
    return Container(
      color: const Color(0xE6071A1B),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _FlipIn(key: ValueKey(card.id), width: cw, child: CardView(card, width: cw)),
            const SizedBox(height: 16),
            Text(card.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.saffron, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 6),
            Text(line, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (d != null && _kindHelp[d.kind] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_kindHelp[d.kind]!,
                    textAlign: TextAlign.center, style: const TextStyle(color: C.inkSoft, fontSize: 14)),
              ),
            if (d != null && mine) ...[
              const SizedBox(height: 14),
              for (final k in d.candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: playerColor(k),
                      foregroundColor: C.stockInk,
                      minimumSize: const Size(double.infinity, 54),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () => ctl.act(d.player, 'target', target: k),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          s.players[k].name + (k == d.player ? ' (you)' : ''),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text('${valueOf(s, k)} now · ${s.players[k].total} total',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------- top ----------------

  Widget _topBar(GameState s) {
    Widget stat(String v, String l) => Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(l, style: const TextStyle(fontSize: 10, color: C.inkSoft, letterSpacing: .6)),
          const SizedBox(width: 4),
          Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
      child: Row(children: [
        const Text('1More', style: TextStyle(color: C.saffron, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(width: 12),
        stat('${s.round}', 'ROUND'),
        const SizedBox(width: 12),
        stat('${s.target}', 'TARGET'),
        if (ctl.roomCode != null) ...[
          const SizedBox(width: 12),
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

  // ---------------- table: every player on one screen ----------------

  Widget _table(GameState s) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 900) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: LayoutBuilder(builder: (c, b) => _seatGrid(s, b.maxWidth, b.maxHeight))),
            const SizedBox(width: 12),
            SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(children: [_deckPanel(s), const SizedBox(height: 12), _logPanel(s, true)]),
              ),
            ),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(children: [
          Expanded(child: LayoutBuilder(builder: (c, b) => _seatGrid(s, b.maxWidth, b.maxHeight))),
          _ticker(s),
        ]),
      );
    });
  }

  Widget _seatGrid(GameState s, double w, double h) {
    const gap = 8.0;
    final n = s.players.length;
    int cols;
    if (w < 560) {
      cols = n <= 3 ? 1 : 2;
    } else {
      cols = n <= 4 ? min(n, 2) : (n <= 6 ? 3 : 4);
    }
    final rows = (n / cols).ceil();
    var cellH = (h - gap * (rows - 1)) / rows;
    final scroll = cellH < 92;
    cellH = cellH.clamp(92.0, 230.0).toDouble();
    final col = Column(mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < rows; r++)
        Padding(
          padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
          child: SizedBox(
            height: cellH,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                Expanded(child: r * cols + c < n ? _seat(s, r * cols + c) : const SizedBox()),
              ],
            ]),
          ),
        ),
    ]);
    return scroll ? SingleChildScrollView(child: col) : Align(alignment: Alignment.topCenter, child: col);
  }

  bool _isMine(Player p) => widget.myClientId != null && p.clientId == widget.myClientId;

  Widget _pill(String t, Color bg) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(color: C.stockInk, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  /// Cards sized so the whole hand fits the space it is given.
  Widget _hand(GameState s, RoundHand h) {
    final nums = [...h.nums]..sort((a, b) => a.v - b.v);
    final cards = [...nums, ...h.mods, ...h.acts];
    final count = cards.length + (h.bust != null ? 1 : 0);
    if (count == 0) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('No cards yet', style: TextStyle(color: C.inkSoft, fontSize: 12)),
      );
    }
    return LayoutBuilder(builder: (context, box) {
      const gap = 4.0;
      var cw = 12.0;
      for (var tryW = 46.0; tryW >= 12; tryW -= 2) {
        final perRow = ((box.maxWidth + gap) / (tryW + gap)).floor();
        if (perRow < 1) continue;
        final rows = (count / perRow).ceil();
        if (rows * tryW * 1.4 + (rows - 1) * gap <= box.maxHeight) {
          cw = tryW;
          break;
        }
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: gap, runSpacing: gap, children: [
          for (final c in cards) CardView(c, width: cw, fresh: c.id == s.lastCardId),
          if (h.bust != null) CardView(h.bust!, width: cw, duplicate: true, fresh: h.bust!.id == s.lastCardId),
        ]),
      );
    });
  }

  Widget _seat(GameState s, int i) {
    final p = s.players[i];
    final h = p.hand;
    final col = playerColor(i);
    final v = scoreOf(h).value;
    final isTurn = s.pending?.player == i && (s.phase == 'deal' || s.phase == 'play');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: isTurn
            ? col.withValues(alpha: 0.16)
            : (h.status == PStatus.bust ? C.coral.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTurn ? col : col.withValues(alpha: 0.45), width: isTurn ? 3 : 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              p.name + (_isMine(p) ? ' (you)' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          if (leaders(s).contains(i)) const Padding(padding: EdgeInsets.only(right: 5), child: Crown(size: 16)),
          Text('${p.total}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1)),
        ]),
        const SizedBox(height: 4),
        Expanded(child: _hand(s, h)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (isTurn) _pill('TURN', col),
                if (h.status == PStatus.stayed) _pill('STAYED', C.stock),
                if (h.status == PStatus.bust) _pill('BUST', C.coral),
                if (h.status == PStatus.frozen) _pill('FROZEN', C.ice),
                if (h.neg) _pill('NEG', C.plum),
                if (h.sc > 0) _pill('2ND', C.mint),
                if (h.nums.length >= 7 && h.status != PStatus.bust) _pill('+15', C.mint),
              ]),
            ),
          ),
          Text('${h.nums.length}/7', style: const TextStyle(color: C.inkSoft, fontSize: 11)),
          const SizedBox(width: 8),
          Text(v > 0 ? '+$v' : '$v',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, height: 1, color: v < 0 ? C.plum : C.ink)),
        ]),
      ]),
    );
  }

  /// Phones: one line with the deck count and the latest event.
  Widget _ticker(GameState s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Row(children: [
          const Icon(Icons.style_outlined, size: 15, color: C.saffron),
          const SizedBox(width: 4),
          Text('${s.deck.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.log.isEmpty ? '' : s.log.first,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.inkSoft, fontSize: 13)),
          ),
        ]),
      );

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
        return Text.rich(TextSpan(children: [name, TextSpan(text: ', pick a player for your ${d.card?.label ?? 'card'}.')]));
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
