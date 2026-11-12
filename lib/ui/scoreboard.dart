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

/// A slim strip of every player's total, highest first, crown on the leader.
class Scoreboard extends StatelessWidget {
  final GameState state;
  final String? myClientId;
  const Scoreboard({super.key, required this.state, this.myClientId});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final lead = leaders(s);
    final order = List.generate(s.players.length, (i) => i)
      ..sort((a, b) => s.players[b].total - s.players[a].total);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: order.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, k) {
          final i = order[k];
          final p = s.players[i];
          final col = playerColor(i);
          final isLead = lead.contains(i);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: col.withValues(alpha: isLead ? 0.22 : 0.10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: col.withValues(alpha: isLead ? 1 : 0.5), width: isLead ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isLead) const Padding(padding: EdgeInsets.only(right: 5), child: Crown(size: 16)),
              Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col)),
              const SizedBox(width: 6),
              Text('${p.total}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          );
        },
      ),
    );
  }
}
