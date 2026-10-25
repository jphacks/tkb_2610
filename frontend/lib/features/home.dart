import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/character_speech.dart';
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
  final _speechRandom = math.Random();
  Timer? _tapTimer;
  String? _speechCharacterId, _speechImageId;
  late String _speech;

  @override
  void initState() {
    super.initState();
    _syncSpeech();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpeech();
  }

  // 再描画だけでは抽選せず、進化・世代交代でキャラが変わった時に更新。
  void _syncSpeech() {
    final character = widget.controller.snapshot!.current;
    if (_speechCharacterId == character.id &&
        _speechImageId == character.form.imageId) {
      return;
    }
    _speechCharacterId = character.id;
    _speechImageId = character.form.imageId;
    _speech = pickCharacterSpeech(character.kind, random: _speechRandom);
    _tapTimer?.cancel();
    tapped = false;
  }

  void _onCharacterTap() {
    _tapTimer?.cancel();
    setState(() {
      tapped = true;
      _speech = pickCharacterSpeech(
        widget.controller.snapshot!.current.kind,
        random: _speechRandom,
        previous: _speech,
      );
    });
    _tapTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => tapped = false);
    });
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!assetsReady) {
      assetsReady = true;
      precacheImage(const AssetImage('assets/characters/dome.png'), context);
      precacheImage(
        AssetImage(widget.controller.snapshot!.current.form.assetPath),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.snapshot!, c = data.current;
    final today =
        data.todayCount ??
        data.deeds.where((d) => dayKey(d.at) == dayKey(DateTime.now())).length;
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: SizedBox(
          height: math.max(
            viewport.maxHeight,
            MediaQuery.textScalerOf(context).scale(14) > 19
                ? 920
                : widget.controller.result != null ||
                      widget.controller.composing
                ? 680
                : viewport.maxHeight,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final composing = widget.controller.composing;
              final charSize = c.evolution == 0
                  ? 132.0
                  : box.maxWidth *
                        (composing
                            ? .48
                            : c.evolution == 1
                            ? .60
                            : .70);
              final feet =
                  box.maxHeight *
                  (composing
                      ? .43
                      : c.evolution == 0
                      ? .75
                      : .84);
              final charTop = feet - charSize;
              return Stack(
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                  ),
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
                    top: charTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CharacterView(
                        character: c,
                        size: charSize,
                        motion: widget.controller.result != null
                            ? CharacterMotion.happy
                            : tapped
                            ? CharacterMotion.tapped
                            : c.hp <= 20
                            ? CharacterMotion.lowEnergy
                            : CharacterMotion.idle,
                        onTap: _onCharacterTap,
                      ),
                    ),
                  ),
                  if (widget.controller.result == null &&
                      !widget.controller.composing)
                    Positioned(
                      top: charTop - 40,
                      left: box.maxWidth * .24,
                      right: 16,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            _speech,
                            key: const ValueKey('character-speech'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ),
                    ),
                  if (widget.controller.result != null)
                    Positioned(
                      top: box.maxHeight * .22,
                      left: 24,
                      right: 24,
                      child: ResultBubble(controller: widget.controller),
                    ),
                  if (!composing)
                    Positioned(
                      top: feet + 6,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: Text(
                          c.form.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
