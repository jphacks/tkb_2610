import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

abstract interface class GameRepository {
  Future<GameSnapshot?> load();
  Future<GameSnapshot> register(String name);
  Future<DeedResult> postDeed(String text, String requestId);
  Future<GameSnapshot> rename(String name);
  Future<GameSnapshot> welcomeNext();
  Future<void> deleteAccount();
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
    if (old.isNotEmpty) return DeedResult(data, old.first);
    final c = data.current;
    if (c.stage != LifeStage.active) {
      throw const GameException('この子の育成は終了しています。新しい子を迎えてください。');
    }
    if (text.trim().isEmpty) throw const GameException('今日の善行を入力してください。');
    // A deterministic local preview, never represented as AI judgement.
    final category = _category(text);
    final todayXp = data.deeds
        .where((d) => dayKey(d.at) == dayKey(clock()))
        .fold(0, (sum, d) => sum + d.xp);
    final xp = todayXp >= 50 ? 0 : 10;
    final hp = (100 - c.hp).clamp(0, 20);
    final attrs = [...c.attributes];
    attrs[category]++;
    final total = c.xp + xp;
    final evolution = total >= 200
        ? 2
        : total >= 100
        ? 1
        : 0;
    final next = c.copyWith(
      hp: c.hp + hp,
      xp: total,
      attributes: attrs,
      evolution: evolution,
    );
    final deed = Deed(
      id: requestId,
      characterId: c.id,
      text: text.trim(),
      at: clock(),
      category: category,
      xp: xp,
      hp: hp,
      praise: _praises[category],
    );
    final snapshot = await _save(
      GameSnapshot(
        name: data.name,
        characters: [...data.characters.take(data.characters.length - 1), next],
        deeds: [...data.deeds, deed],
      ),
    );
    return DeedResult(snapshot, deed, evolved: evolution > c.evolution);
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

  static const _praises = [
    'そのやさしさ、きっと届いたよ！',
    '小さな行動が、世界をきれいにするね。',
    'ありがとうの気持ち、あたたかいね。',
    '一歩踏み出せたあなた、すてきだね。',
    '力を合わせるって、うれしいね。',
    '正直な行動が、誰かの安心になるね。',
    '自分を大切にできて、えらいね。',
  ];
  @override
  Future<GameSnapshot> rename(String name) => _save(
    GameSnapshot(name: name, characters: data.characters, deeds: data.deeds),
  );
  @override
  Future<GameSnapshot> welcomeNext() async {
    final c = data.current;
    if (c.stage == LifeStage.active ||
        c.nextAvailableAt == null ||
        clock().isBefore(c.nextAvailableAt!)) {
      throw const GameException('新しい子は、育成終了の翌日から迎えられます。');
    }
    return _save(
      GameSnapshot(
        name: data.name,
        characters: [
          ...data.characters,
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
  Future<void> deleteAccount() async {
    await store.write(null);
    _data = null;
  }
}
