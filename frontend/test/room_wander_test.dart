import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/room_wander.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';
import 'package:ichinichi_ichizen/widgets/room_character.dart';

void main() {
  test('ランダムな上下左右・斜め移動は境界内に収まり、停止・サイズ変更に対応する', () {
    final wander = RoomWander(random: Random(42));
    const bounds = Rect.fromLTRB(16, 150, 200, 450);
    const origin = Offset(100, 300);
    final directions = <String>{};
    for (var i = 0; i < 18000; i++) {
      final before = wander.position;
      wander.advance(1 / 60, bounds, origin);
      final after = wander.position;
      expect(after.dx, inInclusiveRange(bounds.left, bounds.right));
      expect(after.dy, inInclusiveRange(bounds.top, bounds.bottom));
      if (i > 0) {
        final delta = after - before;
        if (delta.distance > .001) {
          directions.add(
            '${delta.dx.abs() < .0001 ? 0 : delta.dx.sign},${delta.dy.abs() < .0001 ? 0 : delta.dy.sign}',
          );
        }
        expect(delta.distance, lessThan(4));
      }
    }
    expect(directions.length, 8);
    final stopped = wander.position;
    wander.advance(10, bounds, origin, enabled: false);
    expect(wander.position, stopped);
    const smaller = Rect.fromLTRB(20, 160, 40, 190);
    wander.advance(0, smaller, origin, enabled: false);
    expect(wander.position.dx, inInclusiveRange(20, 40));
    expect(wander.position.dy, inInclusiveRange(160, 190));
  });

  testWidgets('名前とセリフがキャラと同じ距離だけ追従し、移動先もタップできる', (t) async {
    var taps = 0;
    final character = Companion(
      id: 'test',
      generation: 1,
      bornAt: DateTime.utc(2026),
    );
    Widget room({bool roam = true, bool reduced = false}) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: SizedBox(
            width: 390,
            height: 680,
            child: RoomCharacter(
              character: character,
              size: 132,
              top: 350,
              speech: 'ここにいるよ',
              motion: CharacterMotion.idle,
              roam: roam,
              random: Random(9),
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    final speech = find.byKey(const ValueKey('character-speech'));
    final name = find.byKey(const ValueKey('character-name'));
    final image = find.byType(CharacterView);
    await t.pumpWidget(room());
    await t.pump();
    final starts = [t.getCenter(image), t.getCenter(speech), t.getCenter(name)];
    var changedX = false, changedY = false;
    for (var i = 0; i < 200; i++) {
      await t.pump(const Duration(milliseconds: 100));
      final delta = t.getCenter(image) - starts[0];
      expect(
        (t.getCenter(speech) - starts[1] - delta).distance,
        lessThan(.001),
      );
      expect((t.getCenter(name) - starts[2] - delta).distance, lessThan(.001));
      changedX |= delta.dx.abs() > 1;
      changedY |= delta.dy.abs() > 1;
      expect(t.getRect(speech).left, greaterThanOrEqualTo(0));
      expect(t.getRect(name).bottom, lessThanOrEqualTo(680));
    }
    expect(changedX && changedY, isTrue);
    await t.tap(image);
    expect(taps, 1);
    await t.pumpWidget(room(roam: false));
    final stopped = t.getCenter(image);
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.getCenter(image), stopped);
    await t.pumpWidget(room(reduced: true));
    final reduced = t.getCenter(image);
    await t.pump(const Duration(seconds: 10));
    expect(t.getCenter(image), reduced);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
