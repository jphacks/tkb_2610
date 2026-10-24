import 'character_catalog.dart';
export 'character_catalog.dart';

const _unchanged = Object();

enum LifeStage { active, sleeping, completed }

enum CharacterMotion { idle, happy, tapped, lowEnergy, sleeping }

DateTime jstDay(DateTime time) {
  final t = time.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(t.year, t.month, t.day);
}

String dayKey(DateTime t) => jstDay(t).toIso8601String().substring(0, 10);
String shortDate(DateTime t) {
  final d = jstDay(t);
  return '${d.month}/${d.day}';
}

class Companion {
  const Companion({
    required this.id,
    required this.generation,
    required this.bornAt,
    this.maxHp = 100,
    this.level = 1,
    this.nextEvolutionXp = 100,
    this.lifespanDays,
    this.deedCount,
    this.canCreateNext,
    this.hp = 100,
    this.xp = 0,
    this.evolution = 0,
    this.kind = 'initial',
    this.stage = LifeStage.active,
    this.endedAt,
    this.nextAvailableAt,
    this.attributes = const [0, 0, 0, 0, 0, 0, 0],
    this.secondEvolutionPoints = const [0, 0, 0, 0, 0, 0, 0],
    this.secondEvolutionDate,
  });
  final String id, kind;
  final int generation, hp, xp, evolution, maxHp, level;
  final int? nextEvolutionXp, lifespanDays, deedCount;
  final bool? canCreateNext;
  final DateTime bornAt;
  final DateTime? endedAt, nextAvailableAt;
  final LifeStage stage;
  final List<int> attributes, secondEvolutionPoints;
  final DateTime? secondEvolutionDate;
  CharacterForm get form => characterForm(kind);
  String get stageLabel => switch (stage) {
    LifeStage.active => '育成中',
    LifeStage.sleeping => 'おやすみ',
    LifeStage.completed => '育成完了',
  };
  String get evolutionLabel => evolution == 0 ? '初期形態' : '第$evolution進化';
  int daysAt(DateTime now) =>
      lifespanDays ??
      (jstDay(endedAt ?? now).difference(jstDay(bornAt)).inDays + 1);
  int get nextXp => nextEvolutionXp ?? (xp > 0 ? xp : 1);
  double get progress => nextEvolutionXp == null
      ? (evolution == 2 ? 1 : 0)
      : (xp / nextXp).clamp(0.0, 1.0);
  Companion copyWith({
    Object? nextEvolutionXp = _unchanged,
    int? level,
    int? lifespanDays,
    List<int>? secondEvolutionPoints,
    DateTime? secondEvolutionDate,
    int? hp,
    int? xp,
    int? evolution,
    String? kind,
    List<int>? attributes,
    LifeStage? stage,
    DateTime? endedAt,
    DateTime? nextAvailableAt,
  }) => Companion(
    id: id,
    generation: generation,
    bornAt: bornAt,
    maxHp: maxHp,
    level: level ?? this.level,
    nextEvolutionXp: identical(nextEvolutionXp, _unchanged)
        ? this.nextEvolutionXp
        : nextEvolutionXp as int?,
    lifespanDays: lifespanDays ?? this.lifespanDays,
    secondEvolutionPoints: secondEvolutionPoints ?? this.secondEvolutionPoints,
    secondEvolutionDate: secondEvolutionDate ?? this.secondEvolutionDate,
    deedCount: deedCount,
    canCreateNext: canCreateNext,
    hp: hp ?? this.hp,
    xp: xp ?? this.xp,
    evolution: evolution ?? this.evolution,
    kind: kind ?? this.kind,
    attributes: attributes ?? this.attributes,
    stage: stage ?? this.stage,
    endedAt: endedAt ?? this.endedAt,
    nextAvailableAt: nextAvailableAt ?? this.nextAvailableAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'generation': generation,
    'bornAt': bornAt.toIso8601String(),
    'maxHp': maxHp,
    'level': level,
    'nextEvolutionXp': nextEvolutionXp,
    'lifespanDays': lifespanDays,
    'deedCount': deedCount,
    'canCreateNext': canCreateNext,
    'hp': hp,
    'xp': xp,
    'evolution': evolution,
    'kind': kind,
    'stage': stage.name,
    'endedAt': endedAt?.toIso8601String(),
    'nextAvailableAt': nextAvailableAt?.toIso8601String(),
    'attributes': attributes,
    'secondEvolutionPoints': secondEvolutionPoints,
    'secondEvolutionDate': secondEvolutionDate?.toIso8601String(),
  };
  factory Companion.fromJson(Map<String, dynamic> j) => Companion(
    id: j['id'],
    generation: j['generation'],
    bornAt: DateTime.parse(j['bornAt']),
    maxHp: j['maxHp'] ?? 100,
    level: j['level'] ?? 1,
    nextEvolutionXp: j.containsKey('nextEvolutionXp')
        ? j['nextEvolutionXp']
        : 100,
    lifespanDays: j['lifespanDays'],
    deedCount: j['deedCount'],
    canCreateNext: j['canCreateNext'],
    hp: j['hp'],
    xp: j['xp'],
    evolution: j['evolution'],
    kind: j['kind'],
    stage: LifeStage.values.byName(j['stage']),
    endedAt: DateTime.tryParse(j['endedAt'] ?? ''),
    nextAvailableAt: DateTime.tryParse(j['nextAvailableAt'] ?? ''),
    attributes: List<int>.from(j['attributes']),
    secondEvolutionPoints: List<int>.from(
      j['secondEvolutionPoints'] ?? List.filled(7, 0),
    ),
    secondEvolutionDate: DateTime.tryParse(j['secondEvolutionDate'] ?? ''),
  );
}

class Deed {
  const Deed({
    required this.id,
    required this.characterId,
    required this.text,
    required this.at,
    required this.category,
    required this.praise,
    required this.xp,
    required this.hp,
    this.categoryPoints = 1,
  });
  final String id, characterId, text, praise;
  final DateTime at;
  final int category, xp, hp, categoryPoints;
  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'text': text,
    'at': at.toIso8601String(),
    'category': category,
    'categoryPoints': categoryPoints,
    'praise': praise,
    'xp': xp,
    'hp': hp,
  };
  factory Deed.fromJson(Map<String, dynamic> j) => Deed(
    id: j['id'],
    characterId: j['characterId'],
    text: j['text'],
    at: DateTime.parse(j['at']),
    category: j['category'],
    categoryPoints: j['categoryPoints'] ?? 1,
    praise: j['praise'],
    xp: j['xp'],
    hp: j['hp'],
  );
}

class GameSnapshot {
  const GameSnapshot({
    required this.name,
    required this.characters,
    this.deeds = const [],
    this.todayCount,
  });
  final String name;
  final int? todayCount;
  final List<Companion> characters;
  final List<Deed> deeds;
  Companion get current => characters.last;
  Map<String, dynamic> toJson() => {
    'name': name,
    'todayCount': todayCount,
    'characters': characters.map((c) => c.toJson()).toList(),
    'deeds': deeds.map((d) => d.toJson()).toList(),
  };
  factory GameSnapshot.fromJson(Map<String, dynamic> j) => GameSnapshot(
    name: j['name'],
    todayCount: j['todayCount'],
    characters: (j['characters'] as List)
        .map((c) => Companion.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
    deeds: (j['deeds'] as List)
        .map((d) => Deed.fromJson(Map<String, dynamic>.from(d)))
        .toList(),
  );
}

class DeedResult {
  const DeedResult(this.snapshot, this.deed, {this.evolved = false});
  final GameSnapshot snapshot;
  final Deed deed;
  final bool evolved;
}

class GameException implements Exception {
  const GameException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    required this.nextOffset,
  });
  final List<T> items;
  final int totalCount, nextOffset;
  final bool hasMore;
}
