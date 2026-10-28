import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/cloud_background.dart';
import '../widgets/room_character.dart';

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
  Offset _direction = const Offset(1, 0);
  bool _roomReacting = false;
  Timer? _roomTapTimer;

  void _petRoom() {
    _roomTapTimer?.cancel();
    setState(() => _roomReacting = true);
    _roomTapTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _roomReacting = false);
    });
  }

  @override
  void dispose() {
    _roomTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = _kind == 'stage1_self_care';
    final room = cat && _selected == 6;
    final choices = [...labels, if (cat) 'おさんぽ'];
    return Dialog(
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
                              if (kind != null) {
                                setState(() {
                                  _kind = kind;
                                  if (_selected >= motions.length) {
                                    _selected = 0;
                                  }
                                });
                              }
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
                height: room ? 340 : 270,
                // The cloud painter deliberately draws beyond its box on full
                // screens. Keep those clouds away from the dialog's controls.
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CloudBackground(floorFraction: room ? .48 : .76),
                      ),
                      if (room)
                        Positioned.fill(
                          child: RoomCharacter(
                            character: _character,
                            size: 160,
                            top: 180,
                            speech: null,
                            motion: _roomReacting
                                ? CharacterMotion.tapped
                                : CharacterMotion.idle,
                            roam: _playing,
                            showLabels: false,
                            onTap: _petRoom,
                          ),
                        )
                      else
                        Center(
                          child: CharacterView(
                            key: ValueKey('preview-character-$_kind'),
                            character: _character,
                            size: 260,
                            motion: motions[_selected],
                            animate: _playing,
                            walking: _selected == 1,
                            facingRight: _right,
                            travelDirection: cat ? _direction : null,
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
                        choices.length,
                        (i) => ChoiceChip(
                          label: Text(choices[i]),
                          selected: _selected == i,
                          onSelected: (_) => setState(() => _selected = i),
                        ),
                      ),
                    ),
                    if (cat && _selected == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final item in const [
                              (Offset(-1, 0), Icons.arrow_back_rounded, '左へ歩く'),
                              (
                                Offset(0, -1),
                                Icons.arrow_upward_rounded,
                                '奥へ歩く',
                              ),
                              (
                                Offset(0, 1),
                                Icons.arrow_downward_rounded,
                                '手前へ歩く',
                              ),
                              (
                                Offset(1, 0),
                                Icons.arrow_forward_rounded,
                                '右へ歩く',
                              ),
                            ])
                              IconButton.filledTonal(
                                tooltip: item.$3,
                                isSelected: _direction == item.$1,
                                onPressed: () =>
                                    setState(() => _direction = item.$1),
                                icon: Icon(item.$2),
                              ),
                          ],
                        ),
                      )
                    else if (_selected == 1)
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
}
