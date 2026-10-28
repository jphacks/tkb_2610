import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

class PaintMask {
  PaintMask(this.width, this.height, this.rgba);
  final int width, height;
  final Uint8List rgba;
  static Future<PaintMask> load(String asset, String folder) async {
    final codec = await ui.instantiateImageCodec(
      await File('animation/first_evolutions/$folder/$asset.png').readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final mask = PaintMask(
      image.width,
      image.height,
      pixels.buffer.asUint8List(),
    );
    image.dispose();
    codec.dispose();
    return mask;
  }

  bool painted(double x, double y) {
    final ix = x.floor(), iy = y.floor();
    return ix >= 0 &&
        iy >= 0 &&
        ix < width &&
        iy < height &&
        rgba[(iy * width + ix) * 4 + 3] > 180;
  }
}

List<double> inverse(List<double> m) {
  final determinant = m[0] * m[3] - m[1] * m[2];
  return [
    m[3] / determinant,
    -m[1] / determinant,
    -m[2] / determinant,
    m[0] / determinant,
    (m[2] * m[5] - m[3] * m[4]) / determinant,
    (m[1] * m[4] - m[0] * m[5]) / determinant,
  ];
}

bool at(PaintMask mask, List<double> m, double x, double y) =>
    mask.painted(m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]);

// Sample actual opaque pixels, not component bounding boxes. Empty padding
// touching a torso cannot make a detached ear or leg pass this check.
bool overlaps(
  PaintMask child,
  List<double> transform,
  List<(PaintMask, List<double>)> parents,
) {
  final points = [
    for (final x in [0, child.width])
      for (final y in [0, child.height])
        (
          transform[0] * x + transform[2] * y + transform[4],
          transform[1] * x + transform[3] * y + transform[5],
        ),
  ];
  final left = points.map((p) => p.$1).reduce(math.min).floor();
  final right = points.map((p) => p.$1).reduce(math.max).ceil();
  final top = points.map((p) => p.$2).reduce(math.min).floor();
  final bottom = points.map((p) => p.$2).reduce(math.max).ceil();
  final inv = inverse(transform);
  var count = 0;
  for (var y = top; y < bottom; y += 3) {
    for (var x = left; x < right; x += 3) {
      if (at(child, inv, x + .5, y + .5) &&
          parents.any((p) => at(p.$1, p.$2, x + .5, y + .5))) {
        if (++count >= 12) return true;
      }
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late rive.File file;
  late List<Map<String, dynamic>> boards;
  final masks = <String, PaintMask>{};
  setUpAll(() async {
    await rive.RiveNative.init();
    file = (await rive.File.decode(
      await File('assets/animations/first_evolutions.riv').readAsBytes(),
      riveFactory: rive.Factory.flutter,
    ))!;
    boards =
        (jsonDecode(
                  await File(
                    'animation/first_evolutions/rig_manifest.json',
                  ).readAsString(),
                )['artboards']
                as List)
            .cast<Map<String, dynamic>>();
    for (final board in boards) {
      for (final part in board['parts'] as List) {
        final asset = part['asset'] as String;
        masks[asset] ??= await PaintMask.load(
          asset,
          part['folder'] as String? ?? 'parts',
        );
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
    test('$kind: 全状態で耳・脚・尾の実ピクセルが本体と重なる', () {
      final id = 'stage1_$kind';
      final spec = boards.singleWhere((b) => b['kind'] == id);
      final parts = (spec['parts'] as List).cast<Map<String, dynamic>>();
      final player = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardSelector.byName(id),
      );
      final data = player.dataBind(rive.DataBind.auto());
      final mode = data.number('mode')!;
      final images = {
        for (final p in parts)
          p['name'] as String: player.artboard.component('${p['name']} image')!,
      };
      final pixels = {
        for (final p in parts) p['name'] as String: masks[p['asset']]!,
      };
      addTearDown(() {
        for (final image in images.values) {
          image.dispose();
        }
        mode.dispose();
        player.dispose();
        data.dispose();
      });
      for (var mood = 0; mood < 6; mood++) {
        final contacts = <String, List<String>>{};
        if (kind == 'kindness') {
          for (final part in parts) {
            final name = part['name'] as String;
            if (name.startsWith('Tentacle')) contacts[name] = ['Cap'];
          }
        } else {
          expect(spec['contacts'], isNotEmpty);
          for (final row in spec['contacts'] as List) {
            if ((row['modes'] as List).contains(mood)) {
              contacts[row['child'] as String] = (row['parents'] as List)
                  .cast<String>();
            }
          }
        }
        mode.value = mood.toDouble();
        for (var frame = 0; frame < 240; frame++) {
          player.stateMachine.advanceAndApply(1 / 60);
          if (frame < 20 || frame % 20 != 0) continue;
          final transforms = {
            for (final entry in images.entries)
              entry.key: [
                for (var i = 0; i < 6; i++) entry.value.worldTransform[i],
              ],
          };
          for (final contact in contacts.entries) {
            if (contact.value.isEmpty) continue;
            expect(
              overlaps(pixels[contact.key]!, transforms[contact.key]!, [
                for (final parent in contact.value)
                  (pixels[parent]!, inverse(transforms[parent]!)),
              ]),
              isTrue,
              reason:
                  '$id mode=$mood frame=$frame ${contact.key} detached from ${contact.value}',
            );
          }
        }
      }
    });
  }
}
