import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/character_speech.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'package:ichinichi_ichizen/features/home.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';

class _Store implements SnapshotStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

void main() {
  testWidgets('タップでセリフが変わり、再描画・2秒経過では変わらない', (tester) async {
    final controller = GameController(DemoRepository(_Store()));
    await controller.register('はる');
    addTearDown(controller.dispose);
    Widget home() => MaterialApp(
      home: Scaffold(body: HomePage(controller: controller)),
    );
    String speech() => tester
        .widget<Text>(find.byKey(const ValueKey('character-speech')))
        .data!;
    await tester.pumpWidget(home());
    final first = speech();
    expect(speechLinesFor('base_01'), contains(first));
    await tester.pumpWidget(home());
    expect(speech(), first);
    await tester.tap(find.byType(CharacterView));
    await tester.pump();
    final second = speech();
    expect(second, isNot(first));
    expect(speechLinesFor('base_01'), contains(second));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(CharacterView));
    await tester.pump();
    final third = speech();
    expect(third, isNot(second));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<CharacterView>(find.byType(CharacterView)).motion,
      CharacterMotion.tapped,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(speech(), third);
    expect(
      tester.widget<CharacterView>(find.byType(CharacterView)).motion,
      CharacterMotion.idle,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('57種の切替で対応するセリフを表示し、タップ中の破棄もできる', (tester) async {
    final controller = GameController(DemoRepository(_Store()));
    await controller.register('はる');
    addTearDown(controller.dispose);
    final initial = controller.snapshot!.current;
    for (final form in characterForms.values) {
      controller.snapshot = GameSnapshot(
        name: 'はる',
        characters: [
          initial.copyWith(kind: form.imageId, evolution: form.stage),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomePage(controller: controller)),
        ),
      );
      final speech = tester
          .widget<Text>(find.byKey(const ValueKey('character-speech')))
          .data;
      expect(speechLinesFor(form.imageId), contains(speech), reason: form.name);
      expect(tester.takeException(), isNull, reason: form.name);
    }
    await tester.tap(find.byType(CharacterView));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
