import 'package:ichinichi_ichizen/core/evolution_sound.dart';

class FakeEvolutionSound implements EvolutionSound {
  FakeEvolutionSound({this.fail = false});
  final bool fail;
  @override
  bool enabled = true;
  int charges = 0, reveals = 0, stops = 0;
  bool disposed = false;
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> playCharge() async {
    if (enabled) charges++;
    return enabled && !fail;
  }

  @override
  Future<bool> playReveal() async {
    if (enabled) reveals++;
    return enabled && !fail;
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) await stop();
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
