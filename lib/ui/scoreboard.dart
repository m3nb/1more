import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/model.dart';
import 'theme.dart';

/// Seats holding the top total. Nobody leads while everyone is level.
Set<int> leaders(GameState s) {
  final totals = s.players.map((p) => p.total).toList();
  final top = totals.reduce(max);
  final idx = {for (var i = 0; i < totals.length; i++) if (totals[i] == top) i};
  return idx.length == totals.length ? <int>{} : idx;
}

class Crown extends StatelessWidget {
  final double size;
  const Crown({super.key, this.size = 18});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size * 0.72), painter: _CrownPainter());
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width, h = sz.height;
    final body = Path()
      ..moveTo(0, h * 0.28)
      ..lineTo(w * 0.27, h * 0.58)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.73, h * 0.58)
      ..lineTo(w, h * 0.28)
      ..lineTo(w * 0.88, h * 0.82)
      ..lineTo(w * 0.12, h * 0.82)
      ..close();
    canvas.drawPath(body, Paint()..color = C.saffron);
    canvas.drawRect(Rect.fromLTRB(w * 0.12, h * 0.86, w * 0.88, h), Paint()..color = C.saffron);
    final gem = Paint()..color = C.coral;
    canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.07, gem);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A strip of every player's total, highest first, with a crown on the leader.
class Scoreboard extends StatelessWidget {
  final GameState state;
  final String? myClientId;
  const Scoreboard({super.key, required this.state, this.myClientId});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final lead = leaders(s);
    final turn = (s.phase == 'deal' || s.phase == 'play') ? s.pending?.player : null;
    final order = List.generate(s.players.length, (i) => i)
      ..sort((a, b) => s.players[b].total - s.players[a].total);
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: order.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, k) {
          final i = order[k];
          final p = s.players[i];
          final round = scoreOf(p.hand).value;
          final isLead = lead.contains(i);
          final mine = p.clientId != null && p.clientId == myClientId;
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            decoration: BoxDecoration(
              color: isLead ? C.saffron.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i == turn ? C.saffron : (isLead ? C.saffron.withValues(alpha: .5) : C.line)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(height: 14, child: isLead ? const Crown() : null),
                Text(
                  p.name + (mine ? ' (you)' : ''),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLead ? C.saffron : C.inkSoft,
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic, children: [
                  Text('${p.total}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                  if (round != 0) ...[
                    const SizedBox(width: 4),
                    Text(round > 0 ? '+$round' : '$round',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: round > 0 ? C.mint : C.plum)),
                  ],
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
