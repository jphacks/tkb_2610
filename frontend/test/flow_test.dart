import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/app.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'package:ichinichi_ichizen/data/character_speech.dart';
import 'package:ichinichi_ichizen/data/models.dart';

class _Store implements SnapshotStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    value = v;
  }
}

void main() {
  testWidgets(
    'Nine screens: registration, posting, status, gallery, details, settings and generation',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final font = FontLoader('Rounded')
        ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Bold.ttf'));
      await font.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final store = _Store();
      final repo = DemoRepository(store);
      final c = GameController(repo);
      await c.initialize();
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: YoinokoApp(controller: c),
        ),
      );
      await t.runAsync(() async {
        await precacheImage(
          const ResizeImage(
            AssetImage('assets/icons/uchinoko.png'),
            width: 136,
          ),
          boundary.currentContext!,
        );
        for (final asset in [
          'evolution/base_01',
          'dome',
          'evolution/stage1_honesty',
        ]) {
          await precacheImage(
            AssetImage('assets/characters/$asset.png'),
            boundary.currentContext!,
          );
        }
      });
      Future<void> settle() async {
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
      }

      Future<void> capture(String name) async {
        await settle();
        await t.runAsync(() async {
          final b =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await b.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/qa').createSync(recursive: true);
          File(
            'build/qa/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(t.takeException(), isNull);
      }

      await capture('01-registration');
      await t.enterText(find.byType(TextFormField), 'はる');
      await t.ensureVisible(find.text('はじめる'));
      await t.tap(find.text('はじめる'));
      await settle();
      expect(
        speechLinesFor(c.snapshot!.current.kind),
        contains(
          t.widget<Text>(find.byKey(const ValueKey('character-speech'))).data,
        ),
      );
      await capture('02-home');
      await t.tap(find.byKey(const ValueKey('tab-2')));
      await settle();
      await capture('03-deed-entry');
      await t.enterText(
        find.byKey(const ValueKey('deed-content')),
        '電車で席をゆずりました。',
      );
      await t.tap(find.text('送る'));
      await settle();
      expect(c.snapshot!.deeds.length, 1);
      expect(find.text('そのやさしさ、きっと届いたよ！'), findsOneWidget);
      await capture('04-result');
      await t.tap(find.byKey(const ValueKey('tab-1')));
      await settle();
      await capture('05-status');
      await t.tap(find.byKey(const ValueKey('tab-3')));
      await settle();
      await capture('06-gallery');
      await t.tap(find.text('育成中'));
      await settle();
      expect(find.text('電車で席をゆずりました。'), findsOneWidget);
      await capture('07-detail');
      await t.tap(find.byKey(const ValueKey('tab-4')));
      await settle();
      await capture('09-settings');
      await t.tap(find.text('プレイヤー名を変更'));
      await settle();
      await t.enterText(find.byType(TextFormField), 'なつ');
      await t.tap(find.text('保存する'));
      await settle();
      expect(c.snapshot!.name, 'なつ');
      final restored = DemoRepository(store);
      expect((await restored.load())!.deeds.length, 1);
      expect((await restored.load())!.name, 'なつ');
      await t.tap(find.text('退会する'));
      await settle();
      final delete = find.widgetWithText(TextButton, '退会する');
      expect(t.widget<TextButton>(delete).onPressed, isNull);
      await t.tap(find.byType(CheckboxListTile));
      await settle();
      await t.tap(delete);
      await settle();
      expect(find.text('はじめまして'), findsOneWidget);
      expect(await store.read(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      final sleeping = Companion(
        id: 'sleep',
        generation: 1,
        bornAt: DateTime.now().subtract(const Duration(days: 14)),
        hp: 0,
        kind: 'turtle',
        evolution: 1,
        stage: LifeStage.sleeping,
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
        nextAvailableAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final s = _Store();
      await s.write(
        '{"name":"はる","characters":[${jsonEncode(sleeping.toJson())}],"deeds":[]}',
      );
      final next = GameController(DemoRepository(s));
      await next.initialize();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: YoinokoApp(controller: next),
        ),
      );
      await settle();
      await capture('08-generation');
      await t.tap(find.text('新しい子を迎える'));
      await settle();
      expect(next.snapshot!.current.generation, 2);
      expect(next.snapshot!.characters.length, 2);
      expect(next.snapshot!.current.hp, 100);
      await t.pumpWidget(const SizedBox());
      next.dispose();
    },
  );
}
