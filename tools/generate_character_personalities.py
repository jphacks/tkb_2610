#!/usr/bin/env python3
"""性格設定の正本から、Flutterデモ向けのデータを生成する。--check で差分を検出。"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'backend/src/config/character-personalities.json'
TARGET = ROOT / 'frontend/lib/data/character_personalities.dart'
CATEGORIES = ['kindness', 'environment', 'gratitude', 'courage', 'cooperation', 'honesty', 'self_care']
EXPECTED_IDS = {'base_01'} | {f'stage1_{c}' for c in CATEGORIES} | {
    f'stage2_{a}_{b}' for a in CATEGORIES for b in CATEGORIES
}


def generate():
    profiles = json.loads(SOURCE.read_text())
    if set(profiles) != EXPECTED_IDS:
        raise SystemExit('57種類のキャラクターIDが一致しません。')
    lines = [
        '// 自動生成。backend/src/config/character-personalities.json を編集し、',
        '// python3 tools/generate_character_personalities.py で更新してください。',
        "import 'character_catalog.dart';", '',
        'class CharacterPersonality {',
        '  const CharacterPersonality({',
        '    required this.name,',
        '    required this.personality,',
        '    required this.firstPerson,',
        '    required this.tone,',
        '    required this.demoTemplate,',
        '  });',
        '  final String name, personality, firstPerson, tone, demoTemplate;',
        '}', '',
        'const characterPersonalities = <String, CharacterPersonality>{',
    ]
    # JSONの二重引用符はDartでも使える。Dartの文字列展開だけは無効にする。
    def dart_string(value):
        return json.dumps(value, ensure_ascii=False).replace('$', r'\$')
    for image_id, profile in profiles.items():
        if set(profile) != {'name', 'personality', 'firstPerson', 'tone', 'demoTemplate'}:
            raise SystemExit(f'{image_id}: 項目が一致しません。')
        if any(not isinstance(v, str) or not v.strip() for v in profile.values()):
            raise SystemExit(f'{image_id}: 空の設定があります。')
        if profile['demoTemplate'].count('{action}') != 1:
            raise SystemExit(f'{image_id}: demoTemplate には {{action}} が1つ必要です。')
        lines += [f'  {dart_string(image_id)}: CharacterPersonality(']
        for field, value in profile.items():
            lines.append(f'    {field}: {dart_string(value)},')
        lines += ['  ),']
    lines += [
        '};', '',
        'CharacterPersonality characterPersonality(String kind) =>',
        '    characterPersonalities[characterForm(kind).imageId]!;', '',
    ]
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    content = generate()
    if args.check:
        if not TARGET.exists() or TARGET.read_text() != content:
            raise SystemExit('生成ファイルが古いです。python3 tools/generate_character_personalities.py を実行してください。')
        print('57キャラの性格設定は同期しています。')
    else:
        TARGET.write_text(content)
        print('57キャラの性格設定を生成しました。')
