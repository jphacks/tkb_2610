import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/models.dart';

/// Drop-in seam for a future Rive renderer; screens never depend on Rive internals.
typedef CharacterRenderer =
    Widget Function(
      BuildContext context,
      Companion character,
      CharacterMotion motion,
    );

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
    label: '第${widget.character.generation}世代のよいのこ',
    button: widget.onTap != null,
    child: GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child:
            widget.renderer?.call(context, widget.character, widget.motion) ??
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
                'assets/characters/${widget.character.kind}.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, error, stackTrace) => Image.asset(
                  'assets/characters/initial.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
      ),
    ),
  );
}
