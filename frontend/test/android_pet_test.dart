import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/android_pet.dart';
import 'package:ichinichi_ichizen/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidPet pet;
  final calls = <MethodCall>[];
  var allowed = false, running = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    pet = AndroidPet();
    calls.clear();
    allowed = false;
    running = false;
    messenger.setMockMethodCallHandler(AndroidPet.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'status':
          return {'allowed': allowed, 'running': running};
        case 'start':
          if (!allowed) {
            throw PlatformException(code: 'PET_ERROR', message: '表示を許可してください');
          }
          running = true;
        case 'stop':
          running = false;
      }
      return null;
    });
  });
  tearDown(() {
    pet.dispose();
    messenger.setMockMethodCallHandler(AndroidPet.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  Companion companion(String kind) => Companion(
    id: 'pet',
    generation: 1,
    bornAt: DateTime(2026, 10, 25),
    kind: kind,
  );

  test('許可前の開始失敗を表示し、許可後は開始・終了できる', () async {
    await pet.refresh();
    expect(pet.available, isTrue);
    await pet.start();
    expect(pet.running, isFalse);
    expect(pet.error, '表示を許可してください');
    allowed = true;
    await pet.refresh();
    await pet.sync(companion('base_01'));
    await pet.start();
    expect(pet.running, isTrue);
    expect(pet.error, isNull);
    await pet.stop();
    expect(pet.running, isFalse);
  });

  test('進化と退会の同期は順番を保ち、削除後の古いキャラを残さない', () async {
    final gate = Completer<void>();
    var writes = 0;
    messenger.setMockMethodCallHandler(AndroidPet.channel, (call) async {
      calls.add(call);
      if (call.method == 'sync' && writes++ == 0) await gate.future;
      return null;
    });
    final first = pet.sync(companion('base_01'));
    final evolved = pet.sync(companion('stage1_environment'));
    final removed = pet.sync(null);
    gate.complete();
    await Future.wait([first, evolved, removed]);
    final values = calls
        .where((c) => c.method == 'sync')
        .map((c) => c.arguments)
        .toList();
    expect(jsonDecode(values[0] as String)['kind'], 'base_01');
    expect(jsonDecode(values[1] as String)['kind'], 'stage1_environment');
    expect(values[2], isNull);
    expect(pet.running, isFalse);
  });

  test('iOSではAndroidの権限やサービスを呼び出さない', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pet.refresh();
    await pet.sync(companion('base_01'));
    await pet.start();
    expect(calls, isEmpty);
    expect(pet.supported, isFalse);
  });
}
