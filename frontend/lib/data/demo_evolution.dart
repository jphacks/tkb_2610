import 'models.dart';

/// Preview rules mirror the backend's current defaults. API mode never uses these.
const demoFirstEvolutionXp = 100;
const demoSecondEvolutionXp = 300;

int winningCategory(List<int> points, Iterable<Deed> deeds) {
  final latest = List<DateTime?>.filled(7, null);
  for (final d in deeds) {
    if (latest[d.category] == null || d.at.isAfter(latest[d.category]!)) {
      latest[d.category] = d.at;
    }
  }
  var winner = 0;
  for (var i = 1; i < 7; i++) {
    final newer =
        latest[i] != null &&
        (latest[winner] == null || latest[i]!.isAfter(latest[winner]!));
    if (points[i] > points[winner] || (points[i] == points[winner] && newer)) {
      winner = i;
    }
  }
  return winner;
}

Companion applyDemoEvolution(Companion c, Deed deed, List<Deed> history) {
  final attrs = [...c.attributes];
  attrs[deed.category] += deed.categoryPoints;
  final second = [...c.secondEvolutionPoints];
  if (c.evolution == 1) second[deed.category] += deed.categoryPoints;
  final xp = c.xp + deed.xp;
  var stage = c.evolution;
  var first = c.form.firstCategory;
  var finalCategory = c.form.secondCategory;
  var secondDate = c.secondEvolutionDate;
  final deeds = [...history.where((d) => d.characterId == c.id), deed];
  if (stage == 0 && xp >= demoFirstEvolutionXp) {
    first = winningCategory(attrs, deeds);
    stage = 1;
  }
  if (stage == 1 && xp >= demoSecondEvolutionXp) {
    finalCategory = winningCategory(second, deeds);
    secondDate = deed.at;
    stage = 2;
  }
  final kind = stage == 0
      ? 'base_01'
      : stage == 1
      ? 'stage1_${categoryIds[first!]}'
      : 'stage2_${categoryIds[first!]}_${categoryIds[finalCategory!]}';
  return c.copyWith(
    hp: c.hp + deed.hp,
    xp: xp,
    level: 1 + xp ~/ 50,
    attributes: attrs,
    secondEvolutionPoints: second,
    secondEvolutionDate: secondDate,
    evolution: stage,
    kind: kind,
    lifespanDays: stage == 2
        ? jstDay(secondDate!).difference(jstDay(c.bornAt)).inDays + 1
        : null,
    nextEvolutionXp: stage == 0
        ? demoFirstEvolutionXp
        : stage == 1
        ? demoSecondEvolutionXp
        : null,
  );
}

/// Old previews stored an evolution stage but never changed the starter image.
/// Recover the image from saved deeds, without erasing or downgrading progress.
Companion repairLegacyDemoForm(Companion c, List<Deed> history) {
  if (c.evolution == 0 || c.form.stage == c.evolution) return c;
  final deeds = history.where((d) => d.characterId == c.id).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final firstPoints = List.filled(7, 0), secondPoints = List.filled(7, 0);
  final firstDeeds = <Deed>[];
  var total = 0;
  for (final d in deeds) {
    if (total < demoFirstEvolutionXp) {
      firstPoints[d.category] += d.categoryPoints;
      firstDeeds.add(d);
    } else {
      secondPoints[d.category] += d.categoryPoints;
    }
    total += d.xp;
  }
  final first =
      c.form.firstCategory ??
      winningCategory(deeds.isEmpty ? c.attributes : firstPoints, firstDeeds);
  final second = winningCategory(secondPoints, deeds);
  return c.copyWith(
    kind: c.evolution == 1
        ? 'stage1_${categoryIds[first]}'
        : 'stage2_${categoryIds[first]}_${categoryIds[second]}',
    secondEvolutionPoints: secondPoints,
    secondEvolutionDate: c.evolution == 2
        ? c.endedAt ?? (deeds.isNotEmpty ? deeds.last.at : c.bornAt)
        : null,
    nextEvolutionXp: c.evolution == 1 ? demoSecondEvolutionXp : null,
  );
}

Companion settleDemoGeneration(Companion c, DateTime now) {
  if (c.evolution != 2 ||
      c.stage != LifeStage.active ||
      c.secondEvolutionDate == null) {
    return c;
  }
  final date = jstDay(c.secondEvolutionDate!);
  final next = date
      .add(const Duration(days: 1))
      .subtract(const Duration(hours: 9));
  if (now.isBefore(next)) return c;
  return c.copyWith(
    stage: LifeStage.completed,
    endedAt: next,
    nextAvailableAt: next,
    lifespanDays: date.difference(jstDay(c.bornAt)).inDays + 1,
  );
}
