import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repository.dart';

class GameController extends ChangeNotifier {
  GameController(this.repository);
  final GameRepository repository;
  GameSnapshot? snapshot;
  bool loading = true, busy = false;
  String? error;
  DeedResult? result;
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
    snapshot = await repository.rename(name);
  });
  Future<void> post(String text, String requestId) => _run(() async {
    result = await repository.postDeed(text, requestId);
    snapshot = result!.snapshot;
  });
  Future<void> welcomeNext() => _run(() async {
    snapshot = await repository.welcomeNext();
    result = null;
  });
  Future<void> deleteAccount() => _run(() async {
    await repository.deleteAccount();
    snapshot = null;
    result = null;
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

  Future<void> refresh() async {
    if (busy) return;
    final latest = await repository.load();
    if (latest != null) {
      snapshot = latest;
      notifyListeners();
    }
  }

  void dismissResult() {
    result = null;
    notifyListeners();
  }
}
