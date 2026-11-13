import 'dart:math';

/// A small generator that gives the same sequence on every platform, so
/// the daily challenge deals the same deck to everyone.
class SeededRandom implements Random {
  int _s;
  SeededRandom(int seed) : _s = (seed % 2147483646) + 1;

  int _next() {
    _s = (_s * 48271) % 2147483647;
    return _s;
  }

  @override
  int nextInt(int max) => _next() % max;

  @override
  double nextDouble() => _next() / 2147483647;

  @override
  bool nextBool() => _next().isEven;
}
