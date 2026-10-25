import 'dart:math';
import 'package:flutter/material.dart';
import '../core/room_wander.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'character_view.dart';
import 'common.dart';

/// Moves the portrait, speech and name together in one bounded layout group.
class RoomCharacter extends StatefulWidget {
  const RoomCharacter({
    super.key,
    required this.character,
    required this.size,
    required this.top,
    required this.speech,
    required this.motion,
    required this.onTap,
    this.roam = true,
    this.showLabels = true,
    this.random,
  });
  final Companion character;
  final double size, top;
  final String? speech;
  final CharacterMotion motion;
  final VoidCallback onTap;
  final bool roam, showLabels;
  final Random? random;
  @override
  State<RoomCharacter> createState() => _RoomCharacterState();
}

class _RoomCharacterState extends State<RoomCharacter>
    with SingleTickerProviderStateMixin {
  late final _wander = RoomWander(random: widget.random);
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..addListener(_tick);
  Rect _bounds = Rect.zero;
  Offset _origin = Offset.zero;
  double _last = 0;
  bool _reduced = false;
  bool _resetLayout = false;

  @override
  void didUpdateWidget(RoomCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetLayout =
        oldWidget.showLabels != widget.showLabels ||
        oldWidget.character.form.imageId != widget.character.form.imageId ||
        oldWidget.size != widget.size;
  }

  void _tick() {
    final seconds = (((_clock.value - _last + 1) % 1) * 60).clamp(0.0, .1);
    _last = _clock.value;
    _wander.advance(
      seconds,
      _bounds,
      _origin,
      enabled: widget.roam && widget.motion == CharacterMotion.idle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _clock.stop();
      _wander.reset(_origin, _bounds);
    } else if (!_clock.isAnimating) {
      _last = _clock.value;
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = min(box.maxWidth - 32, max(widget.size * 1.08, 260.0));
      final height = widget.size + 116;
      final topLimit = widget.showLabels
          ? max(152.0, MediaQuery.textScalerOf(context).scale(14) * 7 + 45)
          : 0.0;
      final bottom = max(0.0, box.maxHeight - height - 12);
      _bounds = Rect.fromLTRB(
        16,
        min(topLimit, bottom),
        max(16, box.maxWidth - width - 16),
        bottom,
      );
      _origin = RoomWander.constrain(
        Offset((box.maxWidth - width) / 2, widget.top - 72),
        _bounds,
      );
      if (_resetLayout) {
        _wander.reset(_origin, _bounds);
        _resetLayout = false;
      }
      _wander.advance(0, _bounds, _origin, enabled: false);
      return AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final position = _reduced ? _origin : _wander.position;
          return Stack(
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                width: width,
                height: height,
                child: Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: widget.showLabels && widget.speech != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Panel(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    widget.speech!,
                                    key: const ValueKey('character-speech'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    CharacterView(
                      character: widget.character,
                      size: widget.size,
                      walking:
                          !_reduced &&
                          widget.roam &&
                          _wander.moving &&
                          widget.motion == CharacterMotion.idle,
                      facingRight: !_reduced && _wander.facingRight,
                      motion: widget.motion,
                      onTap: widget.onTap,
                    ),
                    const SizedBox(height: 8),
                    if (widget.showLabels)
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.character.form.name,
                            key: const ValueKey('character-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
