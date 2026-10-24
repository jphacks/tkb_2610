import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/evolution_event.dart';
import '../core/evolution_sound.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/common.dart';

class EvolutionScene extends StatefulWidget {
  const EvolutionScene({
    super.key,
    required this.event,
    required this.onClose,
    this.sound,
  });
  final EvolutionEvent event;
  final VoidCallback onClose;
  final EvolutionSound? sound;
  @override
  State<EvolutionScene> createState() => _EvolutionSceneState();
}

class _EvolutionSceneState extends State<EvolutionScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController timeline = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.event.after.evolution == 2 ? 6500 : 5500,
    ),
  )..addListener(onFrame);
  late final EvolutionSound sound = widget.sound ?? LocalEvolutionSound();
  bool started = false, ready = false, reduced = false, foreground = true;
  bool chargePlayed = false,
      revealPlayed = false,
      skipped = false,
      soundBlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (!started) {
      started = true;
      unawaited(start());
    } else if (reduced && timeline.value < 1) {
      skip();
    }
  }

  Future<void> start() async {
    unawaited(
      sound.prepare().then((_) {
        if (mounted) setState(() {});
      }),
    );
    // Decode both images before the swap, so slow image loading cannot produce an empty reveal.
    await Future.wait([
      precacheImage(
        AssetImage(widget.event.before.form.assetPath),
        context,
        onError: (_, _) {},
      ),
      precacheImage(
        AssetImage(widget.event.after.form.assetPath),
        context,
        onError: (_, _) {},
      ),
    ]);
    if (!mounted) return;
    setState(() => ready = true);
    if (reduced) {
      timeline.value = 1;
    } else if (foreground) {
      timeline.forward();
    }
  }

  void onFrame() {
    final p = timeline.value;
    if (!skipped && !reduced && foreground) {
      if (p >= .18 && !chargePlayed) {
        chargePlayed = true;
        unawaited(play(false));
      }
      if (p >= .50 && !revealPlayed) {
        revealPlayed = true;
        unawaited(play(true));
      }
    }
  }

  Future<void> play(bool reveal) async {
    final played = reveal ? await sound.playReveal() : await sound.playCharge();
    if (mounted && sound.enabled && !played) {
      setState(() => soundBlocked = true);
    }
  }

  void skip() {
    skipped = true;
    unawaited(sound.stop());
    timeline.stop();
    timeline.value = 1;
  }

  Future<void> toggleSound() async {
    final enable = !sound.enabled || soundBlocked;
    await sound.setEnabled(enable);
    if (!mounted) return;
    setState(() => soundBlocked = false);
    if (enable && foreground && timeline.value < 1 && !skipped) {
      unawaited(play(timeline.value >= .5));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      timeline.stop();
      unawaited(sound.stop());
    } else if (ready && !reduced && timeline.value < 1) {
      timeline.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timeline.dispose();
    unawaited(sound.dispose());
    super.dispose();
  }

  double ramp(double p, double from, double to) =>
      ((p - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final form = widget.event.after.form;
    final color = [
      const Color(0xFFF4C766),
      const Color(0xFF9DC877),
      const Color(0xFFEFACB6),
      const Color(0xFFF4A368),
      const Color(0xFF8ABFEA),
      const Color(0xFFBBA385),
      const Color(0xFFB5A0E4),
    ][form.secondCategory ?? form.firstCategory ?? 0];
    return Material(
      color: wall,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: '進化',
        child: AnimatedBuilder(
          animation: timeline,
          builder: (context, _) {
            final p = timeline.value, done = p >= 1;
            final gathering = ramp(p, .18, .5);
            final reveal = ramp(p, .5, .69);
            final light = (ramp(p, .18, .43) * (1 - ramp(p, .56, .69))).clamp(
              0.0,
              1.0,
            );
            final dark = (ramp(p, 0, .18) * (1 - ramp(p, .66, .9))).clamp(
              0.0,
              1.0,
            );
            final arrival = Curves.easeOutBack.transform(ramp(p, .5, .75));
            final bounce = reduced
                ? 0.0
                : math.sin(ramp(p, .69, .88) * math.pi) * 20;
            return LayoutBuilder(
              builder: (context, box) {
                final pictureSize = math.min(
                  box.maxWidth * .82,
                  box.maxHeight * .43,
                );
                final center = Offset(
                  box.maxWidth / 2,
                  box.maxHeight *
                      (.60 - .10 * Curves.easeInOut.transform(ramp(p, 0, .3))),
                );
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Expanded(
                            flex: 64,
                            child: ColoredBox(
                              color: Color.lerp(
                                wall,
                                const Color(0xFF405472),
                                dark * .32,
                              )!,
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Expanded(
                            flex: 36,
                            child: ColoredBox(
                              color: Color.lerp(
                                floor,
                                const Color(0xFF8A879C),
                                dark * .22,
                              )!,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!reduced && p < .9)
                      Positioned(
                        left: center.dx - pictureSize,
                        top: center.dy - pictureSize,
                        width: pictureSize * 2,
                        height: pictureSize * 2,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (.2 + .55 * light) * (1 - ramp(p, .7, .9)),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: .95),
                                    color.withValues(alpha: .38),
                                    color.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!reduced && !done)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _EvolutionParticles(
                                progress: p,
                                center: center,
                                color: color,
                                powerful: widget.event.after.evolution == 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: center.dx - pictureSize / 2,
                      top: center.dy - pictureSize / 2 - bounce,
                      width: pictureSize,
                      height: pictureSize,
                      child: RepaintBoundary(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (reveal < 1)
                              Opacity(
                                opacity: 1 - reveal,
                                child: Transform.scale(
                                  scale:
                                      ((widget.event.before.evolution == 0
                                              ? .42
                                              : .72) +
                                          (widget.event.before.evolution == 0
                                                  ? .58
                                                  : .28) *
                                              ramp(p, 0, .18)) *
                                      (1 - .08 * gathering),
                                  child: _Figure(
                                    character: widget.event.before,
                                    white: light,
                                  ),
                                ),
                              ),
                            if (reveal > 0 || done)
                              Opacity(
                                opacity: reveal,
                                child: Transform.scale(
                                  scale: .78 + .22 * arrival,
                                  child: _Figure(
                                    character: widget.event.after,
                                    white: light * (1 - reveal),
                                    animate: done && !reduced,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  key: const ValueKey('evolution-sound'),
                                  onPressed: toggleSound,
                                  icon: Icon(
                                    sound.enabled && !soundBlocked
                                        ? Icons.volume_up_outlined
                                        : Icons.volume_off_outlined,
                                    color: ink,
                                    semanticLabel:
                                        sound.enabled && !soundBlocked
                                        ? '効果音をOFF'
                                        : '効果音をON',
                                  ),
                                ),
                                const Spacer(),
                                if (!done)
                                  TextButton(
                                    key: const ValueKey('evolution-skip'),
                                    onPressed: skip,
                                    child: const Text('スキップ'),
                                  ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Positioned(
                      top: box.maxHeight * .19,
                      left: 24,
                      right: 24,
                      child: Opacity(
                        opacity: 1 - ramp(p, .48, .62),
                        child: Text(
                          p < .18 ? 'この子に、変化が…' : 'やさしさが、ひかりに。',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      top: box.maxHeight * .71,
                      bottom: 20,
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          child: Opacity(
                            opacity: ramp(p, .72, .92),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  liveRegion: done,
                                  child: Text(
                                    form.name,
                                    key: const ValueKey(
                                      'evolution-species-name',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'に しんかしたよ！',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  form.label,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                if (done)
                                  PrimaryButton(
                                    label: 'これからもよろしく',
                                    onPressed: () {
                                      unawaited(sound.stop());
                                      widget.onClose();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!ready)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: wall,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.character,
    required this.white,
    this.animate = false,
  });
  final Companion character;
  final double white;
  final bool animate;
  @override
  Widget build(BuildContext context) {
    final figure = CharacterView(
      character: character,
      size: double.infinity,
      animate: animate,
      motion: animate ? CharacterMotion.happy : CharacterMotion.idle,
    );
    if (white <= 0) return figure;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.white.withValues(alpha: white),
        BlendMode.srcATop,
      ),
      child: figure,
    );
  }
}

class _EvolutionParticles extends CustomPainter {
  const _EvolutionParticles({
    required this.progress,
    required this.center,
    required this.color,
    required this.powerful,
  });
  final double progress;
  final Offset center;
  final Color color;
  final bool powerful;
  @override
  void paint(Canvas canvas, Size size) {
    final charge = ((progress - .18) / .32).clamp(0.0, 1.0);
    final burst = ((progress - .50) / .25).clamp(0.0, 1.0);
    final count = powerful ? 36 : 24;
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * math.pi / count + progress * .65;
      final variation = .72 + .28 * math.sin(i * 7.13).abs();
      final radius = progress < .5
          ? size.width * .58 * (1 - charge) * variation
          : (20 + burst * size.width * .57) * variation;
      final alpha = progress < .5
          ? math.sin(charge * math.pi) * .85
          : (1 - burst) * .9;
      if (alpha <= 0) continue;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()
        ..color = (i.isEven ? Colors.white : color).withValues(
          alpha: alpha.clamp(0, 1),
        );
      final r = i % 3 == 0 ? 3.5 : 2.0;
      canvas.drawCircle(point, r, paint);
      if (i % 4 == 0) {
        paint
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          point - const Offset(6, 0),
          point + const Offset(6, 0),
          paint,
        );
        canvas.drawLine(
          point - const Offset(0, 6),
          point + const Offset(0, 6),
          paint,
        );
      }
    }
    if (progress >= .5 && burst < 1) {
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - burst) * .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, 24 + burst * size.width * .65, paint);
    }
  }

  @override
  bool shouldRepaint(_EvolutionParticles old) =>
      progress != old.progress ||
      center != old.center ||
      color != old.color ||
      powerful != old.powerful;
}
