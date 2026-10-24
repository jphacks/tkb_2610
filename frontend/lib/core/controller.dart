import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'evolution_event.dart';

class GameController extends ChangeNotifier {
  GameController(this.repository);
  final GameRepository repository;
  GameSnapshot? snapshot;
  bool loading = true, busy = false;
  String? error;
  DeedResult? result;
  EvolutionEvent? pendingEvolution;
  bool composing = false;
  void setComposing(bool value) {
    composing = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await repository.load();
    } catch (e) {
      error = message(e);
    }
    loading = false;
    notifyListeners();
  }

  static String message(Object e) =>
      e is GameException ? e.message : '通信または保存に失敗しました。もう一度お試しください。';
  Future<T> _run<T>(Future<T> Function() action) async {
    if (busy) throw const GameException('処理中です。少しお待ちください。');
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> register(String name) => _run(() async {
    snapshot = await repository.register(name);
  });
  Future<void> rename(String name) => _run(() async {
    _accept(await repository.rename(name));
  });
  Future<void> post(String text, String requestId) => _run(() async {
    final before = snapshot!.current;
    result = await repository.postDeed(text, requestId);
    _accept(result!.snapshot);
    final after = snapshot!.current;
    if (before.id == after.id && after.evolution > before.evolution) {
      pendingEvolution = EvolutionEvent(
        id: result!.deed.id,
        before: before,
        after: after,
      );
    }
  });
  Future<void> welcomeNext() => _run(() async {
    _accept(await repository.welcomeNext());
    result = null;
    pendingEvolution = null;
  });
  Future<void> deleteAccount() => _run(() async {
    await repository.deleteAccount();
    snapshot = null;
    result = null;
    pendingEvolution = null;
  });
  Future<PageResult<Companion>> history({int offset = 0}) async {
    final page = await repository.history(offset: offset);
    if (snapshot == null) return page;
    final chars = {
      for (final c in snapshot!.characters) c.id: c,
      for (final c in page.items) c.id: c,
    };
    // Preserve the authoritative current-character state and next-generation permissions.
    chars[snapshot!.current.id] = snapshot!.current;
    final ordered = chars.values.toList()
      ..sort((a, b) => a.generation.compareTo(b.generation));
    snapshot = GameSnapshot(
      name: snapshot!.name,
      characters: ordered,
      deeds: snapshot!.deeds,
      todayCount: snapshot!.todayCount,
    );
    notifyListeners();
    return page;
  }

  Future<PageResult<Deed>> deedsFor(String id, {int offset = 0}) async {
    final page = await repository.deedsFor(id, offset: offset);
    if (snapshot == null) return page;
    final deeds = {
      for (final d in snapshot!.deeds) d.id: d,
      for (final d in page.items) d.id: d,
    };
    snapshot = GameSnapshot(
      name: snapshot!.name,
      characters: snapshot!.characters,
      deeds: deeds.values.toList(),
      todayCount: snapshot!.todayCount,
    );
    notifyListeners();
    return page;
  }

  void _accept(GameSnapshot latest) {
    final chars = {
      for (final c in snapshot?.characters ?? <Companion>[]) c.id: c,
      for (final c in latest.characters) c.id: c,
    }.values.toList()..sort((a, b) => a.generation.compareTo(b.generation));
    final deeds = {
      for (final d in snapshot?.deeds ?? <Deed>[]) d.id: d,
      for (final d in latest.deeds) d.id: d,
    };
    snapshot = GameSnapshot(
      name: latest.name,
      characters: chars,
      deeds: deeds.values.toList(),
      todayCount: latest.todayCount,
    );
  }

  Future<void> refresh() async {
    if (busy || loading || snapshot == null || pendingEvolution != null) return;
    await _run(() async {
      final latest = await repository.load();
      if (latest != null) _accept(latest);
    });
  }

  void finishEvolution(String id) {
    if (pendingEvolution?.id != id) return;
    pendingEvolution = null;
    notifyListeners();
  }

  void dismissResult() {
    result = null;
    notifyListeners();
  }
}
