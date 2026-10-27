import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late rive.File file;
  late Map<String, dynamic> manifest;
  setUpAll(() async {
    expect(await rive.RiveNative.init(), isTrue);
    file = (await rive.File.decode(
      await io.File('assets/animations/first_evolutions.riv').readAsBytes(),
      riveFactory: rive.Factory.flutter,
    ))!;
    manifest =
        jsonDecode(
              await io.File(
                'animation/first_evolutions/rig_manifest.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
  });
  tearDownAll(() => file.dispose());

  for (final kind in [
    'kindness',
    'environment',
    'gratitude',
    'courage',
    'cooperation',
    'honesty',
    'self_care',
  ]) {
    test('$kind: 別パーツの形を保ったまま全表情と歩行を再生する', () {
      expect(manifest['architecture'], 'rigid-cutout');
      expect(manifest['meshCount'], 0);
      final id = 'stage1_$kind';
      final spec = (manifest['artboards'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((a) => a['kind'] == id);
      final player = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardSelector.byName(id),
      );
      final data = player.dataBind(rive.DataBind.auto());
      final mode = data.number('mode')!;
      final parts = (spec['parts'] as List).cast<Map<String, dynamic>>();
      final joints = [
        for (final p in parts) player.artboard.component(p['name'] as String)!,
      ];
      final images = [
        for (final p in parts) player.artboard.component('${p['name']} image')!,
      ];
      final scales = [for (final image in images) (image.scaleX, image.scaleY)];
      final eye = player.artboard.component('Eye 0')!;
      final blinks = <double>[];
      final samples = <List<double>>[];
      final legs = (spec['legs'] as List).cast<String>();
      final appendages = (spec['appendages'] as List).cast<String>();
      final movingNames = [...legs, ...appendages];
      final moving = [
        for (final name in movingNames) player.artboard.component(name)!,
      ];
      addTearDown(() {
        eye.dispose();
        for (final component in [...joints, ...images, ...moving]) {
          component.dispose();
        }
        mode.dispose();
        player.dispose();
        data.dispose();
      });
      expect(player.artboard.animationCount(), 6);
      expect(player.artboard.component('Puppet mesh'), isNull);
      expect(player.artboard.component('Puppet skin'), isNull);
      if (kind == 'kindness') expect(appendages.length, 5);
      if (kind == 'cooperation') {
        expect(
          appendages,
          containsAll(['Fin near', 'Fin far', 'Tail stem', 'Tail flukes']),
        );
        for (final name in ['Smile curve', 'Joy mouth', 'Sleep mouth']) {
          expect(player.artboard.component(name), isNull);
        }
      }
      if (legs.isNotEmpty) expect(legs.length, 4);
      for (var mood = 0; mood < 6; mood++) {
        mode.value = mood.toDouble();
        for (var frame = 0; frame < 240; frame++) {
          player.stateMachine.advanceAndApply(1 / 60);
          if (mood == 0) blinks.add(eye.scaleY);
          if (mood == 1) samples.add([for (final c in moving) c.rotation]);
          for (var p = 0; p < images.length; p++) {
            expect(images[p].scaleX, closeTo(scales[p].$1, 1e-6));
            expect(images[p].scaleY, closeTo(scales[p].$2, 1e-6));
            expect(joints[p].scaleX, closeTo(1, 1e-6));
            expect(joints[p].scaleY, closeTo(1, 1e-6));
            final matrix = images[p].worldTransform;
            for (var v = 0; v < 6; v++) {
              expect(matrix[v].isFinite, isTrue);
            }
          }
        }
      }
      expect(blinks.reduce(math.min), lessThan(.15));
      expect(blinks.reduce(math.max), closeTo(1, .01));
      for (var p = 0; p < moving.length; p++) {
        final angles = [for (final row in samples) row[p]];
        expect(
          angles.reduce(math.max) - angles.reduce(math.min),
          greaterThan(.005),
          reason: '${movingNames[p]} must move independently',
        );
      }
      if (kind == 'kindness') {
        // A single parent wobble cannot satisfy independent phase differences.
        for (var p = 1; p < 5; p++) {
          expect(samples.any((s) => (s[p] - s[0]).abs() > .01), isTrue);
        }
      }
    });
  }

  test('ミケルナは専用の四足姿へ切り替わり、停止すると座る位置に戻る', () {
    final player = rive.RiveWidgetController(
      file,
      artboardSelector: rive.ArtboardSelector.byName('stage1_self_care'),
    );
    final data = player.dataBind(rive.DataBind.auto());
    final mode = data.number('mode')!;
    final head = player.artboard.component('Head')!;
    final tail = player.artboard.component('Tail')!;
    final standing = player.artboard.component('Standing torso image')!;
    final seated = player.artboard.component('Seated torso image')!;
    void settle(int value) {
      mode.value = value.toDouble();
      for (var f = 0; f < 30; f++) {
        player.stateMachine.advanceAndApply(1 / 60);
      }
    }

    settle(0);
    final seatedX = head.x, seatedTailX = tail.x;
    settle(1);
    expect(head.x, seatedX - 20);
    expect(tail.x, seatedTailX + 48);
    expect(standing.localBounds.width, greaterThan(0));
    expect(seated.localBounds.width, greaterThan(0));
    settle(0);
    expect(head.x, seatedX);
    expect(tail.x, seatedTailX);
    for (final c in [head, tail, standing, seated]) {
      c.dispose();
    }
    mode.dispose();
    player.dispose();
    data.dispose();
  });
}
