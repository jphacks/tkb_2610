import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import '../data/models.dart';

/// Public contract shared with animation/pono/scene.rml's PonoState view model.
int ponoMotionMode(CharacterMotion motion, {required bool walking}) =>
    switch (motion) {
      CharacterMotion.idle => walking ? 1 : 0,
      CharacterMotion.tapped => 2,
      CharacterMotion.happy => 3,
      CharacterMotion.lowEnergy => 4,
      CharacterMotion.sleeping => 5,
    };

/// One decoded vector file for the app; each portrait owns its playback state.
/// Flutter's renderer keeps this compatible with existing opacity/silhouette
/// effects and avoids allocating a separate GPU texture for every portrait.
class _PonoAsset {
  static Future<rive.File>? _pending;
  static Future<rive.File> load() => _pending ??= _decode();

  static Future<rive.File> _decode() async {
    try {
      final file = await rive.File.asset(
        'assets/animations/pono.riv',
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) {
        throw StateError('Pono Rive asset could not be decoded');
      }
      return file;
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }
}

class PonoView extends StatefulWidget {
  const PonoView({
    super.key,
    required this.motion,
    required this.animate,
    this.walking = false,
    this.facingRight = true,
  });

  final CharacterMotion motion;
  final bool animate, walking, facingRight;

  @override
  State<PonoView> createState() => _PonoViewState();
}

class _PonoViewState extends State<PonoView> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _instance;
  rive.ViewModelInstanceNumber? _mode, _look;
  bool? _wasAnimated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await _PonoAsset.load();
      if (!mounted) return;
      _controller = rive.RiveWidgetController(file);
      _instance = _controller!.dataBind(rive.DataBind.auto());
      _mode = _instance!.number('mode');
      _look = _instance!.number('lookX');
      if (_mode == null || _look == null) {
        throw StateError('PonoState requires mode and lookX');
      }
      _sync();
      setState(() {});
    } catch (error) {
      // Keep the character visible if a runtime/asset fails to load.
      debugPrint('Pono animation unavailable: $error');
      _disposePlayback();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PonoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final controller = _controller;
    if (controller == null) return;
    final animated =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.motion != CharacterMotion.sleeping;
    final mode = ponoMotionMode(
      widget.motion,
      walking: animated && widget.walking,
    ).toDouble();
    final changed = _mode!.value != mode;
    _mode!.value = mode;
    _look!.value =
        animated && widget.walking && widget.motion == CharacterMotion.idle
        ? (widget.facingRight ? 3 : -3)
        : 0;
    // Apply state transitions before pausing, so sleeping never freezes with
    // open eyes and reduced-motion portraits retain the correct expression.
    if (!animated && (changed || _wasAnimated != false)) {
      // Step through entry + blend rather than one large delta: state entry
      // itself can consume a frame. Never advance again on ordinary rebuilds.
      for (var frame = 0; frame < 18; frame++) {
        controller.stateMachine.advanceAndApply(1 / 60);
      }
    }
    controller.active = animated && TickerMode.valuesOf(context).enabled;
    _wasAnimated = animated;
  }

  void _disposePlayback() {
    _mode?.dispose();
    _look?.dispose();
    _mode = null;
    _look = null;
    _controller?.dispose();
    _controller = null;
    _instance?.dispose();
    _instance = null;
  }

  @override
  void dispose() {
    _disposePlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: _controller == null
        ? Image.asset(
            'assets/characters/evolution/base_01.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        : rive.RiveWidget(controller: _controller!, fit: rive.Fit.contain),
  );
}
