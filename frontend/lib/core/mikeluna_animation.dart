import 'dart:math' as math;
import 'package:flutter/painting.dart';
import '../data/models.dart';

/// Four walking views; intermediate views are reserved for a planted turn.
enum MikelunaHeading {
  front(0),
  right(2),
  back(5),
  left(8);

  const MikelunaHeading(this.turnNode);
  final int turnNode;

  static MikelunaHeading fromDirection(Offset direction) {
    if (direction.distanceSquared < .001) return front;
    if (direction.dy.abs() > direction.dx.abs() * .8) {
      return direction.dy > 0 ? front : back;
    }
    return direction.dx > 0 ? right : left;
  }
}

enum MikelunaActivity { resting, walking, settling, turning }

class MikelunaCel {
  const MikelunaCel(
    this.id, {
    this.mirrored = false,
    this.y = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });
  final String id;
  final bool mirrored;
  final double y, scaleX, scaleY, rotation;
}

/// Playback is independent of a renderer and advances only on the app ticker.
/// No body-part transforms, crossfades or zero-width mirror transitions.
class MikelunaPlayback {
  static const cycleSeconds = 1.28;
  static const turnStepSeconds = .09;
  static const settleSeconds = .16;
  var activity = MikelunaActivity.resting;
  var _motion = CharacterMotion.idle;
  var _wantedWalk = false;
  var _initialized = false;
  var _node = 0, _target = 0;
  double _time = 0, _phaseTime = 0, _walkPhase = 0, _pace = 1;
  double _settleFrom = 0, _settleTo = 0;
  int get turnNode => _node;
  double get walkPhase => _walkPhase;

  void request({
    required bool walking,
    required MikelunaHeading heading,
    required CharacterMotion motion,
    double pace = 1,
  }) {
    _motion = motion;
    _wantedWalk = walking && motion == CharacterMotion.idle;
    _target = motion == CharacterMotion.idle ? heading.turnNode : 0;
    _pace = pace.clamp(.25, 1.8);
    if (!_initialized || motion == CharacterMotion.sleeping) {
      _node = _target;
      _initialized = true;
      activity = MikelunaActivity.resting;
      _phaseTime = 0;
      _walkPhase = 0;
    }
  }

  /// Static portraits still reflect explicit mood changes without playing a turn.
  void snapToRequestedPose() {
    _node = _target;
    activity = MikelunaActivity.resting;
    _phaseTime = 0;
    _walkPhase = 0;
  }

  void advance(double seconds) {
    if (_motion == CharacterMotion.sleeping) return;
    var remaining = seconds.clamp(0.0, 2.0);
    // Small steps keep rapid direction changes and slow/fast frames equivalent.
    while (remaining > .000001) {
      final step = math.min(remaining, 1 / 120);
      _advanceStep(step);
      remaining -= step;
    }
  }

  void _enter(MikelunaActivity next) {
    activity = next;
    _phaseTime = 0;
  }

  void _advanceStep(double dt) {
    _time += dt;
    _phaseTime += dt;
    switch (activity) {
      case MikelunaActivity.walking:
        if (!_wantedWalk || _node != _target) {
          _settleFrom = _walkPhase;
          _settleTo = ((_walkPhase * 4).floor() + 1) / 4;
          _enter(MikelunaActivity.settling);
        } else {
          _walkPhase = (_walkPhase + dt * _pace / cycleSeconds) % 1;
        }
      case MikelunaActivity.settling:
        final t = (_phaseTime / settleSeconds).clamp(0.0, 1.0);
        final eased = t * t * (3 - 2 * t);
        _walkPhase = (_settleFrom + (_settleTo - _settleFrom) * eased) % 1;
        if (t >= 1) _enter(MikelunaActivity.resting);
      case MikelunaActivity.turning:
        if (_node == _target) {
          _enter(MikelunaActivity.resting);
        } else if (_phaseTime >= turnStepSeconds) {
          final clockwise = (_target - _node + 10) % 10;
          _node = (_node + (clockwise <= 5 ? 1 : -1) + 10) % 10;
          _phaseTime = 0;
        }
      case MikelunaActivity.resting:
        if (_node != _target) {
          _enter(MikelunaActivity.turning);
        } else if (_wantedWalk) {
          _walkPhase = 0;
          _enter(MikelunaActivity.walking);
        }
    }
  }

  MikelunaCel get cel {
    if (_motion == CharacterMotion.sleeping) {
      return const MikelunaCel('front_sleep');
    }
    if (activity == MikelunaActivity.turning) {
      return _turnCel(_node);
    }
    if (activity == MikelunaActivity.walking ||
        activity == MikelunaActivity.settling) {
      final side = _node == 2 || _node == 8;
      final count = side ? 16 : 8;
      final frame = _walkFrame(count);
      final prefix = side ? 'side' : (_node == 5 ? 'back' : 'front');
      final wave = math.sin(_walkPhase * math.pi * 4);
      final fade = activity == MikelunaActivity.settling
          ? 1 - (_phaseTime / settleSeconds).clamp(0.0, 1.0)
          : 1.0;
      return MikelunaCel(
        '${prefix}_${frame.toString().padLeft(2, '0')}',
        mirrored: _node == 2,
        y: -wave * wave * .009 * fade,
        scaleX: 1 + math.cos(_walkPhase * math.pi * 8) * .006 * fade,
        scaleY: 1 - math.cos(_walkPhase * math.pi * 8) * .012 * fade,
        rotation: math.sin(_walkPhase * math.pi * 2) * .006 * fade,
      );
    }
    final breath = math.sin(_time * math.pi * 2 / 3.4);
    if (_node == 0 &&
        (_motion == CharacterMotion.happy ||
            _motion == CharacterMotion.tapped)) {
      return MikelunaCel(
        'front_happy',
        y: -math.pow(math.sin(_time * math.pi * 1.7), 2) * .012,
        scaleY: 1 + breath * .008,
        rotation: breath * .009,
      );
    }
    final blink = _time % 4.6 >= 4.38;
    final id = switch (_node) {
      2 || 8 => blink ? 'side_blink' : 'side_idle',
      5 => 'back_idle',
      _ => blink ? 'front_blink' : 'front_idle',
    };
    final energy = _motion == CharacterMotion.lowEnergy ? .4 : 1.0;
    return MikelunaCel(
      id,
      mirrored: _node == 2,
      scaleY: 1 + breath * .004 * energy,
    );
  }

  int _walkFrame(int count) {
    if (count == 8) return (_walkPhase * 8).floor().clamp(0, 7);
    // Hold major poses a little longer, with shorter in-betweens.
    final quarter = (_walkPhase * 4).floor().clamp(0, 3);
    final time = (_walkPhase * cycleSeconds) % .32;
    final local = time < .12
        ? 0
        : time < .18
        ? 1
        : time < .24
        ? 2
        : 3;
    return quarter * 4 + local;
  }

  MikelunaCel _turnCel(int node) => switch (node) {
    0 => const MikelunaCel('front_center'),
    1 => const MikelunaCel('turn_front', mirrored: true),
    2 => const MikelunaCel('side_idle', mirrored: true),
    3 => const MikelunaCel('turn_back', mirrored: true),
    4 => const MikelunaCel('back_turn', mirrored: true),
    5 => const MikelunaCel('back_center'),
    6 => const MikelunaCel('back_turn'),
    7 => const MikelunaCel('turn_back'),
    8 => const MikelunaCel('side_idle'),
    _ => const MikelunaCel('turn_front'),
  };
}
