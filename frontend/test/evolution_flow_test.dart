import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/app.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'package:ichinichi_ichizen/features/evolution_scene.dart';
import 'repository_test.dart' show MemoryStore;
import 'support/fake_evolution_sound.dart';

void main() {
  testWidgets('草のシカ→月のシカがホーム・ステータス・図鑑・再起動に反映される', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await (FontLoader('Rounded')
          ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    var now = DateTime.utc(2026, 10, 1, 3);
    final store = MemoryStore();
    final c = GameController(DemoRepository(store, clock: () => now));
    await c.initialize();
    await c.register('はる');
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: YoinokoApp(
          controller: c,
          evolutionSoundFactory: () => FakeEvolutionSound(),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final kind in [
        'base_01',
        'stage1_environment',
        'stage2_environment_self_care',
      ]) {
        await precacheImage(
          AssetImage(characterForm(kind).assetPath),
          key.currentContext!,
        );
      }
      await precacheImage(
        const AssetImage('assets/characters/dome.png'),
        key.currentContext!,
      );
      await precacheImage(
        const ResizeImage(AssetImage('assets/icons/uchinoko.png'), width: 136),
        key.currentContext!,
      );
    });
    Future<void> settle() async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 450));
      await t.pump(const Duration(milliseconds: 450));
    }

    Future<void> capture(String name, {bool wait = true}) async {
      if (wait) await settle();
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/qa').createSync(recursive: true);
        File(
          'build/qa/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(t.takeException(), isNull);
    }

    for (var i = 0; i < 30; i++) {
      now = DateTime.utc(2026, 10, 1 + i ~/ 5, 3, i % 5);
      await c.post(i < 10 ? 'ごみを拾った' : '自分を休めた', 'evolve-$i');
      if (i == 9) {
        await t.pump();
        await t.pump();
        await t.pump(const Duration(milliseconds: 1400));
        await capture('animation-01-gather', wait: false);
        await t.pump(const Duration(milliseconds: 1100));
        await capture('animation-02-light', wait: false);
        await t.pump(const Duration(milliseconds: 800));
        await capture('animation-03-reveal', wait: false);
        await t.pump(const Duration(seconds: 3));
        await capture('evolution-01-first');
        expect(
          find.byKey(const ValueKey('evolution-species-name')),
          findsOneWidget,
        );
        await t.tap(find.text('これからもよろしく'));
        await settle();
        expect(find.text('メブシカに進化したよ！'), findsOneWidget);
      }
    }
    await settle();
    await t.pump(const Duration(seconds: 7));
    await capture('evolution-02-second');
    await t.tap(find.text('これからもよろしく'));
    await settle();
    expect(find.text('ツキノカに進化したよ！'), findsOneWidget);
    await capture('evolution-02-home-large');
    await t.tap(find.byKey(const ValueKey('tab-1')));
    await capture('evolution-03-status');
    expect(find.text('第2進化 · 月・シカ'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tab-3')));
    await capture('evolution-04-gallery');
    await t.tap(find.text('育成中'));
    await capture('evolution-05-detail');
    expect(find.text('月・シカ'), findsOneWidget);
    final restored = (await DemoRepository(store, clock: () => now).load())!;
    expect(restored.current.kind, 'stage2_environment_self_care');
    await t.tap(find.byKey(const ValueKey('tab-4')));
    await settle();
    await t.ensureVisible(find.text('第二進化の演出をみる'));
    await t.tap(find.text('第二進化の演出をみる'));
    await settle();
    final scene = t.widget<EvolutionScene>(find.byType(EvolutionScene));
    await t.runAsync(() async {
      for (final character in [scene.event.before, scene.event.after]) {
        await precacheImage(
          AssetImage(character.form.assetPath),
          t.element(find.byType(EvolutionScene)),
        );
      }
    });
    await settle();
    await t.tap(find.byKey(const ValueKey('evolution-skip')));
    await t.pump();
    await t.tap(find.text('これからもよろしく'));
    await settle();
    expect(find.text('第一進化の演出をみる'), findsOneWidget);
    expect(c.snapshot!.current.kind, restored.current.kind);
    expect(c.snapshot!.deeds.length, restored.deeds.length);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
