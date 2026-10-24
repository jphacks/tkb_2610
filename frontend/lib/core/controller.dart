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
  void dismissResult() {
    result = null;
    notifyListeners();
  }
}
