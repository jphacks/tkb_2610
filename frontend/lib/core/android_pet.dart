import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';

/// Only companion data crosses this channel; account credentials stay in the app.
class AndroidPet extends ChangeNotifier {
  static const channel = MethodChannel('jp.yoinoko.app/pet');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool allowed = false, running = false, busy = false;
  bool available = false;
  String? error;
  String? _lastCharacter;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final status = await channel.invokeMapMethod<String, dynamic>('status');
      available = status != null;
      allowed = status?['allowed'] == true;
      running = status?['running'] == true;
      error = null;
    } on PlatformException catch (e) {
      error = e.message ?? 'おでかけの状態を確認できませんでした。';
    } on MissingPluginException {
      error = 'Android版を更新して、もう一度お試しください。';
    }
    _notify();
  }

  Future<void> requestPermission() => _perform('permission');
  Future<void> start() => _perform('start');
  Future<void> stop() => _perform('stop');

  Future<void> _perform(String method) async {
    if (!supported || busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _pending;
      await channel.invokeMethod<void>(method);
      await refresh();
      if (method == 'stop') running = false;
    } on PlatformException catch (e) {
      error = e.message ?? 'おでかけを開始できませんでした。';
    } on MissingPluginException {
      error = 'Android版を更新して、もう一度お試しください。';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> sync(Companion? character) {
    if (!supported) return Future.value();
    final encoded = character == null ? null : jsonEncode(character.toJson());
    if (encoded == _lastCharacter) return _pending;
    _lastCharacter = encoded;
    _pending = _pending.then((_) async {
      try {
        await channel.invokeMethod<void>('sync', encoded);
        if (encoded == null) running = false;
      } on PlatformException catch (e) {
        _lastCharacter = null;
        error = e.message ?? 'よいのこの状態を更新できませんでした。';
      } on MissingPluginException {
        _lastCharacter = null;
        error = 'Android版を更新して、もう一度お試しください。';
      }
      _notify();
    });
    return _pending;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
