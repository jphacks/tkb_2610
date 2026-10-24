import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class EvolutionSound {
  bool get enabled;
  Future<void> prepare();
  Future<bool> playCharge();
  Future<bool> playReveal();
  Future<void> setEnabled(bool value);
  Future<void> stop();
  Future<void> dispose();
}

/// Sound is optional presentation: a playback or preference failure never affects a deed.
class LocalEvolutionSound implements EvolutionSound {
  AudioPlayer? _player;
  Future<void>? _preparation;
  bool _enabled = true, _disposed = false;
  int _epoch = 0;
  @override
  bool get enabled => _enabled;
  @override
  Future<void> prepare() => _preparation ??= _prepare();
  Future<void> _prepare() async {
    try {
      _enabled =
          (await SharedPreferences.getInstance()).getBool(
            'yoinoko.evolution.sound',
          ) ??
          true;
      if (_disposed) return;
      final player = _player = AudioPlayer();
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(.45);
    } catch (_) {
      /* Keep the visual sequence available on unsupported players. */
    }
  }

  Future<bool> _play(String file) async {
    final epoch = _epoch;
    try {
      await prepare();
      if (_disposed || !_enabled || epoch != _epoch || _player == null) {
        return false;
      }
      await _player!.play(AssetSource('audio/$file'), volume: .45);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> playCharge() => _play('evolution_charge.wav');
  @override
  Future<bool> playReveal() => _play('evolution_reveal.wav');
  @override
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    try {
      await (await SharedPreferences.getInstance()).setBool(
        'yoinoko.evolution.sound',
        value,
      );
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _epoch++;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _epoch++;
    try {
      await _player?.dispose();
    } catch (_) {}
  }
}
