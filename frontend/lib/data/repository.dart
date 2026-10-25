import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'demo_evolution.dart';
import 'character_praise.dart';

abstract interface class GameRepository {
  Future<GameSnapshot?> load();
  Future<GameSnapshot> register(String name);
  Future<DeedResult> postDeed(String text, String requestId);
  Future<GameSnapshot> rename(String name);
  Future<GameSnapshot> welcomeNext();
  Future<void> deleteAccount();
  Future<PageResult<Companion>> history({int offset = 0});
  Future<PageResult<Deed>> deedsFor(String characterId, {int offset = 0});
}

abstract interface class SnapshotStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class LocalSnapshotStore implements SnapshotStore {
  static const key = 'yoinoko.demo.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = value == null
        ? await prefs.remove(key)
        : await prefs.setString(key, value);
    if (!ok) throw const GameException('保存できませんでした。もう一度お試しください。');
  }
}

/// Offline demonstration only. Production HP, XP, classification and dates belong to the server.
class DemoRepository implements GameRepository {
  DemoRepository(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final SnapshotStore store;
  final DateTime Function() clock;
  GameSnapshot? _data;
  Future<GameSnapshot> _save(GameSnapshot next) async {
    await store.write(jsonEncode(next.toJson()));
    _data = next;
    return next;
  }

  GameSnapshot get data =>
      _data ?? (throw const GameException('登録をやり直してください。'));
  @override
  Future<GameSnapshot?> load() async {
    final raw = await store.read();
    if (raw == null) return null;
    try {
      _data = GameSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      throw const GameException('保存データを読み込めませんでした。データを消さずに、再読み込みをお試しください。');
    }
    final current = data;
    final repaired = [
      for (final c in current.characters)
        settleDemoGeneration(repairLegacyDemoForm(c, current.deeds), clock()),
    ];
    if (List.generate(
      repaired.length,
      (i) => !identical(repaired[i], current.characters[i]),
    ).contains(true)) {
      return _save(
        GameSnapshot(
          name: current.name,
          characters: repaired,
          deeds: current.deeds,
        ),
      );
    }
    return _data;
  }

  @override
  Future<GameSnapshot> register(String name) async {
    if (_data != null) return data;
    return _save(
      GameSnapshot(
        name: name,
        characters: [Companion(id: 'demo-1', generation: 1, bornAt: clock())],
      ),
    );
  }

  @override
  Future<DeedResult> postDeed(String text, String requestId) async {
    final old = data.deeds.where((d) => d.id == requestId);
    if (old.isNotEmpty) {
      if (old.first.text != text.trim()) {
        throw const GameException('送信内容が変わっています。新しく投稿してください。');
      }
      return DeedResult(data, old.first);
    }
    final c = settleDemoGeneration(data.current, clock());
    if (c.stage != LifeStage.active) {
      throw const GameException('この子の育成は終了しています。新しい子を迎えてください。');
    }
    if (text.trim().isEmpty) throw const GameException('今日の善行を入力してください。');
    if (text.length > 500) throw const GameException('500文字以内で入力してください。');
    // A deterministic local preview, never represented as AI judgement.
    final category = _category(text);
    final todayXp = data.deeds
        .where((d) => dayKey(d.at) == dayKey(clock()))
        .fold(0, (sum, d) => sum + d.xp);
    final xp = todayXp >= 50 ? 0 : 10;
    final hp = (100 - c.hp).clamp(0, 20);
    final deed = Deed(
      id: requestId,
      characterId: c.id,
      text: text.trim(),
      at: clock(),
      category: category,
      categoryPoints: xp > 0 ? 1 : 0,
      xp: xp,
      hp: hp,
      // この善行で進化する場合も、行動を見ていた進化前のキャラが褒める。
      praise: demoCharacterPraise(c.kind, category),
    );
    final next = applyDemoEvolution(c, deed, data.deeds);
    final snapshot = await _save(
      GameSnapshot(
        name: data.name,
        characters: [...data.characters.take(data.characters.length - 1), next],
        deeds: [...data.deeds, deed],
      ),
    );
    return DeedResult(snapshot, deed, evolved: next.evolution > c.evolution);
  }

  int _category(String t) {
    if (RegExp('ごみ|ゴミ|掃除|節電|植物').hasMatch(t)) return 1;
    if (RegExp('ありがとう|感謝').hasMatch(t)) return 2;
    if (RegExp('挑戦|勇気').hasMatch(t)) return 3;
    if (RegExp('手伝|協力|一緒').hasMatch(t)) return 4;
    if (RegExp('正直|落とし物|約束').hasMatch(t)) return 5;
    if (RegExp('休|睡眠|自分|散歩').hasMatch(t)) return 6;
    return 0;
  }

  @override
  Future<GameSnapshot> rename(String name) => _save(
    GameSnapshot(name: name, characters: data.characters, deeds: data.deeds),
  );
  @override
  Future<GameSnapshot> welcomeNext() async {
    final c = settleDemoGeneration(data.current, clock());
    if (c.stage == LifeStage.active ||
        c.nextAvailableAt == null ||
        clock().isBefore(c.nextAvailableAt!)) {
      throw const GameException('新しい子は、育成終了の翌日から迎えられます。');
    }
    return _save(
      GameSnapshot(
        name: data.name,
        characters: [
          ...data.characters.take(data.characters.length - 1),
          c,
          Companion(
            id: 'demo-${c.generation + 1}',
            generation: c.generation + 1,
            bornAt: clock(),
          ),
        ],
        deeds: data.deeds,
      ),
    );
  }

  @override
  Future<PageResult<Companion>> history({int offset = 0}) async {
    final all = data.characters.reversed.toList();
    final items = all.skip(offset).take(20).toList();
    return PageResult(
      items: items,
      totalCount: all.length,
      hasMore: offset + items.length < all.length,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<PageResult<Deed>> deedsFor(
    String characterId, {
    int offset = 0,
  }) async {
    final all = data.deeds.where((d) => d.characterId == characterId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final items = all.skip(offset).take(20).toList();
    return PageResult(
      items: items,
      totalCount: all.length,
      hasMore: offset + items.length < all.length,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<void> deleteAccount() async {
    await store.write(null);
    _data = null;
  }
}
