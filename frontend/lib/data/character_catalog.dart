const categoryIds = [
  'kindness',
  'environment',
  'gratitude',
  'courage',
  'cooperation',
  'honesty',
  'self_care',
];
const pointKeys = [
  'kindness',
  'environment',
  'gratitude',
  'courage',
  'cooperation',
  'honesty',
  'selfCare',
];
const attributeNames = ['思いやり', '環境保全', '感謝', '勇気', '協力', '誠実', 'セルフケア'];
const elementNames = ['光', '草', '風', '炎', '水', '鉱石', '月'];
const familyNames = ['クラゲ', 'シカ', 'ヒツジ', 'ライオン', 'クジラ', 'カメ', 'ネコ'];

class CharacterForm {
  const CharacterForm(this.imageId, {this.firstCategory, this.secondCategory});
  final String imageId;
  final int? firstCategory, secondCategory;
  int get stage => secondCategory != null
      ? 2
      : firstCategory != null
      ? 1
      : 0;
  String get assetPath => 'assets/characters/evolution/$imageId.png';
  String get label => firstCategory == null
      ? 'はじまりのよいのこ'
      : '${elementNames[secondCategory ?? firstCategory!]}・${familyNames[firstCategory!]}';
}

final characterForms = <String, CharacterForm>{
  'base_01': const CharacterForm('base_01'),
  for (var first = 0; first < categoryIds.length; first++)
    'stage1_${categoryIds[first]}': CharacterForm(
      'stage1_${categoryIds[first]}',
      firstCategory: first,
    ),
  for (var first = 0; first < categoryIds.length; first++)
    for (var second = 0; second < categoryIds.length; second++)
      'stage2_${categoryIds[first]}_${categoryIds[second]}': CharacterForm(
        'stage2_${categoryIds[first]}_${categoryIds[second]}',
        firstCategory: first,
        secondCategory: second,
      ),
};

/// Legacy local saves keep working; unknown server IDs retain the safe starter fallback.
CharacterForm characterForm(String kind) =>
    characterForms[kind] ??
    switch (kind) {
      'turtle' || 'demo_turtle' => characterForms['stage1_honesty']!,
      _ => characterForms['base_01']!,
    };
String knownCharacterKind(Object? imageId) =>
    imageId is String && characterForms.containsKey(imageId)
    ? imageId
    : imageId == 'demo_turtle'
    ? 'turtle'
    : 'initial';
