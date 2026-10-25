import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/app.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';
import 'repository_test.dart' show MemoryStore;

void main() {
  for (final kind in ['base_01', 'stage2_environment_self_care']) {
    testWidgets('投稿中も$kindの位置と大きさを保ち、キーボードの後ろで動き続ける', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final controller = GameController(DemoRepository(MemoryStore()));
      await controller.initialize();
      await controller.register('はる');
      final initial = controller.snapshot!.current;
      controller.snapshot = GameSnapshot(
        name: 'はる',
        characters: [
          initial.copyWith(kind: kind, evolution: characterForm(kind).stage),
        ],
      );
      await t.pumpWidget(YoinokoApp(controller: controller));
      await t.pump();
      final portrait = find.byType(CharacterView);
      final before = t.getRect(portrait);
      await t.tap(find.byKey(const ValueKey('tab-2')));
      await t.pump();
      expect(controller.composing, isTrue);
      expect(t.getRect(portrait), before);
      expect(find.byKey(const ValueKey('character-speech')), findsOneWidget);
      // The sheet owns keyboard avoidance. The background room stays full size.
      t.view.viewInsets = const FakeViewPadding(bottom: 240);
      await t.pump();
      expect(t.getRect(portrait).size, before.size);
      expect(t.getRect(portrait).topLeft, before.topLeft);
      var moved = false;
      for (var i = 0; i < 180; i++) {
        await t.pump(const Duration(milliseconds: 100));
        moved |= (t.getRect(portrait).topLeft - before.topLeft).distance > 1;
      }
      expect(moved, isTrue);
      expect(t.widget<CharacterView>(portrait).size, before.width);
      t.view.resetViewInsets();
      await t.pump();
      await t.tap(find.byTooltip('閉じる'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(controller.composing, isFalse);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
