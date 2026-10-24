enum LifeStage { active, sleeping, completed }

enum CharacterMotion { idle, happy, tapped, lowEnergy, sleeping }

const attributeNames = ['思いやり', '環境保護', '感謝', '勇気', '協力', '誠実', 'セルフケア'];
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
    this.hp = 100,
    this.xp = 0,
    this.evolution = 0,
    this.kind = 'initial',
    this.stage = LifeStage.active,
    this.endedAt,
    this.nextAvailableAt,
    this.attributes = const [0, 0, 0, 0, 0, 0, 0],
  });
  final String id, kind;
  final int generation, hp, xp, evolution;
  final DateTime bornAt;
  final DateTime? endedAt, nextAvailableAt;
  final LifeStage stage;
  final List<int> attributes;
  String get stageLabel => switch (stage) {
    LifeStage.active => '育成中',
    LifeStage.sleeping => 'おやすみ',
    LifeStage.completed => '育成完了',
  };
  String get evolutionLabel => evolution == 0 ? '初期形態' : '第$evolution進化';
  int daysAt(DateTime now) =>
      jstDay(endedAt ?? now).difference(jstDay(bornAt)).inDays + 1;
  int get nextXp => evolution == 0 ? 100 : 200;
  double get progress => (xp / nextXp).clamp(0.0, 1.0);
  Companion copyWith({
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
    'hp': hp,
    'xp': xp,
    'evolution': evolution,
    'kind': kind,
    'stage': stage.name,
    'endedAt': endedAt?.toIso8601String(),
    'nextAvailableAt': nextAvailableAt?.toIso8601String(),
    'attributes': attributes,
  };
  factory Companion.fromJson(Map<String, dynamic> j) => Companion(
    id: j['id'],
    generation: j['generation'],
    bornAt: DateTime.parse(j['bornAt']),
    hp: j['hp'],
    xp: j['xp'],
    evolution: j['evolution'],
    kind: j['kind'],
    stage: LifeStage.values.byName(j['stage']),
    endedAt: DateTime.tryParse(j['endedAt'] ?? ''),
    nextAvailableAt: DateTime.tryParse(j['nextAvailableAt'] ?? ''),
    attributes: List<int>.from(j['attributes']),
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
  });
  final String id, characterId, text, praise;
  final DateTime at;
  final int category, xp, hp;
  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'text': text,
    'at': at.toIso8601String(),
    'category': category,
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
  });
  final String name;
  final List<Companion> characters;
  final List<Deed> deeds;
  Companion get current => characters.last;
  Map<String, dynamic> toJson() => {
    'name': name,
    'characters': characters.map((c) => c.toJson()).toList(),
    'deeds': deeds.map((d) => d.toJson()).toList(),
  };
  factory GameSnapshot.fromJson(Map<String, dynamic> j) => GameSnapshot(
    name: j['name'],
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
