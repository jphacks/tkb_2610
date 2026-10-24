import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/models.dart';
import 'package:ichinichi_ichizen/data/repository.dart';

class MemoryStore implements SnapshotStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async {
    if (fail) throw const GameException('保存失敗');
    value = next;
  }
}

void main() {
  test('再送で重複せず、保存失敗は再試行でき、XP上限は日本時間で切り替わる', () async {
    var now = DateTime.utc(2026, 10, 24, 14, 59);
    final store = MemoryStore();
    final repo = DemoRepository(store, clock: () => now);
    await repo.register('はる');
    final first = await repo.postDeed('席をゆずった', '1');
    expect(first.deed.hp, 0);
    expect((await repo.postDeed('席をゆずった', '1')).snapshot.deeds.length, 1);
    await expectLater(
      repo.postDeed('別の内容', '1'),
      throwsA(isA<GameException>()),
    );
    store.fail = true;
    await expectLater(
      repo.postDeed('ありがとう', '2'),
      throwsA(isA<GameException>()),
    );
    store.fail = false;
    expect((await repo.postDeed('ありがとう', '2')).snapshot.deeds.length, 2);
    for (var i = 3; i <= 6; i++) {
      final result = await repo.postDeed('ありがとう', '$i');
      expect(result.deed.xp, i == 6 ? 0 : 10);
    }
    now = DateTime.utc(2026, 10, 24, 15);
    expect((await repo.postDeed('ありがとう', '7')).deed.xp, 10);
    expect((await DemoRepository(store).load())!.deeds.length, 7);
  });
}
