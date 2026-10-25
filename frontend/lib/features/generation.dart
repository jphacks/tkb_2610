import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';
import '../widgets/cloud_background.dart';

class GenerationPage extends StatefulWidget {
  const GenerationPage({super.key, required this.controller});
  final GameController controller;
  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage> {
  String? error;
  Future<void> welcome() async {
    try {
      await widget.controller.welcomeNext();
    } catch (e) {
      if (mounted) setState(() => error = GameController.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller.snapshot!.current;
    final available =
        c.canCreateNext ??
        (c.nextAvailableAt != null &&
            !DateTime.now().isBefore(c.nextAvailableAt!));
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          const Positioned.fill(child: CloudBackground(floorFraction: .43)),
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 200,
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.controller.snapshot!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${c.evolutionLabel}  ·  HP ${c.hp}/${c.maxHp}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'XP ${c.xp}',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
              Center(
                child: CharacterView(
                  character: c,
                  motion: CharacterMotion.sleeping,
                  size: 166,
                ),
              ),
              const SizedBox(height: 8),
              Panel(
                child: Column(
                  children: [
                    const Text(
                      'いっしょに過ごしてくれて、\nありがとう。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(c.stageLabel, style: const TextStyle(color: muted)),
                    Text('いっしょに ${c.daysAt(DateTime.now())}日'),
                    Text(
                      '善行 ${c.deedCount ?? widget.controller.snapshot!.deeds.where((d) => d.characterId == c.id).length}件',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'この子の記録は、歴代図鑑に残ります。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    if (!available)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          '新しい子は、明日から迎えられます。',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                    if (error != null) ErrorNotice(error!),
                    PrimaryButton(
                      label: '新しい子を迎える',
                      onPressed: available ? welcome : null,
                      busy: widget.controller.busy,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/gallery'),
                      child: const Text('歴代図鑑を見る'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
