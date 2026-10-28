import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/mikeluna_animation.dart';
import 'package:ichinichi_ichizen/core/room_wander.dart';
import 'package:ichinichi_ichizen/data/mikeluna_sprites.dart';
import 'package:ichinichi_ichizen/data/models.dart';

void main() {
  void request(
    MikelunaPlayback p,
    MikelunaHeading heading, {
    bool walking = true,
    CharacterMotion motion = CharacterMotion.idle,
    double pace = 1,
  }) =>
      p.request(walking: walking, heading: heading, motion: motion, pace: pace);

  test('左右反転は足を着いて正面の中間画を通り、幅を潰さない', () {
    final p = MikelunaPlayback();
    request(p, MikelunaHeading.left);
    p.advance(.5);
    expect(p.activity, MikelunaActivity.walking);
    request(p, MikelunaHeading.right);
    final activities = <MikelunaActivity>[];
    final cels = <String>[];
    for (var i = 0; i < 150; i++) {
      p.advance(.01);
      activities.add(p.activity);
      cels.add(p.cel.id);
      expect(p.cel.scaleX, greaterThan(.95));
      expect(mikelunaCelIds, contains(p.cel.id));
    }
    expect(
      activities.indexOf(MikelunaActivity.settling),
      lessThan(activities.indexOf(MikelunaActivity.turning)),
    );
    expect(cels, contains('front_center'));
    expect(cels, contains('turn_front'));
    expect(p.activity, MikelunaActivity.walking);
    expect(p.cel.mirrored, isTrue);
  });

  test('4方向で歩行画が変わり、速度がコマ送りに反映され、停止してから表情が変わる', () {
    for (final entry in const {
      MikelunaHeading.left: 'side_',
      MikelunaHeading.right: 'side_',
      MikelunaHeading.front: 'front_',
      MikelunaHeading.back: 'back_',
    }.entries) {
      final p = MikelunaPlayback();
      request(p, entry.key);
      p.advance(.4);
      expect(p.cel.id, startsWith(entry.value));
      request(p, entry.key, walking: false);
      p.advance(.25);
      expect(p.activity, MikelunaActivity.resting);
      expect(p.cel.id, endsWith('_idle'));
      request(p, entry.key, motion: CharacterMotion.tapped);
      p.advance(1);
      expect(p.cel.id, 'front_happy');
      request(p, entry.key, motion: CharacterMotion.sleeping);
      p.advance(1);
      expect(p.cel.id, 'front_sleep');
    }
    final slow = MikelunaPlayback(), fast = MikelunaPlayback();
    request(slow, MikelunaHeading.left, pace: .5);
    request(fast, MikelunaHeading.left, pace: 1);
    slow.advance(.5);
    fast.advance(.5);
    expect(fast.walkPhase, closeTo(slow.walkPhase * 2, .001));
  });

  test('方向を連続変更しても隣の向きを経由し、素材のないコマにならない', () {
    final p = MikelunaPlayback();
    request(p, MikelunaHeading.left);
    p.advance(.3);
    for (var i = 0; i < 400; i++) {
      if (i % 7 == 0) request(p, MikelunaHeading.values[(i ~/ 7) % 4]);
      final before = p.turnNode;
      p.advance(.01);
      final distance = (p.turnNode - before + 10) % 10;
      expect([0, 1, 9], contains(distance));
      expect(mikelunaCelIds, contains(p.cel.id));
    }
    expect(
      MikelunaHeading.fromDirection(const Offset(1, 1)),
      MikelunaHeading.front,
    );
    expect(
      MikelunaHeading.fromDirection(const Offset(-1, -1)),
      MikelunaHeading.back,
    );
  });

  test('部屋は向きを決めてから待機し、タップ後もその場で振り向いてから移動を再開する', () {
    final w = RoomWander(random: Random(9), turnDuration: .68);
    const bounds = Rect.fromLTRB(0, 0, 120, 150);
    const origin = Offset(60, 75);
    w.advance(2.01, bounds, origin);
    expect(w.preparing, isTrue);
    expect(w.moving, isFalse);
    expect(w.position, origin);
    expect(w.speed, 0);
    w.advance(.4, bounds, origin);
    expect(w.position, origin);
    w.advance(.3, bounds, origin);
    w.advance(.4, bounds, origin);
    expect(w.moving, isTrue);
    expect(w.speed, greaterThan(0));
    final stopped = w.position;
    w.advance(.1, bounds, origin, enabled: false);
    w.advance(.3, bounds, origin);
    expect(w.position, stopped);
    expect(w.preparing, isTrue);
    w.advance(.4, bounds, origin);
    w.advance(.1, bounds, origin);
    expect((w.position - stopped).distance, greaterThan(0));
  });
}
