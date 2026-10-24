import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller.snapshot!.current;
    final maxPoints = c.attributes.fold<int>(1, (a, b) => a > b ? a : b);
    return PageBody(
      title: 'ステータス',
      children: [
        Panel(
          child: Row(
            children: [
              CharacterView(character: c, size: 82),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第${c.generation}世代',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      c.evolutionLabel,
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Text('Lv.${c.level}  ·  XP ${c.xp}'),
                    const SizedBox(height: 6),
                    ProgressTrack(value: c.progress),
                    const SizedBox(height: 6),
                    Text(
                      c.evolution >= 2
                          ? '最終進化に到達したよ！'
                          : c.nextEvolutionXp == null
                          ? '次の進化を楽しみに'
                          : '次の進化まで ${(c.nextXp - c.xp).clamp(0, c.nextXp)} XP',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          7,
          (i) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: line, width: .5)),
            ),
            child: Row(
              children: [
                Icon(categoryIcons[i], color: categoryColors[i], size: 26),
                const SizedBox(width: 12),
                SizedBox(
                  width: 94,
                  child: Text(
                    attributeNames[i],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ProgressTrack(
                    value: c.attributes[i] / maxPoints,
                    color: categoryColors[i],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 28,
                  child: Text('${c.attributes[i]}', textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => context.go('/gallery/${c.id}'),
          icon: const Icon(Icons.history_rounded),
          label: const Text('この子との善行を見る'),
        ),
      ],
    );
  }
}
