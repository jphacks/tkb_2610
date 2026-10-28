import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/features/pono_preview.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';
import 'package:ichinichi_ichizen/widgets/character_rive_view.dart';
import 'package:ichinichi_ichizen/widgets/mikeluna_sprite_view.dart';

Future<void> loaded(WidgetTester t) async {
  for (var i = 0; i < 50; i++) {
    if (find.byKey(const ValueKey('mikeluna-cel')).evaluate().isNotEmpty) {
      return;
    }
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
  expect(find.byKey(const ValueKey('mikeluna-cel')), findsOneWidget);
}

MikelunaCelPainter painter(WidgetTester t) =>
    t.widget<CustomPaint>(find.byKey(const ValueKey('mikeluna-cel'))).painter!
        as MikelunaCelPainter;

final character = Companion(
  id: 'mikeluna-test',
  generation: 1,
  bornAt: _testBirthday,
  kind: 'stage1_self_care',
);
final _testBirthday = DateTime.utc(2026);

void main() {
  testWidgets('ミケルナは全身画で歩き、タップに反応し、停止・おやすみでコマを動かさない', (t) async {
    var taps = 0;
    Future<void> mount({
      bool animate = true,
      bool reduced = false,
      CharacterMotion motion = CharacterMotion.idle,
    }) => t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: CharacterView(
              character: character,
              size: 180,
              walking: true,
              facingRight: false,
              animate: animate,
              motion: motion,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await mount();
    await loaded(t);
    expect(find.byType(CharacterRiveView), findsNothing);
    final atlas = painter(t).atlas;
    final seen = <String>{};
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 80));
      seen.add(painter(t).cel.id);
    }
    expect(seen.length, greaterThan(8));
    await t.tap(find.byType(CharacterView));
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(taps, 1);
    expect(painter(t).cel.id, 'front_happy');
    expect(painter(t).atlas, same(atlas));
    await mount(animate: false);
    final stopped = painter(t).cel.id;
    await t.pump(const Duration(seconds: 1));
    expect(painter(t).cel.id, stopped);
    expect(painter(t).animate, isFalse);
    await mount(motion: CharacterMotion.sleeping);
    expect(painter(t).cel.id, 'front_sleep');
    await t.pump(const Duration(seconds: 1));
    expect(painter(t).cel.id, 'front_sleep');
    await mount(reduced: true);
    expect(painter(t).animate, isFalse);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('設定の見本で手前・奥を含む方向を選べ、おさんぽを試せる', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PonoPreview(initialKind: 'stage1_self_care')),
      ),
    );
    await loaded(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'あるく'));
    await t.pump();
    await t.tap(find.byTooltip('奥へ歩く'));
    for (var i = 0; i < 14; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(painter(t).cel.id, startsWith('back_'));
    await t.tap(find.byTooltip('手前へ歩く'));
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(painter(t).cel.id, startsWith('front_'));
    await t.tap(find.widgetWithText(ChoiceChip, 'おさんぽ'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(MikelunaSpriteView), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
