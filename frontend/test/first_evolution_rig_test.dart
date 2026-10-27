import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late rive.File file;
  late Map<String, dynamic> manifest;
  final vertices = <(double, double)>[];
  final triangles = <(int, int, int)>[];

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
    final grid = manifest['meshGrid'] as int;
    final points = <(int, int)>[
      for (var x = 0; x <= grid; x++) (x, 0),
      for (var y = 1; y <= grid; y++) (grid, y),
      for (var x = grid - 1; x >= 0; x--) (x, grid),
      for (var y = grid - 1; y > 0; y--) (0, y),
      for (var y = 1; y < grid; y++)
        for (var x = 1; x < grid; x++) (x, y),
    ];
    final lookup = {for (var i = 0; i < points.length; i++) points[i]: i};
    vertices.addAll(points.map((p) => (p.$1 * 500 / grid, p.$2 * 500 / grid)));
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        final a = lookup[(x, y)]!,
            b = lookup[(x + 1, y)]!,
            c = lookup[(x + 1, y + 1)]!,
            d = lookup[(x, y + 1)]!;
        triangles.addAll([(a, b, c), (a, c, d)]);
      }
    }
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
    test('$kind: 実ファイルの表情・歩行・ポーズとメッシュの接続を確認', () {
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
      final bones = (spec['bones'] as List).cast<Map<String, dynamic>>();
      final components = [
        for (final b in bones) player.artboard.component(b['name'] as String)!,
      ];
      final eye = player.artboard.component('Eye 0')!;
      final body = player.artboard.component('Body')!;
      addTearDown(() {
        eye.dispose();
        body.dispose();
        for (final c in components) {
          c.dispose();
        }
        mode.dispose();
        player.dispose();
        data.dispose();
      });
      expect(player.artboard.animationCount(), 6);
      final blinkScales = <double>[];
      final appendageAngles = <double>[];
      final weights = (spec['weights'] as List).cast<List>();
      for (var mood = 0; mood < 6; mood++) {
        mode.value = mood.toDouble();
        for (var frame = 0; frame < 240; frame++) {
          player.stateMachine.advanceAndApply(1 / 60);
          if (mood == 0) blinkScales.add(eye.scaleY);
          if (mood == 1) appendageAngles.add(components.last.rotation);
          final matrices = [for (final c in components) c.worldTransform];
          final posed = <(double, double)>[];
          for (var v = 0; v < vertices.length; v++) {
            final indices = weights[v][0] as int, values = weights[v][1] as int;
            var px = 0.0, py = 0.0, sum = 0;
            for (var slot = 0; slot < 4; slot++) {
              final value = (values >> (slot * 8)) & 255;
              if (value == 0) continue;
              final index = ((indices >> (slot * 8)) & 255) - 1;
              expect(index, inInclusiveRange(0, bones.length - 1));
              final bind = bones[index]['bind'] as List;
              final x = vertices[v].$1 - (bind[0] as num).toDouble();
              final y = vertices[v].$2 - (bind[1] as num).toDouble();
              final m = matrices[index];
              px += (m[0] * x + m[2] * y + m[4]) * value / 255;
              py += (m[1] * x + m[3] * y + m[5]) * value / 255;
              sum += value;
            }
            expect(sum, 255);
            expect(px.isFinite && py.isFinite, isTrue);
            posed.add((px, py));
          }
          var inverted = 0;
          final foldedAt = <(double, double)>[];
          for (final (a, b, c) in triangles) {
            final p = posed[a], q = posed[b], r = posed[c];
            final area =
                (q.$1 - p.$1) * (r.$2 - p.$2) - (q.$2 - p.$2) * (r.$1 - p.$1);
            if (area <= 0) {
              inverted++;
              foldedAt.add(vertices[a]);
            }
          }
          expect(
            inverted,
            0,
            reason:
                '$id mood=$mood frame=$frame: triangle folds at ${foldedAt.take(8).toList()}',
          );
          expect(body.scaleY, greaterThan(.8));
        }
      }
      expect(blinkScales.reduce(math.min), lessThan(.15));
      expect(blinkScales.reduce(math.max), closeTo(1, .01));
      expect(
        appendageAngles.reduce(math.max) - appendageAngles.reduce(math.min),
        greaterThan(.02),
      );
    });
  }
}
