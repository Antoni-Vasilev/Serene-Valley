import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../audio/sound.dart';
import '../graphics/ui_textures.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/save_service.dart';
import '../widgets/hud_widget.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/world_widget.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  final SaveService saveService;

  const GameScreen({super.key, required this.gameState, required this.saveService});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Movement from the on-screen joystick, each axis in -1..1.
  Offset _joystickInput = Offset.zero;
  // Set once the player chose to go back to the title screen.
  bool _leaving = false;
  // Briefly true after saving from the pause menu.
  bool _justSaved = false;

  // Footsteps and the sounds of the surroundings.
  Offset _lastPosition = Offset.zero;
  double _stepTimer = 0;
  double _sceneTimer = 0;

  static const double tileSize = 16.0;

  GameState get gameState => widget.gameState;

  @override
  void initState() {
    super.initState();

    // Game loop: runs once per frame with the real elapsed time.
    _ticker = createTicker(_gameLoop)..start();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _ticker.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    // Back to the title screen's music.
    Sound.instance.setScene(ambience: false);
    gameState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save whenever the app leaves the foreground; it may never come back.
    if (state != AppLifecycleState.resumed) _save();
  }

  Future<void> _save() => widget.saveService.save(gameState);

  void _gameLoop(Duration elapsed) {
    // Clamp so a long pause (e.g. app in background) doesn't cause a jump.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;

    gameState.moveInput = _joystickInput != Offset.zero ? _joystickInput : _keyboardInput();
    gameState.update(dt);
    if (gameState.takeSaveRequest()) _save();
    // Each sound at most once a frame, even if it happened twice.
    for (final name in gameState.takeSounds().toSet()) {
      Sound.instance.play(name);
    }
    _updateSound(dt);
  }

  void _updateSound(double dt) {
    final player = gameState.player;
    final world = gameState.world;
    final moved = (player.position - _lastPosition).distance > 0.001;
    _lastPosition = player.position;
    if (moved && !gameState.isMenuOpen) {
      _stepTimer -= dt;
      if (_stepTimer <= 0) {
        _stepTimer = player.speed < Player.baseSpeed ? 0.42 : 0.3;
        final ground = world.getTileAt(player.position.dx.floor(), player.position.dy.floor());
        Sound.instance.play(ground == 'wood_floor' || ground == 'bridge' ? 'step_wood' : 'step', volume: 0.6);
      }
    } else {
      _stepTimer = 0.08;
    }

    // The surroundings change slowly, so a few updates a second will do.
    _sceneTimer -= dt;
    if (_sceneTimer > 0) return;
    _sceneTimer = 0.25;
    final x = player.position.dx.floor();
    final y = player.position.dy.floor();
    var water = double.infinity;
    for (var dy = -5; dy <= 5; dy++) {
      for (var dx = -5; dx <= 5; dx++) {
        if (world.getTileAt(x + dx, y + dy) == 'water') water = min(water, sqrt(dx * dx + dy * dy));
      }
    }
    var fire = double.infinity;
    for (final f in world.fires) {
      fire = min(fire, (f + const Offset(0.5, 0.5) - player.position).distance);
    }
    Sound.instance.setScene(
      darkness: (1 - world.getLightLevel()) / 0.85,
      water: Sound.nearness(water, 6),
      fire: Sound.nearness(fire, 6),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.keyE) {
      gameState.interact();
    } else if (key == LogicalKeyboardKey.keyI) {
      gameState.toggleInventory();
    } else if (key == LogicalKeyboardKey.keyC) {
      gameState.toggleCrafting();
    } else if (key == LogicalKeyboardKey.keyM) {
      gameState.toggleMap();
    } else if (key == LogicalKeyboardKey.escape) {
      _back();
    } else if (key == LogicalKeyboardKey.space) {
      gameState.requestSleep();
    } else {
      return false;
    }
    return true;
  }

  /// Escape and the system back button close the open panel, or pause.
  void _back() {
    if (!gameState.closeOverlay()) gameState.togglePause();
  }

  Offset _keyboardInput() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    bool any(List<LogicalKeyboardKey> keys) => keys.any(pressed.contains);

    double dx = 0, dy = 0;
    if (any([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW])) dy -= 1;
    if (any([LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS])) dy += 1;
    if (any([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA])) dx -= 1;
    if (any([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD])) dx += 1;
    return Offset(dx, dy);
  }

  Future<void> _saveFromMenu() async {
    await _save();
    if (!mounted) return;
    setState(() => _justSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _goToMainMenu() async {
    if (_leaving) return;
    _leaving = true;
    await _save();
    if (mounted) Navigator.of(context).pop();
  }

  void _interact() {
    HapticFeedback.selectionClick();
    gameState.interact();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    // Keep touch controls above the bottom control bar.
    final controlsBottom = padding.bottom + 88;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: Stack(
          children: [
            // Game world
            Positioned.fill(
              child: WorldWidget(
                gameState: gameState,
                tileSize: tileSize,
                hudInsets: EdgeInsets.only(top: padding.top + 150, bottom: controlsBottom),
              ),
            ),

            // HUD and touch controls rebuild whenever the game state changes.
            Positioned.fill(
              child: ListenableBuilder(
                listenable: gameState,
                builder: (context, _) => Stack(
                  children: [
                    if (!gameState.isMenuOpen) ...[
                      Positioned(
                        left: 24,
                        bottom: controlsBottom,
                        child: Joystick(
                          onChanged: (input) => _joystickInput = input,
                        ),
                      ),
                      Positioned(
                        right: 20,
                        bottom: controlsBottom + 16,
                        child: _ActionButton(target: gameState.target, onPressed: _interact),
                      ),
                    ],
                    HUDWidget(
                      gameState: gameState,
                      onSave: _saveFromMenu,
                      onMainMenu: _goToMainMenu,
                      justSaved: _justSaved,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Virtual thumbstick. Reports the stick position as an offset whose
/// components are in -1..1, or [Offset.zero] when released.
class Joystick extends StatefulWidget {
  final ValueChanged<Offset> onChanged;
  final double size;

  const Joystick({super.key, required this.onChanged, this.size = 130});

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;

  double get _radius => widget.size / 2 - 20;

  void _update(Offset localPosition) {
    final centre = Offset(widget.size / 2, widget.size / 2);
    var delta = localPosition - centre;
    if (delta.distance > _radius) {
      delta = Offset.fromDirection(delta.direction, _radius);
    }
    setState(() => _knob = delta);

    final input = delta / _radius;
    // Small dead zone so a resting thumb doesn't drift.
    widget.onChanged(input.distance < 0.15 ? Offset.zero : input);
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  void dispose() {
    widget.onChanged(Offset.zero);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RawImage(
              image: UiTextures.instance.joystickBase,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              opacity: const AlwaysStoppedAnimation(0.85),
            ),
            Transform.translate(
              offset: _knob,
              child: RawImage(
                image: UiTextures.instance.joystickKnob,
                width: 52,
                height: 52,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round button that does whatever is nearby, with a sign saying what.
class _ActionButton extends StatefulWidget {
  final Interaction? target;
  final VoidCallback onPressed;

  const _ActionButton({required this.target, required this.onPressed});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final textures = UiTextures.instance;
    final active = target != null;
    final image = active
        ? (_down ? textures.roundActivePressed : textures.roundActive)
        : (_down ? textures.roundIdlePressed : textures.roundIdle);
    final px = uiPixel(context);
    final size = 26 * px;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: PixelPanel(
            frame: PixelFrame.plate,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            child: Text(target?.label ?? '', style: pixelText(15, bold: true)),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: target?.label ?? 'Interact',
          child: GestureDetector(
            key: const ValueKey('action-button'),
            onTapDown: (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            onTap: widget.onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RawImage(image: image, width: size, height: size, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                  Padding(
                    // The face sinks when pressed.
                    padding: EdgeInsets.only(top: (_down ? 3 : 0) * px, bottom: (_down ? 0 : 2) * px),
                    child: PixelIcon(
                      UiTextures.actionIcon(target?.type),
                      size: 12 * px * 1.25,
                      opacity: active ? 1 : 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
