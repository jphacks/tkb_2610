import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../core/character_animation.dart';
import 'character_rive_view.dart';
import 'mikeluna_sprite_view.dart';

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
    this.wanderDistance = 0,
    this.wander = true,
    this.walking,
    this.facingRight,
    this.travelDirection,
    this.movementSpeed,
  });
  final Companion character;
  final double size;
  final CharacterMotion motion;
  final CharacterRenderer? renderer;
  final VoidCallback? onTap;
  final bool animate;
  final double wanderDistance;
  final bool wander;
  final bool? walking, facingRight;
  final Offset? travelDirection;
  final double? movementSpeed;
  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..addListener(_tick);
  double _seconds = 0, _travelSeconds = 0, _lastValue = 0;
  Timer? _tapTimer;
  bool _reacting = false;

  bool get _hasRig => widget.character.form.stage <= 1;
  CharacterMotion get _rigMotion =>
      _reacting &&
          widget.motion != CharacterMotion.happy &&
          widget.motion != CharacterMotion.sleeping
      ? CharacterMotion.tapped
      : widget.motion;

  void _tap() {
    if (_hasRig &&
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.motion != CharacterMotion.sleeping) {
      _tapTimer?.cancel();
      setState(() => _reacting = true);
      _tapTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _reacting = false);
      });
    }
    widget.onTap?.call();
  }

  void _tick() {
    final delta = ((_animation.value - _lastValue + 1) % 1) * 60;
    _lastValue = _animation.value;
    // A resumed tab must not leap across the room.
    final step = delta.clamp(0.0, .1);
    _seconds += step;
    if (widget.wander && widget.motion == CharacterMotion.idle) {
      _travelSeconds += step;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.form.imageId != widget.character.form.imageId) {
      _tapTimer?.cancel();
      _reacting = false;
    }
    _sync();
  }

  void _sync() {
    if (widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.motion != CharacterMotion.sleeping &&
        (!_hasRig || widget.wanderDistance > 0)) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
      _seconds = 0;
      _travelSeconds = 0;
      _lastValue = _animation.value;
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '第${widget.character.generation}世代のよいのこ、${widget.character.form.name}、${widget.character.form.label}',
    button:
        widget.onTap != null ||
        (_hasRig &&
            widget.animate &&
            widget.motion != CharacterMotion.sleeping),
    child: GestureDetector(
      onTap:
          widget.onTap != null ||
              (_hasRig &&
                  widget.animate &&
                  widget.motion != CharacterMotion.sleeping)
          ? _tap
          : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size + widget.wanderDistance * 2,
        height: widget.size,
        child: Center(
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
                    final enabled =
                        widget.animate &&
                        !MediaQuery.disableAnimationsOf(context);
                    final pose = enabled
                        ? characterPose(
                            form: widget.character.form,
                            seconds: _seconds,
                            travelSeconds: _travelSeconds,
                            motion: widget.motion,
                            travel: widget.wanderDistance,
                            walking: widget.walking,
                            facingRight: widget.facingRight,
                          )
                        : const CharacterPose();
                    // Evolution scenes can give this view unbounded dimensions.
                    final size = widget.size.isFinite ? widget.size : 160.0;
                    if (_hasRig) {
                      // Rive owns the local pose; the room still owns travel.
                      return Transform.translate(
                        offset: Offset(pose.x, 0),
                        child: child,
                      );
                    }
                    return Transform.translate(
                      offset: Offset(pose.x, pose.y * size),
                      child: Transform.rotate(
                        angle: pose.rotation,
                        alignment: Alignment.bottomCenter,
                        child: Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.diagonal3Values(
                            pose.scaleX * (pose.faceLeft ? -1 : 1),
                            pose.scaleY,
                            1,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: widget.character.form.stage == 0
                      ? PonoView(
                          motion: _rigMotion,
                          animate: widget.animate,
                          walking: widget.walking ?? false,
                          facingRight: widget.facingRight ?? true,
                        )
                      : widget.character.form.imageId == 'stage1_self_care'
                      ? MikelunaSpriteView(
                          motion: _rigMotion,
                          animate: widget.animate,
                          walking: widget.walking ?? false,
                          direction:
                              widget.travelDirection ??
                              (widget.facingRight == null
                                  ? null
                                  : Offset(widget.facingRight! ? 1 : -1, 0)),
                          pace: widget.movementSpeed == null
                              ? 1
                              : widget.movementSpeed! /
                                    (widget.size * .18 / 1.28),
                        )
                      : _hasRig
                      ? CharacterRiveView(
                          kind: widget.character.form.imageId,
                          motion: _rigMotion,
                          animate: widget.animate,
                          walking: widget.walking ?? false,
                          facingRight: widget.facingRight ?? true,
                        )
                      : Image.asset(
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
      ),
    ),
  );
}
