import 'package:flutter_test/flutter_test.dart';
import 'package:ichinichi_ichizen/data/api_mapper.dart';
import 'package:ichinichi_ichizen/data/models.dart';

void main() {
  test(
    'Guest response accepts fractional dates and never invents XP thresholds',
    () {
      final c = companionFromApi({
        'id': 'a',
        'generation': 1,
        'imageId': 'base_01',
        'hp': 100,
        'maxHp': 100,
        'totalXp': 0,
        'level': 1,
        'evolutionStage': 0,
        'status': 'alive',
        'createdAt': '2026-10-24T03:00:00.123456+00:00',
      });
      expect(c.nextEvolutionXp, isNull);
      expect(c.form.imageId, 'base_01');
      expect(c.bornAt.isUtc, true);
    },
  );
  test('Dead API state is displayed as おやすみ with server lifespan', () {
    final c = companionFromApi({
      'id': 'a',
      'generation': 2,
      'imageId': 'future',
      'hp': 0,
      'totalXp': 44,
      'evolutionStage': 1,
      'status': 'dead',
      'createdAt': '2026-10-01T00:00:00Z',
      'diedAt': '2026-10-14T00:00:00Z',
      'lifespanDays': 14,
    });
    expect(c.stage, LifeStage.sleeping);
    expect(c.stageLabel, 'おやすみ');
    expect(c.daysAt(DateTime.now()), 14);
  });
  test('Self care category uses snake case ID and actual rewards', () {
    final d = deedFromApi({
      'id': 'd',
      'characterId': 'a',
      'content': '休んだ',
      'category': 'self_care',
      'praise': 'おつかれさま',
      'earnedXp': 0,
      'earnedCategoryPoints': 0,
      'recoveredHp': 10,
      'createdAt': '2026-10-24T00:00:00Z',
    });
    expect(d.category, 6);
    expect(d.categoryPoints, 0);
    expect(d.hp, 10);
  });
  test('JST midnight is the previous UTC day', () {
    expect(jstMidnight('2026-10-25'), DateTime.utc(2026, 10, 24, 15));
  });
}
