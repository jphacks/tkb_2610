import 'models.dart';

Map<String, dynamic> object(Object? value) {
  if (value is! Map) {
    throw const GameException('サーバーのデータ形式を確認してください。');
  }
  return Map<String, dynamic>.from(value);
}

DateTime? apiDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
DateTime? jstMidnight(Object? value) =>
    value is String ? DateTime.tryParse('${value}T00:00:00+09:00') : null;
Companion companionFromApi(
  Map<String, dynamic> j, {
  Map<String, dynamic>? evolution,
  bool? canCreateNext,
  DateTime? nextAvailableAt,
}) {
  final points = object(j['categoryPoints'] ?? {});
  final status = switch (j['status']) {
    'alive' => LifeStage.active,
    'dead' => LifeStage.sleeping,
    'retired' => LifeStage.completed,
    _ => throw const GameException('キャラクターの状態を読み取れませんでした。'),
  };
  // Unknown image IDs deliberately fall back to the starter until the asset catalog is supplied.
  final kind = switch (j['imageId']) {
    'base_01' => 'initial',
    'demo_turtle' => 'turtle',
    _ => 'initial',
  };
  return Companion(
    id: j['id'] as String,
    generation: j['generation'] as int,
    bornAt: DateTime.parse(j['createdAt']),
    hp: j['hp'] as int,
    maxHp: j['maxHp'] as int? ?? 100,
    xp: j['totalXp'] as int,
    level: j['level'] as int? ?? 1,
    evolution: j['evolutionStage'] as int,
    nextEvolutionXp: evolution?['nextEvolutionXp'] as int?,
    kind: kind,
    stage: status,
    endedAt: apiDate(j['diedAt']) ?? apiDate(j['endedAt']),
    lifespanDays: j['lifespanDays'] as int?,
    deedCount: j['deedCount'] as int?,
    nextAvailableAt: nextAvailableAt,
    canCreateNext: canCreateNext,
    attributes: pointKeys.map((key) => points[key] as int? ?? 0).toList(),
  );
}

Deed deedFromApi(Map<String, dynamic> j) {
  final category = categoryIds.indexOf(j['category'] as String);
  if (category < 0) {
    throw const GameException('善行のカテゴリを読み取れませんでした。');
  }
  return Deed(
    id: j['id'] as String,
    characterId: j['characterId'] as String,
    text: j['content'] as String,
    at: DateTime.parse(j['createdAt']),
    category: category,
    praise: j['praise'] as String,
    xp: j['earnedXp'] as int,
    hp: j['recoveredHp'] as int,
    categoryPoints: j['earnedCategoryPoints'] as int,
  );
}

PageResult<T> pageFromApi<T>(
  Map<String, dynamic> j,
  T Function(Map<String, dynamic>) convert,
) {
  final items = (j['items'] as List).map((v) => convert(object(v))).toList();
  return PageResult(
    items: items,
    totalCount: j['totalCount'] as int,
    hasMore: j['hasMore'] as bool,
    nextOffset: (j['offset'] as int) + items.length,
  );
}
