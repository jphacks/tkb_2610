import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/models.dart';

/// Drop-in seam for a future Rive renderer; screens never depend on Rive internals.
typedef CharacterRenderer =
    Widget Function(
      BuildContext context,
      Companion character,
      CharacterMotion motion,
      bool animate,
    );

/// Install once around the app when the final Rive assets become available.
class CharacterRendererScope extends InheritedWidget {
  const CharacterRendererScope({
    super.key,
    required this.renderer,
    required super.child,
  });
  final CharacterRenderer renderer;
  static CharacterRenderer? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CharacterRendererScope>()
      ?.renderer;
  @override
  bool updateShouldNotify(CharacterRendererScope oldWidget) =>
      renderer != oldWidget.renderer;
}

class CharacterView extends StatefulWidget {
  const CharacterView({
    super.key,
    required this.character,
    this.size = 120,
    this.motion = CharacterMotion.idle,
    this.renderer,
    this.onTap,
    this.animate = true,
  });
  final Companion character;
  final double size;
  final CharacterMotion motion;
  final CharacterRenderer? renderer;
  final VoidCallback? onTap;
  final bool animate;
  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.motion != CharacterMotion.sleeping) {
      _animation.repeat();
    } else {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '第${widget.character.generation}世代のよいのこ、${widget.character.form.label}',
    button: widget.onTap != null,
    child: GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child:
            (widget.renderer ?? CharacterRendererScope.of(context))?.call(
              context,
              widget.character,
              widget.motion,
              widget.animate && !MediaQuery.disableAnimationsOf(context),
            ) ??
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final amount =
                    widget.motion == CharacterMotion.happy ||
                        widget.motion == CharacterMotion.tapped
                    ? 6.0
                    : 2.0;
                return Transform.translate(
                  offset: Offset(
                    0,
                    -math.sin(_animation.value * math.pi * 2) * amount,
                  ),
                  child: child,
                );
              },
              child: Image.asset(
                widget.character.form.assetPath,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, error, stackTrace) => Image.asset(
                  characterForm('base_01').assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
      ),
    ),
  );
}
