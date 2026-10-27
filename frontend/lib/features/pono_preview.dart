import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/cloud_background.dart';

/// A local-only preview; never reads or writes the player's companion.
class PonoPreview extends StatefulWidget {
  const PonoPreview({super.key, this.initialKind = 'base_01'});
  final String initialKind;

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
  late String _kind = characterForm(widget.initialKind).stage <= 1
      ? characterForm(widget.initialKind).imageId
      : 'base_01';
  Companion get _character => Companion(
    id: 'animation-preview-$_kind',
    generation: 1,
    bornAt: DateTime.utc(2026),
    kind: _kind,
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
                  Expanded(
                    child: Semantics(
                      label: 'キャラクターを選ぶ',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _kind,
                          isExpanded: true,
                          style: const TextStyle(
                            color: ink,
                            fontFamily: 'Rounded',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          items: [
                            for (final kind in [
                              'base_01',
                              for (final category in categoryIds)
                                'stage1_$category',
                            ])
                              DropdownMenuItem(
                                value: kind,
                                child: Text(
                                  characterForm(kind).name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (kind) {
                            if (kind != null) setState(() => _kind = kind);
                          },
                        ),
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
                        key: ValueKey('preview-character-$_kind'),
                        character: _character,
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
