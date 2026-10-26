import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';
import 'package:ichinichi_ichizen/widgets/pono_view.dart';
import 'package:ichinichi_ichizen/features/settings.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'repository_test.dart' show MemoryStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('実際のRiveファイルで目と体と玉が独立して動き、全状態へ遷移できる', () async {
    expect(await rive.RiveNative.init(), isTrue);
    final file = (await rive.File.decode(
      await io.File('assets/animations/pono.riv').readAsBytes(),
      riveFactory: rive.Factory.flutter,
    ))!;
    final player = rive.RiveWidgetController(file);
    final data = player.dataBind(rive.DataBind.auto());
    final mode = data.number('mode')!;
    final look = data.number('lookX')!;
    final body = player.artboard.component('Body')!;
    final eyes = player.artboard.component('Eyes')!;
    final orb = player.artboard.component('Orb')!;
    final direction = player.artboard.component('Look direction')!;
    addTearDown(() {
      direction.dispose();
      orb.dispose();
      eyes.dispose();
      body.dispose();
      mode.dispose();
      look.dispose();
      player.dispose();
      data.dispose();
      file.dispose();
    });
    void frames(int count) {
      for (var f = 0; f < count; f++) {
        player.stateMachine.advanceAndApply(1 / 60);
      }
    }

    expect(player.artboard.animationCount(), 6);
    final bodyHeights = <double>[],
        eyeScales = <double>[],
        orbHeights = <double>[];
    for (var f = 0; f < 480; f++) {
      frames(1);
      bodyHeights.add(body.scaleY);
      eyeScales.add(eyes.scaleY);
      orbHeights.add(orb.y);
    }
    expect(eyeScales.reduce((a, b) => a < b ? a : b), lessThan(.15));
    expect(eyeScales.reduce((a, b) => a > b ? a : b), closeTo(1, .01));
    expect(bodyHeights.toSet().length, greaterThan(100));
    expect(orbHeights.toSet().length, greaterThan(100));
    for (final motion in CharacterMotion.values) {
      mode.value = ponoMotionMode(motion, walking: false).toDouble();
      frames(24);
      expect(body.scaleY.isFinite, isTrue);
    }
    mode.value = 1;
    look.value = -3;
    frames(24);
    expect(direction.x, closeTo(-3, .01));
    look.value = 3;
    frames(1);
    expect(direction.x, closeTo(3, .01));
    mode.value = 3;
    final jumps = <double>[];
    for (var f = 0; f < 120; f++) {
      frames(1);
      jumps.add(body.y);
    }
    expect(jumps.reduce((a, b) => a < b ? a : b), lessThan(420));
  });

  testWidgets('タップで笑顔になり、再生を保って戻り、動きを減らす設定では停止する', (t) async {
    var callbacks = 0;
    final character = Companion(
      id: 'pono',
      generation: 1,
      bornAt: DateTime.utc(2026),
      kind: 'base_01',
    );
    Future<void> mount({
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
              motion: motion,
              onTap: () => callbacks++,
            ),
          ),
        ),
      ),
    );
    await mount();
    // Allow the real native decoder to finish outside the fake widget clock.
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pump();
    final view = find.byType(rive.RiveWidget);
    expect(view, findsOneWidget);
    final player = t.widget<rive.RiveWidget>(view).controller;
    expect(player.active, isTrue);
    await t.tapAt(t.getCenter(find.byType(CharacterView)));
    await t.pump(const Duration(milliseconds: 300));
    expect(callbacks, 1);
    expect(
      t.widget<PonoView>(find.byType(PonoView)).motion,
      CharacterMotion.tapped,
    );
    expect(t.widget<rive.RiveWidget>(view).controller, same(player));
    await t.pump(const Duration(seconds: 2));
    expect(
      t.widget<PonoView>(find.byType(PonoView)).motion,
      CharacterMotion.idle,
    );
    await mount(reduced: true);
    await t.pump();
    expect(player.active, isFalse);
    final body = player.artboard.component('Body')!;
    final stopped = body.scaleY;
    await t.pump(const Duration(seconds: 1));
    await mount(reduced: true);
    expect(body.scaleY, stopped);
    await mount(motion: CharacterMotion.sleeping);
    await t.pump();
    expect(player.active, isFalse);
    expect(
      t.widget<PonoView>(find.byType(PonoView)).motion,
      CharacterMotion.sleeping,
    );
    body.dispose();
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('設定からポノの全動作を試しても育成記録が変わらない', (t) async {
    final game = GameController(DemoRepository(MemoryStore()));
    await game.initialize();
    await game.register('はる');
    final before = game.snapshot!.toJson();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: game, isDemo: true)),
      ),
    );
    await t.scrollUntilVisible(find.text('ポノの動きをみる'), 200);
    await t.tap(find.text('ポノの動きをみる'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final preview = find.byType(PonoView).last;
    for (final label in ['あるく', 'なでる', 'よろこぶ', 'つかれた', 'おやすみ', 'いつも']) {
      await t.tap(find.text(label));
      await t.pump(const Duration(milliseconds: 300));
      expect(preview, findsOneWidget);
      expect(game.snapshot!.toJson(), before);
    }
    await t.tap(find.byTooltip('動きを止める'));
    await t.pump();
    expect(t.widget<PonoView>(preview).animate, isFalse);
    await t.tap(find.byTooltip('閉じる'));
    await t.pump(const Duration(milliseconds: 300));
    expect(game.snapshot!.toJson(), before);
    await t.pumpWidget(const SizedBox());
    game.dispose();
    expect(t.takeException(), isNull);
  });
}
