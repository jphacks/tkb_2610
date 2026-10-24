import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';

class DisplayCase extends StatelessWidget {
  const DisplayCase({super.key, required this.character});
  final Companion character;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 4,
    child: LayoutBuilder(
      builder: (context, b) => Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/characters/dome.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: b.maxWidth * .13,
            right: b.maxWidth * .13,
            bottom: b.maxHeight * .22,
            child: CharacterView(
              character: character,
              size: b.maxWidth * .74,
              animate: false,
            ),
          ),
          Positioned(
            left: b.maxWidth * .20,
            right: b.maxWidth * .20,
            bottom: b.maxHeight * .085,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '第${character.generation}世代',
                style: const TextStyle(
                  color: Color(0xFF573721),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final items = controller.snapshot!.characters.reversed.toList();
    return PageBody(
      title: '歴代図鑑',
      trailing: Text('${items.length}体', style: const TextStyle(color: muted)),
      children: [
        LayoutBuilder(
          builder: (context, b) => Wrap(
            spacing: 14,
            runSpacing: 24,
            children: items
                .map(
                  (c) => SizedBox(
                    width: (b.maxWidth - 14) / 2,
                    child: Semantics(
                      button: true,
                      label: '第${c.generation}世代、${c.stageLabel}の育成記録',
                      child: InkWell(
                        onTap: () => context.go('/gallery/${c.id}'),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          children: [
                            DisplayCase(character: c),
                            const SizedBox(height: 8),
                            Text(
                              c.stageLabel,
                              style: TextStyle(
                                color: c.stage == LifeStage.active
                                    ? ink
                                    : muted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${shortDate(c.bornAt)}〜${c.endedAt == null ? '' : shortDate(c.endedAt!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                            Text(
                              '${c.daysAt(DateTime.now())}日${c.stage == LifeStage.active ? '目' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (items.length == 1)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Text(
              'これから増えていく、この子たちとの思い出。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
      ],
    );
  }
}

class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    super.key,
    required this.controller,
    required this.characterId,
  });
  final GameController controller;
  final String characterId;
  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  int limit = 20;
  @override
  Widget build(BuildContext context) {
    final matches = widget.controller.snapshot!.characters.where(
      (c) => c.id == widget.characterId,
    );
    if (matches.isEmpty) {
      return PageBody(
        title: '育成記録',
        children: [
          const Text('この子の記録が見つかりませんでした。'),
          TextButton(
            onPressed: () => context.go('/gallery'),
            child: const Text('図鑑へ戻る'),
          ),
        ],
      );
    }
    final c = matches.first;
    final deeds =
        widget.controller.snapshot!.deeds
            .where((d) => d.characterId == c.id)
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    return PageBody(
      title: '育成記録',
      trailing: IconButton(
        tooltip: '図鑑へ戻る',
        onPressed: () => context.go('/gallery'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      children: [
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: DisplayCase(character: c)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第${c.generation}世代',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        Text(
                          c.stageLabel,
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 12),
                        Text(c.evolutionLabel),
                        Text('いっしょに ${c.daysAt(DateTime.now())}日'),
                        const Divider(height: 24),
                        Text('累計XP　${c.xp}'),
                        Text('善行　${deeds.length}件'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${shortDate(c.bornAt)} 〜 ${c.endedAt == null ? 'いま' : shortDate(c.endedAt!)}',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'この子との善行',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (deeds.isEmpty)
          const Panel(
            child: Column(
              children: [
                Icon(Icons.auto_stories_outlined, color: muted, size: 32),
                SizedBox(height: 12),
                Text('まだ記録はありません'),
                Text(
                  '小さな善いことから、残してみよう。',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ...deeds
            .take(limit)
            .map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${shortDate(d.at)}  ${d.at.toUtc().add(const Duration(hours: 9)).hour.toString().padLeft(2, '0')}:${d.at.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        d.text,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            categoryIcons[d.category],
                            color: categoryColors[d.category],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            attributeNames[d.category],
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            'XP +${d.xp}',
                            style: const TextStyle(
                              color: orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        d.praise,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        if (limit < deeds.length)
          OutlinedButton(
            onPressed: () => setState(() => limit += 20),
            child: const Text('もっと見る'),
          ),
      ],
    );
  }
}
