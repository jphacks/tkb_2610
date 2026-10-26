import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/cloud_background.dart';

/// A local-only preview; never reads or writes the player's companion.
class PonoPreview extends StatefulWidget {
  const PonoPreview({super.key});

  @override
  State<PonoPreview> createState() => _PonoPreviewState();
}

class _PonoPreviewState extends State<PonoPreview> {
  static const labels = ['いつも', 'あるく', 'なでる', 'よろこぶ', 'つかれた', 'おやすみ'];
  static const motions = [
    CharacterMotion.idle,
    CharacterMotion.idle,
    CharacterMotion.tapped,
    CharacterMotion.happy,
    CharacterMotion.lowEnergy,
    CharacterMotion.sleeping,
  ];
  final _pono = Companion(
    id: 'pono-preview',
    generation: 1,
    bornAt: DateTime.utc(2026),
    kind: 'base_01',
  );
  int _selected = 0;
  bool _playing = true, _right = true;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ポノ',
                      style: TextStyle(
                        color: ink,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: _playing ? '動きを止める' : '動かす',
                    child: TextButton(
                      onPressed: () => setState(() => _playing = !_playing),
                      child: Text(_playing ? 'とめる' : 'うごかす'),
                    ),
                  ),
                  Tooltip(
                    message: '閉じる',
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 270,
              // The cloud painter deliberately draws beyond its box on full
              // screens. Keep those clouds away from the dialog's controls.
              child: ClipRect(
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CloudBackground(floorFraction: .76),
                    ),
                    Center(
                      child: CharacterView(
                        character: _pono,
                        size: 260,
                        motion: motions[_selected],
                        animate: _playing,
                        walking: _selected == 1,
                        facingRight: _right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: List.generate(
                      labels.length,
                      (i) => ChoiceChip(
                        label: Text(labels[i]),
                        selected: _selected == i,
                        onSelected: (_) => setState(() => _selected = i),
                      ),
                    ),
                  ),
                  if (_selected == 1)
                    TextButton.icon(
                      onPressed: () => setState(() => _right = !_right),
                      icon: Icon(
                        _right
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_back_rounded,
                      ),
                      label: const Text('向きを変える'),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'タップでも反応します',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
