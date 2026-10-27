import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import '../data/models.dart';

/// The same mode contract is used by the starter and first-evolution rigs.
int ponoMotionMode(CharacterMotion motion, {required bool walking}) =>
    switch (motion) {
      CharacterMotion.idle => walking ? 1 : 0,
      CharacterMotion.tapped => 2,
      CharacterMotion.happy => 3,
      CharacterMotion.lowEnergy => 4,
      CharacterMotion.sleeping => 5,
    };

/// Each asset is decoded once; every visible companion owns its playback state.
class _CharacterRiveAssets {
  static final Map<String, rive.File> _loaded = {};
  static final Map<String, Future<rive.File>> _pending = {};
  static Future<rive.File> load(String asset) {
    final file = _loaded[asset];
    if (file != null) return Future.value(file);
    return _pending.putIfAbsent(asset, () => _decode(asset));
  }

  static Future<rive.File> _decode(String asset) async {
    try {
      // The web renderer factory is available only after WASM initializes.
      if (!await rive.RiveNative.init()) {
        throw StateError('Rive runtime could not be initialized');
      }
      final file = await rive.File.asset(
        asset,
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) {
        throw StateError('Character Rive asset could not be decoded');
      }
      _loaded[asset] = file;
      _pending.remove(asset);
      return file;
    } catch (_) {
      _pending.remove(asset);
      rethrow;
    }
  }
}

class CharacterRiveSpec {
  const CharacterRiveSpec(this.asset, this.artboard, {this.facesLeft = false});
  final String asset, artboard;
  final bool facesLeft;
}

CharacterRiveSpec? characterRiveSpec(String kind) {
  final form = characterForm(kind);
  if (form.stage == 0) {
    return const CharacterRiveSpec('assets/animations/pono.riv', 'Pono');
  }
  if (form.stage == 1) {
    return CharacterRiveSpec(
      'assets/animations/first_evolutions.riv',
      form.imageId,
      facesLeft: const [1, 4, 5].contains(form.firstCategory),
    );
  }
  return null;
}

class CharacterRiveView extends StatefulWidget {
  const CharacterRiveView({
    required this.kind,
    super.key,
    required this.motion,
    required this.animate,
    this.walking = false,
    this.facingRight = true,
  });

  final String kind;
  final CharacterMotion motion;
  final bool animate, walking, facingRight;

  @override
  State<CharacterRiveView> createState() => _CharacterRiveViewState();
}

class _CharacterRiveViewState extends State<CharacterRiveView> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstance? _instance;
  rive.ViewModelInstanceNumber? _mode, _look;
  bool? _wasAnimated;
  bool _mirrored = false;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    try {
      final spec = characterRiveSpec(widget.kind);
      if (spec == null) throw StateError('No Rive model for ${widget.kind}');
      final file = await _CharacterRiveAssets.load(spec.asset);
      if (!mounted || serial != _loadSerial) return;
      _controller = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardSelector.byName(spec.artboard),
      );
      _instance = _controller!.dataBind(rive.DataBind.auto());
      _mode = _instance!.number('mode');
      _look = _instance!.number('lookX');
      if (_mode == null || _look == null) {
        throw StateError('Character view model requires mode and lookX');
      }
      _sync();
      setState(() {});
    } catch (error) {
      if (!mounted || serial != _loadSerial) return;
      // Keep the character visible if a runtime/asset fails to load.
      debugPrint('Character animation unavailable (${widget.kind}): $error');
      _disposePlayback();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CharacterRiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _loadSerial++;
      _disposePlayback();
      _wasAnimated = null;
      _load();
    } else {
      _sync();
    }
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
      walking: widget.walking,
    ).toDouble();
    final changed = _mode!.value != mode;
    if (changed) _mode!.value = mode;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _mirrored = false;
    } else if (animated) {
      _mirrored =
          (characterRiveSpec(widget.kind)?.facesLeft ?? false) &&
          widget.facingRight;
    }
    final look =
        animated && widget.walking && widget.motion == CharacterMotion.idle
        ? (widget.facingRight ? 3.0 : -3.0) * (_mirrored ? -1 : 1)
        : 0.0;
    if ((animated || changed || _wasAnimated == null) && _look!.value != look) {
      _look!.value = look;
    }
    // Apply state transitions before pausing, so sleeping never freezes with
    // open eyes and reduced-motion portraits retain the correct expression.
    if (!animated && (changed || _wasAnimated == null)) {
      // Step through entry + blend rather than one large delta: state entry
      // itself can consume a frame. Never advance again on ordinary rebuilds.
      for (var frame = 0; frame < 18; frame++) {
        controller.stateMachine.advanceAndApply(1 / 60);
      }
    }
    final active = animated && TickerMode.valuesOf(context).enabled;
    if (controller.active != active) controller.active = active;
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
    _loadSerial++;
    _disposePlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portrait = _controller == null
        ? Image.asset(
            characterForm(widget.kind).assetPath,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        : rive.RiveWidget(controller: _controller!, fit: rive.Fit.contain);
    final animated =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.motion != CharacterMotion.sleeping;
    final facesLeft = characterRiveSpec(widget.kind)?.facesLeft ?? false;
    // A short squash makes direction changes less abrupt. Reduced-motion and
    // static gallery portraits retain the original untransformed view.
    return IgnorePointer(
      child: !facesLeft
          ? portrait
          : TweenAnimationBuilder<double>(
              tween: Tween(end: _mirrored ? -1.0 : 1.0),
              duration: animated
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              curve: Curves.easeInOutCubic,
              builder: (context, scale, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(scale, 1, 1),
                child: child,
              ),
              child: portrait,
            ),
    );
  }
}

/// Retains the existing starter API while sharing the lifecycle with all rigs.
class PonoView extends CharacterRiveView {
  const PonoView({
    super.key,
    required super.motion,
    required super.animate,
    super.walking = false,
    super.facingRight = true,
  }) : super(kind: 'base_01');
}
