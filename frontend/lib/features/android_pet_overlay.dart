import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/room_wander.dart';
import '../core/theme.dart';
import '../data/character_speech.dart';
import '../data/models.dart';
import '../widgets/character_view.dart';
import '../widgets/speech_bubble.dart';

/// A second Flutter engine shares the app's artwork, poses and speech catalog.
class AndroidPetOverlay extends StatefulWidget {
  const AndroidPetOverlay({super.key});
  @override
  State<AndroidPetOverlay> createState() => _AndroidPetOverlayState();
}

class _AndroidPetOverlayState extends State<AndroidPetOverlay> {
  static const _channel = MethodChannel('jp.yoinoko.app/overlay');
  final _wander = RoomWander(turnDuration: .68);
  final _random = Random();
  Companion? _character;
  Rect _bounds = Rect.zero;
  bool _visible = false, _dragging = false, _tapped = false, _moving = false;
  bool _positionPending = false;
  Offset? _lastSent;
  String? _speech;
  Timer? _clock, _tapTimer, _speechTimer;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'state':
          _accept(Map<String, dynamic>.from(call.arguments as Map));
        case 'visibility':
          setState(() => _visible = call.arguments == true);
          _schedule();
      }
    });
    _load();
  }

  void _schedule() {
    _clock?.cancel();
    _speechTimer?.cancel();
    if (!_visible) return;
    _clock = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    _speechTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      if (!_dragging) _say();
    });
  }

  Future<void> _load() async {
    final state = await _channel.invokeMapMethod<String, dynamic>('ready');
    if (mounted && state != null) _accept(state);
  }

  void _accept(Map<String, dynamic> state) {
    final character = Companion.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(state['character'] as String) as Map,
      ),
    );
    final changed =
        _character?.id != character.id || _character?.kind != character.kind;
    setState(() {
      _character = character;
      _bounds = Rect.fromLTWH(
        0,
        0,
        (state['maxX'] as num).toDouble(),
        (state['maxY'] as num).toDouble(),
      );
      _wander.reset(
        Offset((state['x'] as num).toDouble(), (state['y'] as num).toDouble()),
        _bounds,
      );
      _visible = state['visible'] == true;
      _lastSent = null;
      if (changed) {
        _speech = pickCharacterSpeech(character.kind, random: _random);
      }
    });
    _schedule();
  }

  void _tick() {
    final c = _character;
    if (!_visible || c == null || _dragging || _positionPending) return;
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final oldDirection = _wander.direction;
    final wasPreparing = _wander.preparing;
    _wander.advance(
      .033,
      _bounds,
      _wander.position,
      enabled: !_tapped && c.hp > 20 && c.stage == LifeStage.active && !reduced,
    );
    if (_moving != _wander.moving ||
        oldDirection != _wander.direction ||
        wasPreparing != _wander.preparing ||
        (c.form.imageId == 'stage1_self_care' && _wander.moving)) {
      setState(() => _moving = _wander.moving);
    }
    _move();
  }

  Future<void> _move() async {
    if (_positionPending || _lastSent == _wander.position) return;
    _positionPending = true;
    try {
      _lastSent = _wander.position;
      await _channel.invokeMethod<void>('move', {
        'x': _wander.position.dx,
        'y': _wander.position.dy,
      });
    } finally {
      _positionPending = false;
    }
  }

  void _say() {
    if (_character == null) return;
    _tapTimer?.cancel();
    setState(() {
      _speech = pickCharacterSpeech(
        _character!.kind,
        random: _random,
        previous: _speech,
      );
      _tapped = true;
    });
    _tapTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _tapped = false);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _tapTimer?.cancel();
    _speechTimer?.cancel();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: yoinokoTheme(),
    color: Colors.transparent,
    home: Material(
      color: Colors.transparent,
      child: TickerMode(
        enabled: _visible,
        child: _character == null
            ? const SizedBox.shrink()
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _say,
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: (event) {
                  _wander.reset(_wander.position + event.delta, _bounds);
                  _move();
                },
                onPanEnd: (_) => setState(() => _dragging = false),
                onPanCancel: () => setState(() => _dragging = false),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _control(Icons.open_in_full_rounded, 'よいのこを開く', 'open'),
                        _control(Icons.close_rounded, 'おでかけを終了', 'stop'),
                      ],
                    ),
                    if (_speech != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SpeechBubble(text: _speech!),
                      ),
                    Expanded(
                      child: Center(
                        child: CharacterView(
                          character: _character!,
                          size: 124,
                          wander: false,
                          walking: !_dragging && !_tapped && _moving,
                          facingRight: _wander.facingRight,
                          travelDirection: _wander.direction,
                          movementSpeed: _wander.speed,
                          motion: _character!.stage != LifeStage.active
                              ? CharacterMotion.sleeping
                              : _tapped
                              ? CharacterMotion.tapped
                              : _character!.hp <= 20
                              ? CharacterMotion.lowEnergy
                              : CharacterMotion.idle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );

  Widget _control(IconData icon, String label, String method) => SizedBox(
    width: 36,
    height: 36,
    child: IconButton(
      tooltip: label,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .9),
      ),
      iconSize: 18,
      icon: Icon(icon),
      onPressed: () => _channel.invokeMethod<void>(method),
    ),
  );
}
