import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mikeluna_animation.dart';
import '../data/mikeluna_sprites.dart';
import '../data/models.dart';

class _MikelunaAtlas {
  static ui.Image? _loaded;
  static Future<ui.Image>? _pending;
  static Future<ui.Image> load() {
    final loaded = _loaded;
    if (loaded != null) return Future.value(loaded);
    return _pending ??= _decode();
  }
  static Future<ui.Image> _decode() async {
    try {
      final data = await rootBundle.load(mikelunaAtlasAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      try {
        final image = (await codec.getNextFrame()).image;
        _loaded = image;
        _pending = null;
        return image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }
}

class MikelunaSpriteView extends StatefulWidget {
  const MikelunaSpriteView({
    super.key,
    required this.motion,
    required this.animate,
    required this.walking,
    this.direction,
    this.pace = 1,
  });
  final CharacterMotion motion;
  final bool animate, walking;
  final Offset? direction;
  final double pace;

  @override
  State<MikelunaSpriteView> createState() => _MikelunaSpriteViewState();
}

class _MikelunaSpriteViewState extends State<MikelunaSpriteView>
    with SingleTickerProviderStateMixin {
  final _playback = MikelunaPlayback();
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..addListener(_tick);
  ui.Image? _atlas;
  double _last = 0;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _MikelunaAtlas.load().then(
      (atlas) {
        if (mounted) setState(() => _atlas = atlas);
      },
      onError: (Object error) {
        debugPrint('Mikeluna atlas unavailable: $error');
      },
    );
  }

  void _tick() {
    final delta = ((_clock.value - _last + 1) % 1) * 60;
    _last = _clock.value;
    _playback.advance(delta.clamp(0.0, .1));
  }

  void _sync({bool changedMotion = false}) {
    _playback.request(
      walking: widget.walking,
      heading: MikelunaHeading.fromDirection(widget.direction ?? Offset.zero),
      motion: widget.motion,
      pace: widget.pace,
    );
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        widget.motion != CharacterMotion.sleeping;
    if (!enabled && changedMotion) _playback.snapToRequestedPose();
    _enabled = enabled;
    if (enabled) {
      if (!_clock.isAnimating) {
        _last = _clock.value;
        _clock.repeat();
      }
    } else {
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MikelunaSpriteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(changedMotion: oldWidget.motion != widget.motion);
  }

  @override
  void dispose() {
    _clock.dispose();
    // The immutable atlas is shared by every portrait for the app's lifetime.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => _atlas == null
            ? Image.asset(
                characterForm('stage1_self_care').assetPath,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              )
            : CustomPaint(
                key: const ValueKey('mikeluna-cel'),
                painter: MikelunaCelPainter(
                  _atlas!,
                  _playback.cel,
                  animate: _enabled,
                ),
                size: Size.infinite,
              ),
      ),
    ),
  );
}

class MikelunaCelPainter extends CustomPainter {
  MikelunaCelPainter(this.atlas, this.cel, {required this.animate});
  final ui.Image atlas;
  final MikelunaCel cel;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final index = mikelunaCelIds.indexOf(cel.id);
    if (index < 0) return;
    const stride = mikelunaCellSize + mikelunaAtlasGutter * 2;
    final src = Rect.fromLTWH(
      (index % mikelunaAtlasColumns) * stride + mikelunaAtlasGutter.toDouble(),
      (index ~/ mikelunaAtlasColumns) * stride + mikelunaAtlasGutter.toDouble(),
      mikelunaCellSize.toDouble(),
      mikelunaCellSize.toDouble(),
    );
    canvas.save();
    if (cel.mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (animate) {
      final pivot = Offset(size.width / 2, size.height * .906);
      canvas.translate(pivot.dx, pivot.dy + cel.y * size.height);
      canvas.rotate(cel.rotation);
      canvas.scale(cel.scaleX, cel.scaleY);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    canvas.drawImageRect(
      atlas,
      src,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(MikelunaCelPainter oldDelegate) =>
      oldDelegate.atlas != atlas ||
      oldDelegate.cel.id != cel.id ||
      oldDelegate.cel.mirrored != cel.mirrored ||
      oldDelegate.cel.y != cel.y ||
      oldDelegate.cel.scaleX != cel.scaleX ||
      oldDelegate.cel.scaleY != cel.scaleY ||
      oldDelegate.cel.rotation != cel.rotation ||
      oldDelegate.animate != animate;
}
