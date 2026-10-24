import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/app.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'repository_test.dart' show MemoryStore;

void main() {
  testWidgets('小さい画面でも登録・タブ・キーボード付き投稿を操作できる', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = GameController(DemoRepository(MemoryStore()));
    await c.initialize();
    await t.pumpWidget(YoinokoApp(controller: c));
    await t.enterText(find.byType(TextFormField), 'はる');
    await t.ensureVisible(find.text('はじめる'));
    await t.tap(find.text('はじめる'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    for (final index in [1, 3, 4, 0]) {
      await t.tap(find.byKey(ValueKey('tab-$index')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    }
    await t.tap(find.byKey(const ValueKey('tab-2')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    t.view.viewInsets = const FakeViewPadding(bottom: 240);
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('deed-content')), 'ありがとう');
    await t.ensureVisible(find.text('送る'));
    await t.tap(find.text('送る'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    t.view.resetViewInsets();
    await t.pump();
    expect(c.snapshot!.deeds.length, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
