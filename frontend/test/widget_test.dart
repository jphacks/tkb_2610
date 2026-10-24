import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/app.dart';
import 'package:ichinichi_ichizen/core/controller.dart';
import 'package:ichinichi_ichizen/data/repository.dart';

class MemoryStore implements SnapshotStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    value = v;
  }
}

void main() {
  testWidgets('Registration validates a name and enters the home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = GameController(DemoRepository(MemoryStore()));
    await c.initialize();
    await tester.pumpWidget(YoinokoApp(controller: c));
    await tester.ensureVisible(find.text('はじめる'));
    await tester.tap(find.text('はじめる'));
    await tester.pump();
    expect(find.text('名前を入力してください'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'はる');
    await tester.ensureVisible(find.text('はじめる'));
    await tester.tap(find.text('はじめる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('おかえり'), findsOneWidget);
    expect(c.snapshot?.name, 'はる');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
