import 'character_personalities.dart';

/// デモ用。実際のAPIでは、投稿内容に合う具体的な文章をAIが生成します。
const demoPraiseActions = [
  '人にやさしくできた',
  '自然を大切にできた',
  '感謝を伝えられた',
  '勇気を出して踏み出せた',
  '力を合わせられた',
  '誠実に行動できた',
  '自分を大切にできた',
];

String demoCharacterPraise(String kind, int category) => characterPersonality(
  kind,
).demoTemplate.replaceAll('{action}', demoPraiseActions[category]);
