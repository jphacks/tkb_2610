import 'dart:math';
import 'package:flutter/painting.dart';

/// Random destinations with pauses, smooth acceleration and a shared room boundary.
class RoomWander {
  RoomWander({Random? random, this.turnDuration = 0})
    : _random = random ?? Random();
  final Random _random;
  final double turnDuration;
  Offset? _position;
  Offset _from = Offset.zero, _to = Offset.zero;
  double _elapsed = 0, _duration = 2;
  bool _moving = false, _preparing = false, _paused = false;
  double _resumeDelay = 0;
  bool facingRight = false;
  bool get moving => _moving && !_paused && _resumeDelay <= 0;
  bool get preparing => _preparing || _resumeDelay > 0;
  Offset get direction {
    final delta = _to - _from;
    return delta.distance > 1 ? delta / delta.distance : const Offset(-1, 0);
  }

  double get speed {
    if (!moving) return 0;
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    return (_to - _from).distance * 6 * t * (1 - t) / _duration;
  }

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
    _moving = false;
    _preparing = false;
    _paused = false;
    _resumeDelay = 0;
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
    if (!enabled) {
      // Layout sanitation calls advance(0); it is not a playback pause.
      if (seconds > 0) _paused = true;
      return;
    }
    if (_paused) {
      _paused = false;
      if (_moving) _resumeDelay = turnDuration;
    }
    if (_resumeDelay > 0) {
      _resumeDelay = max(0, _resumeDelay - seconds);
      return;
    }
    _elapsed += seconds;
    if (_elapsed >= _duration) {
      _position = _moving ? _to : position;
      _elapsed = 0;
      if (_preparing) {
        _preparing = false;
        _moving = true;
        _duration = (2.5 + (_to - _from).distance / 60).clamp(2.5, 5.5);
      } else if (_moving) {
        _moving = false;
        _duration = 1.5 + _random.nextDouble() * 2;
      } else {
        _from = position;
        _to = _destination(bounds);
        _moving = (_to - _from).distance > 1;
        if ((_to.dx - _from.dx).abs() > 1) {
          facingRight = _to.dx > _from.dx;
        }
        _duration = (2.5 + (_to - _from).distance / 60).clamp(2.5, 5.5);
        if (_moving && turnDuration > 0) {
          _moving = false;
          _preparing = true;
          _duration = turnDuration;
        }
      }
    }
    if (_moving) {
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
