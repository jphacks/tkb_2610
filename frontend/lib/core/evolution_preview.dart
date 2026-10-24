import 'dart:math';
import '../data/models.dart';
import 'evolution_event.dart';

/// Separate from saved progression. Each stage cycles through all its forms.
class EvolutionPreviewPicker {
  EvolutionPreviewPicker({Random? random}) : _random = random ?? Random();
  final Random _random;
  final _remaining = <int, List<CharacterForm>>{};
  final _last = <int, String>{};

  EvolutionEvent next({required bool second}) {
    final stage = second ? 2 : 1;
    final pool = _remaining.putIfAbsent(stage, () => []);
    if (pool.isEmpty) {
      pool.addAll(characterForms.values.where((form) => form.stage == stage));
      pool.shuffle(_random);
      if (pool.last.imageId == _last[stage]) {
        final first = pool.first;
        pool[0] = pool.last;
        pool[pool.length - 1] = first;
      }
    }
    final form = pool.removeLast();
    _last[stage] = form.imageId;
    final before = Companion(
      id: 'preview',
      generation: 1,
      bornAt: DateTime.now(),
      evolution: second ? 1 : 0,
      kind: second ? 'stage1_${categoryIds[form.firstCategory!]}' : 'base_01',
    );
    return EvolutionEvent(
      id: 'preview-${form.imageId}',
      before: before,
      after: before.copyWith(evolution: stage, kind: form.imageId),
    );
  }
}
