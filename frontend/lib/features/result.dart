import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class ResultBubble extends StatelessWidget {
  const ResultBubble({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final result = controller.result!, d = result.deed;
    return Semantics(
      liveRegion: true,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      d.praise,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '結果を閉じる',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: controller.dismissResult,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _reward('XP', '+${d.xp}', orange),
                _reward(
                  attributeNames[d.category],
                  '+${d.categoryPoints}',
                  categoryColors[d.category],
                ),
                _reward('HP', '+${d.hp}', const Color(0xFFEF8798)),
              ],
            ),
            if (d.xp == 0)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '今日のXPは上限に到達。善行は記録できたよ。',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
            if (result.evolved)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '${result.snapshot.current.form.label}に進化したよ！',
                  style: TextStyle(fontSize: 12, color: orange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reward(String label, String value, Color color) => Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
