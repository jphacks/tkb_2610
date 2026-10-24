import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/api_mapper.dart';
import 'package:ichinichi_ichizen/data/demo_evolution.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'repository_test.dart' show MemoryStore;

void main() {
  test('APIの全57画像IDが実ファイルと属性対応を持つ', () {
    expect(characterForms.length, 57);
    expect(characterForms.values.map((f) => f.name).toSet().length, 57);
    expect(characterForm('base_01').name, 'ポノ');
    expect(characterForm('stage1_environment').name, 'メブシカ');
    expect(characterForm('stage2_environment_self_care').name, 'ツキノカ');
    for (final form in characterForms.values) {
      expect(File(form.assetPath).existsSync(), isTrue, reason: form.imageId);
      final c = companionFromApi({
        'id': 'c',
        'generation': 1,
        'imageId': form.imageId,
        'hp': 100,
        'totalXp': 300,
        'evolutionStage': form.stage,
        'status': 'alive',
        'createdAt': '2026-10-24T00:00:00Z',
      });
      expect(c.form.imageId, form.imageId);
      expect(c.form.stage, form.stage);
    }
    expect(characterForm('stage2_environment_self_care').label, '月・シカ');
    expect(characterForm('unknown').imageId, 'base_01');
    expect(characterForm('turtle').imageId, 'stage1_honesty');
  });
  test('第一進化7種と第二進化49通り、第一進化のポイントを持ち越さない', () {
    for (var first = 0; first < 7; first++) {
      for (var second = 0; second < 7; second++) {
        var c = Companion(
          id: 'c',
          generation: 1,
          bornAt: DateTime.utc(2026, 10, 1),
        );
        final deeds = <Deed>[];
        for (var i = 0; i < 30; i++) {
          final d = Deed(
            id: '$i',
            characterId: 'c',
            text: '善行',
            at: DateTime.utc(2026, 10, 1).add(Duration(hours: i)),
            category: i < 10 ? first : second,
            praise: 'ありがとう',
            xp: 10,
            hp: 0,
          );
          c = applyDemoEvolution(c, d, deeds);
          deeds.add(d);
          if (i == 9) {
            expect(c.kind, 'stage1_${categoryIds[first]}');
            expect(c.nextEvolutionXp, 300);
            expect(c.secondEvolutionPoints.every((p) => p == 0), isTrue);
          }
        }
        expect(c.kind, 'stage2_${categoryIds[first]}_${categoryIds[second]}');
        expect(c.nextEvolutionXp, isNull);
        expect(c.secondEvolutionPoints[second], 20);
        expect(c.stage, LifeStage.active);
        expect(c.level, 7);
      }
    }
  });
  test('同点は最後の投稿、完全同時刻は定義順で決まる', () {
    Deed d(int cat, DateTime time) => Deed(
      id: '$cat',
      characterId: 'c',
      text: '',
      at: time,
      category: cat,
      praise: '',
      xp: 10,
      hp: 0,
    );
    final now = DateTime.utc(2026, 10, 1);
    expect(
      winningCategory(
        [2, 2, 0, 0, 0, 0, 0],
        [d(0, now), d(1, now.add(const Duration(seconds: 1)))],
      ),
      1,
    );
    expect(winningCategory([2, 2, 0, 0, 0, 0, 0], [d(0, now), d(1, now)]), 0);
  });
  test('デモ投稿から進化・再起動・翌日の世代交代まで画像と記録を保持する', () async {
    var now = DateTime.utc(2026, 10, 1, 3);
    final store = MemoryStore();
    final repo = DemoRepository(store, clock: () => now);
    await repo.register('はる');
    for (var i = 0; i < 30; i++) {
      now = DateTime.utc(2026, 10, 1 + i ~/ 5, 3, i % 5);
      final r = await repo.postDeed(i < 10 ? 'ごみを拾った' : '自分を休めた', 'post-$i');
      if (i == 9) expect(r.snapshot.current.form.label, '草・シカ');
    }
    final finalDay = now;
    final resumed = DemoRepository(store, clock: () => now);
    final saved = (await resumed.load())!;
    expect(saved.current.form.label, '月・シカ');
    expect(saved.current.nextEvolutionXp, isNull);
    expect(saved.current.stage, LifeStage.active);
    final capped = await resumed.postDeed('ありがとう', 'cap');
    expect(capped.deed.categoryPoints, 0);
    expect(capped.snapshot.current.kind, saved.current.kind);
    now = finalDay.add(const Duration(days: 1));
    final retired = (await resumed.load())!;
    expect(retired.current.stage, LifeStage.completed);
    final next = await resumed.welcomeNext();
    expect(next.current.generation, 2);
    expect(next.current.form.imageId, 'base_01');
    expect(next.characters.first.form.label, '月・シカ');
    expect(next.deeds.length, 31);
  });
  test('旧デモの初期画像のままの進化と保存データを壊さず移行する', () async {
    final store = MemoryStore();
    final c = Companion(
      id: 'old',
      generation: 1,
      bornAt: DateTime.utc(2026, 10, 1),
      evolution: 1,
      xp: 100,
      attributes: const [0, 10, 0, 0, 0, 0, 0],
    );
    await store.write(
      jsonEncode(GameSnapshot(name: 'はる', characters: [c]).toJson()),
    );
    final s = (await DemoRepository(store).load())!;
    expect(s.current.kind, 'stage1_environment');
    expect(s.current.nextEvolutionXp, 300);
    expect(s.current.id, 'old');
    expect(s.current.xp, 100);
  });
}
