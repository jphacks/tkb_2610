import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/core/evolution_event.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'package:ichinichi_ichizen/features/evolution_scene.dart';
import 'repository_test.dart' show MemoryStore;
import 'support/fake_evolution_sound.dart';

final before = Companion(
  id: 'c',
  generation: 1,
  bornAt: DateTime.utc(2026, 10, 24),
  kind: 'base_01',
);
final event = EvolutionEvent(
  id: 'd',
  before: before,
  after: before.copyWith(evolution: 1, kind: 'stage1_environment'),
);
Future<void> mountScene(
  WidgetTester t,
  FakeEvolutionSound sound, {
  bool reduced = false,
  VoidCallback? close,
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: EvolutionScene(event: event, sound: sound, onClose: close ?? () {}),
    ),
  );
  final context = t.element(find.byType(EvolutionScene));
  await t.runAsync(() async {
    await precacheImage(AssetImage(before.form.assetPath), context);
    await precacheImage(AssetImage(event.after.form.assetPath), context);
  });
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('第一進化は段階を経て完了し、音は各一度だけ、ボタンで閉じる', (t) async {
    final sound = FakeEvolutionSound();
    var closed = 0;
    await mountScene(t, sound, close: () => closed++);
    expect(find.text('これからもよろしく'), findsNothing);
    await t.pump(const Duration(milliseconds: 1200));
    expect(sound.charges, 1);
    expect(sound.reveals, 0);
    await t.pump(const Duration(milliseconds: 1900));
    expect(sound.reveals, 1);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('これからもよろしく'), findsOneWidget);
    await t.tap(find.text('これからもよろしく'));
    expect(closed, 1);
    expect(sound.charges, 1);
    expect(sound.reveals, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    expect(sound.disposed, isTrue);
  });
  testWidgets('スキップは結果を即表示し、遅れて音を鳴らさない', (t) async {
    final sound = FakeEvolutionSound();
    await mountScene(t, sound);
    await t.tap(find.byKey(const ValueKey('evolution-skip')));
    await t.pump();
    expect(find.text('これからもよろしく'), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
    expect(sound.reveals, 0);
    expect(sound.stops, greaterThan(0));
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('動きを減らす設定では演出を待たずに結果を表示する', (t) async {
    final sound = FakeEvolutionSound();
    await mountScene(t, sound, reduced: true);
    expect(find.text('これからもよろしく'), findsOneWidget);
    expect(sound.charges, 0);
    expect(sound.reveals, 0);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('音声再生失敗でも完走でき、再生を再試行できる', (t) async {
    final sound = FakeEvolutionSound(fail: true);
    await mountScene(t, sound);
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('evolution-sound')));
    await t.pump();
    await t.pump(const Duration(seconds: 4));
    expect(find.text('これからもよろしく'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('消音中は音を鳴らさず、バックグラウンドでは進化を停止する', (t) async {
    final sound = FakeEvolutionSound();
    await mountScene(t, sound);
    await t.tap(find.byKey(const ValueKey('evolution-sound')));
    await t.pump();
    expect(sound.enabled, isFalse);
    await t.pump(const Duration(milliseconds: 1200));
    expect(sound.charges, 0);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 8));
    expect(find.text('これからもよろしく'), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    expect(find.text('これからもよろしく'), findsOneWidget);
    expect(sound.reveals, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('小さい画面でも結果と閉じる操作が収まる', (t) async {
    await mountScene(t, FakeEvolutionSound(), reduced: true);
    t.view.physicalSize = const Size(320, 568);
    await t.pump();
    await t.ensureVisible(find.text('これからもよろしく'));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  test('進化時だけ演出イベントが発生し、再送と再起動では繰り返さない', () async {
    final store = MemoryStore();
    final c = before.copyWith(xp: 90, attributes: [0, 9, 0, 0, 0, 0, 0]);
    await store.write(
      jsonEncode(GameSnapshot(name: 'はる', characters: [c]).toJson()),
    );
    final repo = DemoRepository(store);
    final controller = GameController(repo);
    await controller.initialize();
    expect(controller.pendingEvolution, isNull);
    await controller.post('ごみを拾った', 'same');
    expect(controller.pendingEvolution!.before.evolution, 0);
    expect(controller.pendingEvolution!.after.form.name, 'メブシカ');
    controller.finishEvolution('same');
    await controller.post('ごみを拾った', 'same');
    expect(controller.pendingEvolution, isNull);
    expect(controller.snapshot!.deeds.length, 1);
    final restarted = GameController(DemoRepository(store));
    await restarted.initialize();
    expect(restarted.pendingEvolution, isNull);
    expect(restarted.snapshot!.current.form.name, 'メブシカ');
    controller.dispose();
    restarted.dispose();
  });
}
