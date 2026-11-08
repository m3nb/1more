import 'package:flutter/material.dart';

import '../engine/model.dart';
import 'theme.dart';

class CardView extends StatelessWidget {
  final GameCard card;
  final double width;
  final bool duplicate;
  final bool fresh;
  const CardView(this.card, {super.key, this.width = 44, this.duplicate = false, this.fresh = false});

  Color get _bg {
    switch (card.t) {
      case CardType.num:
        return C.stock;
      case CardType.add:
      case CardType.x2:
        return C.saffron;
      case CardType.sc:
        return C.mint;
      case CardType.flip3:
        return C.violet;
      case CardType.freeze:
        return C.ice;
      case CardType.neg:
        return C.plum;
    }
  }

  String get _icon {
    switch (card.t) {
      case CardType.sc:
        return '↺';
      case CardType.flip3:
        return '3';
      case CardType.freeze:
        return '✱';
      case CardType.neg:
        return '−';
      default:
        return card.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = width * 1.4;
    final numColor = HSLColor.fromAHSL(1, ((card.v * 29 + 190) % 360).toDouble(), 0.62, 0.34).toColor();
    Widget body;
    if (card.isAction) {
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_icon, style: TextStyle(fontSize: width * 0.42, fontWeight: FontWeight.w900, color: C.stockInk, height: 1)),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(card.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: width * 0.18, fontWeight: FontWeight.w800, color: C.stockInk, height: 1.05)),
        ),
      ]);
    } else {
      body = Center(
        child: Text(card.label,
            style: TextStyle(
              fontSize: width * (card.label.length > 2 ? 0.42 : 0.55),
              fontWeight: FontWeight.w900,
              color: card.isNumber ? numColor : C.stockInk,
              height: 1,
            )),
      );
    }
    Widget c = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(width * 0.16),
        border: duplicate ? Border.all(color: C.coral, width: 3) : null,
        boxShadow: const [BoxShadow(color: Color(0x59000000), offset: Offset(0, 2))],
      ),
      child: body,
    );
    if (duplicate) c = Transform.rotate(angle: -0.1, child: c);
    if (fresh) {
      c = TweenAnimationBuilder<double>(
        key: ValueKey(card.id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (_, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - t) * -14), child: child),
        ),
        child: c,
      );
    }
    return c;
  }
}
