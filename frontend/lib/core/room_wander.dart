import 'dart:math';
import 'package:flutter/painting.dart';

/// Random destinations with pauses, smooth acceleration and a shared room boundary.
class RoomWander {
  RoomWander({Random? random}) : _random = random ?? Random();
  final Random _random;
  Offset? _position;
  Offset _from = Offset.zero, _to = Offset.zero;
  double _elapsed = 0, _duration = 2;
  bool moving = false, facingRight = false;
  Offset get position => _position ?? Offset.zero;

  static Offset constrain(Offset point, Rect bounds) => Offset(
    point.dx.clamp(bounds.left, bounds.right),
    point.dy.clamp(bounds.top, bounds.bottom),
  );

  void reset(Offset origin, Rect bounds) {
    _position = constrain(origin, bounds);
    _from = _to = position;
    _elapsed = 0;
    _duration = 2;
    moving = false;
  }

  void advance(
    double seconds,
    Rect bounds,
    Offset origin, {
    bool enabled = true,
  }) {
    if (_position == null) reset(origin, bounds);
    final safe = constrain(position, bounds);
    if (safe != position || constrain(_to, bounds) != _to) {
      reset(safe, bounds);
    }
    if (!enabled) return;
    _elapsed += seconds;
    if (_elapsed >= _duration) {
      _position = moving ? _to : position;
      _elapsed = 0;
      if (moving) {
        moving = false;
        _duration = 1.5 + _random.nextDouble() * 2;
      } else {
        _from = position;
        _to = _destination(bounds);
        moving = (_to - _from).distance > 1;
        if ((_to.dx - _from.dx).abs() > 1) {
          facingRight = _to.dx > _from.dx;
        }
        _duration = (2.5 + (_to - _from).distance / 60).clamp(2.5, 5.5);
      }
    }
    if (moving) {
      final t = (_elapsed / _duration).clamp(0.0, 1.0);
      _position = constrain(
        Offset.lerp(_from, _to, t * t * (3 - 2 * t))!,
        bounds,
      );
    }
  }

  Offset _destination(Rect bounds) {
    const directions = [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
      Offset(1, 1),
      Offset(1, -1),
      Offset(-1, 1),
      Offset(-1, -1),
    ];
    for (var attempt = 0; attempt < 16; attempt++) {
      final direction = directions[_random.nextInt(directions.length)];
      final distance = .3 + _random.nextDouble() * .5;
      final candidate = constrain(
        position +
            Offset(
              direction.dx * bounds.width * distance,
              direction.dy * bounds.height * distance,
            ),
        bounds,
      );
      if ((candidate - position).distance > 6) return candidate;
    }
    return position;
  }
}
