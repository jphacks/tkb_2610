import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/character_speech.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/features/android_pet_overlay.dart';
import 'package:ichinichi_ichizen/widgets/character_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jp.yoinoko.app/overlay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('小さい透過画面で既存キャラを表示し、タップで別のセリフ、ドラッグと終了を扱う', (tester) async {
    tester.view.physicalSize = const Size(192, 232);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <MethodCall>[];
    final c = Companion(
      id: 'current',
      generation: 2,
      bornAt: DateTime(2026, 10, 25),
      kind: 'stage2_environment_self_care',
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'ready') {
        return {
          'character': jsonEncode(c.toJson()),
          'visible': true,
          'x': 50.0,
          'y': 100.0,
          'maxX': 200.0,
          'maxY': 500.0,
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const AndroidPetOverlay());
    await tester.pump();
    expect(
      tester.widget<CharacterView>(find.byType(CharacterView)).character.kind,
      c.kind,
    );
    final first = tester
        .widget<Text>(find.byKey(const ValueKey('character-speech')))
        .data!;
    expect(speechLinesFor(c.kind), contains(first));
    await tester.tap(find.byType(CharacterView));
    await tester.pump();
    final next = tester
        .widget<Text>(find.byKey(const ValueKey('character-speech')))
        .data!;
    expect(next, isNot(first));
    await tester.drag(find.byType(CharacterView), const Offset(40, 20));
    await tester.pump();
    expect(calls.where((call) => call.method == 'move'), isNotEmpty);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('visibility', false),
      ),
      (_) {},
    );
    final beforeHidden = calls.length;
    final hiddenSpeech = tester
        .widget<Text>(find.byKey(const ValueKey('character-speech')))
        .data;
    await tester.pump(const Duration(seconds: 45));
    expect(calls.length, beforeHidden);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('character-speech'))).data,
      hiddenSpeech,
    );
    await tester.tap(find.byTooltip('おでかけを終了'));
    await tester.pump();
    expect(calls.last.method, 'stop');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
