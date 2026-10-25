import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/character_personalities.dart';
import 'package:ichinichi_ichizen/data/character_praise.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';
import 'repository_test.dart' show MemoryStore;

void main() {
  test('全57種に名前の対応する性格があり、7カテゴリを褒め分ける', () {
    expect(characterPersonalities.keys.toSet(), characterForms.keys.toSet());
    for (final form in characterForms.values) {
      final profile = characterPersonality(form.imageId);
      expect(profile.name, form.name);
      expect(profile.personality, isNotEmpty);
      expect(profile.tone, isNotEmpty);
      final praises = <String>{};
      for (var category = 0; category < categoryIds.length; category++) {
        final praise = demoCharacterPraise(form.imageId, category);
        expect(praise, contains(demoPraiseActions[category]));
        expect(praise, isNot(contains('{action}')));
        praises.add(praise);
      }
      expect(praises.length, 7);
    }
    expect(demoCharacterPraise('stage1_courage', 0), contains('かっこいいぞ'));
    expect(demoCharacterPraise('stage1_self_care', 0), contains('にゃ'));
    expect(
      demoCharacterPraise('unknown', 0),
      demoCharacterPraise('base_01', 0),
    );
    expect(
      demoCharacterPraise('turtle', 0),
      demoCharacterPraise('stage1_honesty', 0),
    );
  });

  test('57キャラの投稿で口調を保存し、XP・カテゴリはそのまま', () async {
    final now = DateTime.utc(2026, 10, 25, 3);
    for (final form in characterForms.values) {
      final store = MemoryStore();
      store.value = jsonEncode(
        GameSnapshot(
          name: 'はる',
          characters: [
            Companion(
              id: 'demo-1',
              generation: 1,
              bornAt: now,
              kind: form.imageId,
              evolution: form.stage,
              xp: form.stage == 2
                  ? 300
                  : form.stage == 1
                  ? 100
                  : 0,
              secondEvolutionDate: form.stage == 2 ? now : null,
            ),
          ],
        ).toJson(),
      );
      final repo = DemoRepository(store, clock: () => now);
      await repo.load();
      final result = await repo.postDeed('ありがとうと伝えた', 'post-1');
      expect(
        result.deed.praise,
        demoCharacterPraise(form.imageId, 2),
        reason: form.name,
      );
      expect(result.deed.category, 2);
      expect(result.deed.xp, 10);
      final replay = await repo.postDeed('ありがとうと伝えた', 'post-1');
      expect(replay.deed.praise, result.deed.praise);
      final loaded = await DemoRepository(store, clock: () => now).load();
      expect(loaded!.deeds.single.praise, result.deed.praise);
    }
  });

  test('進化する投稿は進化前の口調で褒め、次の投稿は進化後の口調になる', () async {
    final now = DateTime.utc(2026, 10, 25, 3);
    final store = MemoryStore();
    store.value = jsonEncode(
      GameSnapshot(
        name: 'はる',
        characters: [
          Companion(id: 'demo-1', generation: 1, bornAt: now, xp: 90),
        ],
      ).toJson(),
    );
    final repo = DemoRepository(store, clock: () => now);
    await repo.load();
    final evolved = await repo.postDeed('勇気を出して挑戦した', 'evolution');
    expect(evolved.evolved, isTrue);
    expect(evolved.snapshot.current.kind, 'stage1_courage');
    expect(evolved.deed.praise, demoCharacterPraise('base_01', 3));
    final next = await repo.postDeed('勇気を出して挑戦した', 'next');
    expect(next.deed.praise, demoCharacterPraise('stage1_courage', 3));
    final replay = await repo.postDeed('勇気を出して挑戦した', 'evolution');
    expect(replay.deed.praise, evolved.deed.praise);
  });
}
