import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';
import 'result.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final GameController controller;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool tapped = false;
  bool assetsReady = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!assetsReady) {
      assetsReady = true;
      for (final name in ['initial', 'dome', 'turtle']) {
        precacheImage(AssetImage('assets/characters/$name.png'), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.snapshot!, c = data.current;
    final today =
        data.todayCount ??
        data.deeds.where((d) => dayKey(d.at) == dayKey(DateTime.now())).length;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  flex: widget.controller.composing ? 42 : 62,
                  child: const ColoredBox(
                    color: wall,
                    child: SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: widget.controller.composing ? 58 : 38,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: floor,
                      border: Border(top: BorderSide(color: line)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 32,
            left: 18,
            right: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 3,
                  child: Panel(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              'HP ${c.hp}/${c.maxHp}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.evolutionLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            ),
                            ...List.generate(
                              5,
                              (i) => Icon(
                                c.hp > i * c.maxHp / 5
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 15,
                                color: c.hp > i * c.maxHp / 5
                                    ? const Color(0xFFFF8C83)
                                    : line,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          c.nextEvolutionXp == null
                              ? 'XP ${c.xp}'
                              : 'XP ${c.xp}/${c.nextXp}',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        const SizedBox(height: 4),
                        ProgressTrack(value: c.progress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '今日の善行　$today件\nいっしょに ${c.daysAt(DateTime.now())}日目',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: box.maxHeight * (widget.controller.composing ? .32 : .56),
            left: 0,
            right: widget.controller.result == null ? 0 : box.maxWidth * .38,
            child: Center(
              child: CharacterView(
                character: c,
                size: 166,
                motion: widget.controller.result != null
                    ? CharacterMotion.happy
                    : tapped
                    ? CharacterMotion.tapped
                    : c.hp <= 20
                    ? CharacterMotion.lowEnergy
                    : CharacterMotion.idle,
                onTap: () {
                  setState(() => tapped = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => tapped = false);
                  });
                },
              ),
            ),
          ),
          if (widget.controller.result == null && !widget.controller.composing)
            Positioned(
              top: box.maxHeight * .53,
              left: box.maxWidth * .24,
              child: Panel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  tapped ? 'えへへ、ありがとう' : 'おかえり',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ),
          if (widget.controller.result != null)
            Positioned(
              top: box.maxHeight * .41,
              left: box.maxWidth * .38,
              right: 16,
              child: ResultBubble(controller: widget.controller),
            ),
        ],
      ),
    );
  }
}
