import 'package:flutter/material.dart';

import '../engine/model.dart';
import 'effects.dart';
import 'theme.dart';

class CardView extends StatelessWidget {
  final GameCard card;
  final double width;
  final bool duplicate;
  final bool fresh;
  const CardView(this.card, {super.key, this.width = 44, this.duplicate = false, this.fresh = false});

  List<Color> get _colors {
    switch (card.t) {
      case CardType.num:
        final h = ((card.v * 47 + 350) % 360).toDouble();
        return [
          HSLColor.fromAHSL(1, h, 0.85, 0.56).toColor(),
          HSLColor.fromAHSL(1, (h + 28) % 360, 0.9, 0.36).toColor(),
        ];
      case CardType.add:
        return const [Color(0xFFFFE27A), Color(0xFFF2A516)];
      case CardType.x2:
        return const [Color(0xFFFFF06A), Color(0xFFFF7A1A), Color(0xFFD9121F)];
      case CardType.sc:
        return const [Color(0xFF8CF5B4), Color(0xFF12A95C)];
      case CardType.flip3:
        return const [Color(0xFFC9B6FF), Color(0xFF6A3DF0)];
      case CardType.freeze:
        return const [Color(0xFFE8FAFF), Color(0xFF39B6E8)];
      case CardType.neg:
        return const [Color(0xFFFF9AD5), Color(0xFFB3137E)];
      case CardType.div2:
        return const [Color(0xFFA9B2FF), Color(0xFF2A2F9A)];
      case CardType.minus:
        return const [Color(0xFF6B6B80), Color(0xFF14141E)];
      case CardType.steal:
        return const [Color(0xFFFFB86B), Color(0xFFC2410C)];
      case CardType.swap:
        return const [Color(0xFF7CEDE9), Color(0xFF0D7780)];
      case CardType.onemore:
        return const [Color(0xFFFFD86B), Color(0xFFD9123A)];
      case CardType.shield:
        return const [Color(0xFFF2F4FA), Color(0xFF8B96AB)];
    }
  }

  IconData? get _icon {
    switch (card.t) {
      case CardType.sc:
        return Icons.favorite;
      case CardType.flip3:
        return Icons.filter_3;
      case CardType.freeze:
        return Icons.ac_unit;
      case CardType.neg:
        return Icons.remove_circle;
      case CardType.x2:
        return Icons.local_fire_department;
      case CardType.steal:
        return Icons.back_hand;
      case CardType.swap:
        return Icons.swap_horiz;
      case CardType.onemore:
        return Icons.plus_one;
      case CardType.shield:
        return Icons.shield;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = width * 1.4;
    final radius = width * 0.16;
    final light = card.t == CardType.add ||
        card.t == CardType.freeze ||
        card.t == CardType.sc ||
        card.t == CardType.shield;
    final asText = card.t == CardType.minus || card.t == CardType.div2;
    final ink = light ? C.stockInk : Colors.white;
    final shadow = [Shadow(color: Colors.black.withValues(alpha: light ? 0.0 : 0.45), offset: Offset(0, width * 0.03), blurRadius: 2)];

    Widget body;
    if (card.isAction && !asText) {
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_icon, size: width * 0.5, color: ink),
        if (width >= 34)
          Padding(
            padding: EdgeInsets.fromLTRB(2, width * 0.04, 2, 0),
            child: Text(card.label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: width * 0.15, fontWeight: FontWeight.w900, color: ink, height: 1.05)),
          ),
      ]);
    } else if (card.t == CardType.x2) {
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (width >= 30) Icon(_icon, size: width * 0.34, color: Colors.white),
        Text('×2',
            style: TextStyle(
                fontSize: width * 0.5, fontWeight: FontWeight.w900, color: Colors.white, height: 1, shadows: shadow)),
      ]);
    } else {
      body = Center(
        child: Text(card.label,
            style: TextStyle(
              fontSize: width * (card.label.length > 2 ? 0.42 : 0.58),
              fontWeight: FontWeight.w900,
              color: ink,
              height: 1,
              shadows: shadow,
            )),
      );
    }

    Widget c = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _colors),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: duplicate ? Colors.white : Colors.white.withValues(alpha: 0.75),
          width: duplicate ? 3 : (width * 0.04).clamp(1.0, 4.0).toDouble(),
        ),
        boxShadow: [
          if (duplicate) const BoxShadow(color: C.red, blurRadius: 16, spreadRadius: 3),
          const BoxShadow(color: Color(0x73000000), offset: Offset(0, 2), blurRadius: 3),
        ],
      ),
      child: body,
    );
    if (card.t == CardType.x2) {
      c = Pulse(color: const Color(0xFFFF6A00), radius: radius, spread: width * 0.45, child: c);
    }
    if (duplicate) c = Transform.rotate(angle: -0.1, child: c);
    if (fresh) {
      c = TweenAnimationBuilder<double>(
        key: ValueKey(card.id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: (t * 2.5).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY((1 - t) * 1.5),
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          ),
        ),
        child: c,
      );
    }
    return c;
  }
}
