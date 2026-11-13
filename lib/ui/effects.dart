import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../profile.dart';
import 'theme.dart';

/// Drifting specks: snow falling for Freeze, embers rising for ×2.
class Particles extends StatefulWidget {
  final Color color;
  final bool up;
  const Particles({super.key, required this.color, this.up = false});

  @override
  State<Particles> createState() => _ParticlesState();
}

class _ParticlesState extends State<Particles> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) =>
                CustomPaint(painter: _ParticlePainter(_c.value, widget.color, widget.up), size: Size.infinite),
          ),
        ),
      );
}

class _ParticlePainter extends CustomPainter {
  final double t;
  final Color color;
  final bool up;
  _ParticlePainter(this.t, this.color, this.up);

  double _frac(double v) => v - v.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 46; i++) {
      final speed = 1 + (i % 3);
      var y = _frac(i * 0.293 + t * speed);
      if (up) y = 1 - y;
      final sway = sin((t * 2 * pi * speed) + i) * 12;
      final x = _frac(i * 0.618) * size.width + sway;
      final r = 2.0 + _frac(i * 0.71) * 4.5;
      final fade = up ? y : 1 - y * 0.4;
      canvas.drawCircle(
        Offset(x, y * size.height),
        r,
        Paint()..color = color.withValues(alpha: (0.25 + 0.6 * _frac(i * 0.37)) * fade.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

/// A glow that breathes around its child. Used for the ×2 card.
class Pulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double spread;
  const Pulse({super.key, required this.child, required this.color, this.radius = 8, this.spread = 14});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.55 + 0.4 * _c.value),
                blurRadius: widget.spread * (0.5 + _c.value),
                spreadRadius: widget.spread * 0.15 * _c.value,
              ),
            ],
          ),
          child: child,
        ),
      );
}

/// The HIT button: glowing, and it never quite sits still.
class HitButton extends StatefulWidget {
  final VoidCallback onPressed;
  const HitButton({super.key, required this.onPressed});

  @override
  State<HitButton> createState() => _HitButtonState();
}

class _HitButtonState extends State<HitButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // A quick shake in the first third of each cycle, then rest.
          final shake = t < 0.35 ? sin(t / 0.35 * pi * 6) * 0.045 * (1 - t / 0.35) : 0.0;
          final glow = 0.5 + 0.5 * sin(t * 2 * pi);
          return Transform.rotate(
            angle: shake,
            child: Transform.scale(
              scale: 1 + 0.04 * glow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: C.red.withValues(alpha: 0.55 + 0.4 * glow), blurRadius: 14 + 18 * glow, spreadRadius: 1 + 3 * glow),
                    BoxShadow(color: C.saffron.withValues(alpha: 0.35 * glow), blurRadius: 30),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: C.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: C.saffron, width: 2.5),
            ),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onPressed();
          },
          child: const Text('HIT'),
        ),
      );
}

/// The glow behind the table, in the colours the player picked.
class TableBg extends StatelessWidget {
  final Widget child;
  const TableBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Profile.I,
        child: child,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.9),
              radius: 1.3,
              colors: Profile.I.tableTheme.colors,
              stops: const [0, 0.55, 1],
            ),
          ),
          child: child,
        ),
      );
}
