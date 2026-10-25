import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/character_animation.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';

void main() {
  test('全57形態で左右移動が範囲内に収まり、周期の終わりに中央へ戻る', () {
    expect(characterForms.length, 57);
    for (final form in characterForms.values) {
      final xs = <double>[];
      for (var tick = 0; tick <= 240; tick++) {
        final pose = characterPose(
          form: form,
          seconds: tick / 10,
          travelSeconds: tick / 10,
          motion: CharacterMotion.idle,
          travel: 42,
        );
        expect(pose.x.abs(), lessThanOrEqualTo(42));
        expect(pose.y.isFinite && pose.rotation.isFinite, isTrue);
        expect(pose.scaleX, inInclusiveRange(.9, 1.1));
        expect(pose.scaleY, inInclusiveRange(.9, 1.1));
        xs.add(pose.x);
      }
      expect(xs.first, 0);
      expect(xs.last, 0);
      expect(xs, contains(42));
      expect(xs, contains(-42));
    }
  });

  test('最終進化は同じ種族の動きを引き継ぎ、別種族では動きが異なる', () {
    CharacterPose sample(String kind) => characterPose(
      form: characterForm(kind),
      seconds: 4.2,
      travelSeconds: 4.2,
      motion: CharacterMotion.idle,
      travel: 30,
    );
    for (final first in categoryIds) {
      final before = sample('stage1_$first');
      for (final second in categoryIds) {
        final after = sample('stage2_${first}_$second');
        expect(
          [after.y, after.rotation, after.scaleX],
          [before.y, before.rotation, before.scaleX],
        );
      }
    }
    expect(sample('stage1_kindness').y, isNot(sample('stage1_honesty').y));
    final sleep = characterPose(
      form: characterForm('base_01'),
      seconds: 4,
      travelSeconds: 4,
      motion: CharacterMotion.sleeping,
      travel: 50,
    );
    expect([sleep.x, sleep.y, sleep.rotation], [0, 0, 0]);
  });

  testWidgets('移動先もタップでき、動きを減らす設定では完全に停止する', (t) async {
    var tapped = 0;
    final c = Companion(
      id: 'test',
      generation: 1,
      bornAt: DateTime.utc(2026),
      kind: 'stage1_environment',
    );
    Future<void> mount({bool reduced = false}) => t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: CharacterView(
              character: c,
              size: 120,
              wanderDistance: 60,
              onTap: () => tapped++,
            ),
          ),
        ),
      ),
    );
    await mount();
    await t.pump();
    for (var i = 0; i < 65; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tapAt(
      t.getCenter(find.byType(CharacterView)) + const Offset(60, 0),
    );
    expect(tapped, 1);
    await mount(reduced: true);
    await t.pump(const Duration(seconds: 1));
    final transforms = t.widgetList<Transform>(
      find.descendant(
        of: find.byType(CharacterView),
        matching: find.byType(Transform),
      ),
    );
    for (final transform in transforms) {
      expect(transform.transform, Matrix4.identity());
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
