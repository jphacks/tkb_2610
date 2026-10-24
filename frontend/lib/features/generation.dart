import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      children: [
        Center(
          child: CharacterView(
            character: c,
            motion: CharacterMotion.sleeping,
            size: 140,
          ),
        ),
        const SizedBox(height: 32),
        Panel(
          child: Column(
            children: [
              const Text(
                'いっしょに過ごしてくれて、\nありがとう。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(c.stageLabel, style: const TextStyle(color: muted)),
              Text('いっしょに ${c.daysAt(DateTime.now())}日'),
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
    );
  }
}
