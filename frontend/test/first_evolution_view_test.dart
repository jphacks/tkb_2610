import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';
import 'package:ichinichi_ichizen/widgets/character_rive_view.dart';

Future<void> loaded(WidgetTester tester) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (find.byType(rive.RiveWidget).evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.byType(rive.RiveWidget), findsOneWidget);
}

void main() {
  testWidgets('Riveを使う第一進化6体でモデル、タッチ、停止とおやすみを扱う', (t) async {
    var taps = 0;
    for (final category in categoryIds) {
      if (category == 'self_care') continue; // Covered by mikeluna_sprite_test.
      final kind = 'stage1_$category';
      final character = Companion(
        id: kind,
        generation: 1,
        bornAt: DateTime.utc(2026),
        kind: kind,
      );
      Future<void> mount({
        bool animate = true,
        CharacterMotion motion = CharacterMotion.idle,
      }) => t.pumpWidget(
        MaterialApp(
          home: Center(
            child: CharacterView(
              character: character,
              size: 180,
              motion: motion,
              animate: animate,
              walking: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await mount();
      await loaded(t);
      final view = find.byType(rive.RiveWidget);
      final player = t.widget<rive.RiveWidget>(view).controller;
      expect(player.artboard.name, kind);
      expect(player.active, isTrue);
      final before = taps;
      await t.tapAt(t.getCenter(find.byType(CharacterView)));
      await t.pump(const Duration(milliseconds: 300));
      expect(taps, before + 1);
      expect(
        t.widget<CharacterRiveView>(find.byType(CharacterRiveView)).motion,
        CharacterMotion.tapped,
      );
      expect(t.widget<rive.RiveWidget>(view).controller, same(player));
      await t.pump(const Duration(seconds: 2));
      expect(
        t.widget<CharacterRiveView>(find.byType(CharacterRiveView)).motion,
        CharacterMotion.idle,
      );
      await mount(animate: false);
      await t.pump();
      expect(player.active, isFalse);
      final body = player.artboard.component('Body')!;
      final scale = body.scaleY;
      await t.pump(const Duration(seconds: 1));
      await mount(animate: false);
      expect(body.scaleY, scale);
      await mount(motion: CharacterMotion.sleeping);
      await t.pump();
      expect(player.active, isFalse);
      body.dispose();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull, reason: kind);
    }
  });

  testWidgets('同じ表示枠のキャラクターを連続で切り替えても最後のモデルを表示する', (t) async {
    for (final kind in [
      'stage1_courage',
      'stage1_honesty',
      'stage1_cooperation',
    ]) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: CharacterView(
              character: Companion(
                id: 'same',
                generation: 1,
                bornAt: DateTime.utc(2026),
                kind: kind,
              ),
              size: 180,
            ),
          ),
        ),
      );
    }
    await loaded(t);
    expect(
      t
          .widget<rive.RiveWidget>(find.byType(rive.RiveWidget))
          .controller
          .artboard
          .name,
      'stage1_cooperation',
    );
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('最終進化は既存の画像と動きを引き続き使う', (t) async {
    const kind = 'stage2_environment_self_care';
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: CharacterView(
            character: Companion(
              id: 'second',
              generation: 1,
              bornAt: DateTime.utc(2026),
              kind: kind,
            ),
            size: 180,
          ),
        ),
      ),
    );
    expect(find.byType(CharacterRiveView), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(characterRiveSpec(kind), isNull);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
