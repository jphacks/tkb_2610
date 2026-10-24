import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/core/evolution_preview.dart';

void main() {
  test('各段階の全種類を重複なしで試せて、第二進化の前後は同じ系統になる', () {
    final picker = EvolutionPreviewPicker(random: Random(42));
    for (final second in [false, true]) {
      final count = second ? 49 : 7;
      final names = <String>{};
      String? previous;
      for (var cycle = 0; cycle < 2; cycle++) {
        names.clear();
        for (var i = 0; i < count; i++) {
          final event = picker.next(second: second);
          expect(event.after.kind, isNot(previous));
          expect(event.after.evolution, second ? 2 : 1);
          expect(event.before.evolution, second ? 1 : 0);
          if (second) {
            expect(
              event.before.form.firstCategory,
              event.after.form.firstCategory,
            );
          } else {
            expect(event.before.kind, 'base_01');
          }
          names.add(event.after.kind);
          previous = event.after.kind;
        }
        expect(names.length, count);
      }
    }
  });
}
