import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/character_catalog.dart';
import 'package:ichinichi_ichizen/data/character_speech.dart';

void main() {
  test('57キャラすべてに重複・空白のない10個のセリフがある', () {
    expect(characterForms.length, 57);
    expect(characterSpeechLines.keys.toSet(), characterForms.keys.toSet());
    for (final form in characterForms.values) {
      final lines = speechLinesFor(form.imageId);
      expect(lines.length, 10, reason: form.name);
      expect(lines.toSet().length, 10, reason: form.name);
      expect(lines.every((line) => line.trim().isNotEmpty), isTrue);
    }
  });

  test('どのキャラも自分の10個から抽選し、直前と同じセリフを続けない', () {
    final random = Random(42);
    for (final kind in characterForms.keys) {
      String? previous;
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final line = pickCharacterSpeech(
          kind,
          random: random,
          previous: previous,
        );
        expect(speechLinesFor(kind), contains(line));
        expect(line, isNot(previous));
        seen.add(line);
        previous = line;
      }
      expect(seen, speechLinesFor(kind).toSet());
    }
  });

  test('旧ID・不明なIDは画像と同じキャラのセリフになる', () {
    for (final kind in ['initial', 'unknown', 'turtle', 'demo_turtle']) {
      expect(
        speechLinesFor(kind),
        characterSpeechLines[characterForm(kind).imageId],
      );
    }
  });
}
