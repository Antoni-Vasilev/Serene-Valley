import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../widgets/world_widget.dart';
import '../widgets/hud_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameState gameState;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Movement from the on-screen joystick, each axis in -1..1.
  Offset _joystickInput = Offset.zero;

  static const double tileSize = 16.0;

  @override
  void initState() {
    super.initState();

    gameState = GameState();

    // Game loop: runs once per frame with the real elapsed time.
    _ticker = createTicker(_gameLoop)..start();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _ticker.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    gameState.dispose();
    super.dispose();
  }

  void _gameLoop(Duration elapsed) {
    // Clamp so a long pause (e.g. app in background) doesn't cause a jump.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;

    gameState.moveInput = _joystickInput != Offset.zero ? _joystickInput : _keyboardInput();
    gameState.update(dt);
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
      gameState.togglePause();
    } else if (key == LogicalKeyboardKey.space) {
      gameState.rest();
    } else {
      // Number keys 1-5 for quick tool selection.
      const tools = ['axe', 'pickaxe', 'fishing_rod', 'stick', 'wooden_sword'];
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      final index = digits.indexOf(key);
      if (index == -1) return false;
      gameState.selectTool(tools[index]);
    }
    return true;
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Keep touch controls above the bottom control bar.
    final controlsBottom = bottomInset + 72;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(
        children: [
          // Game world
          Positioned.fill(
            child: WorldWidget(gameState: gameState, tileSize: tileSize),
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
                      right: 24,
                      bottom: controlsBottom + 24,
                      child: _buildActionButton(),
                    ),
                  ],
                  HUDWidget(
                    player: gameState.player,
                    gameState: gameState,
                    onToolSelected: gameState.selectTool,
                    onFoodEaten: gameState.eatFood,
                    onInventoryToggle: gameState.toggleInventory,
                    onCraftingToggle: gameState.toggleCrafting,
                    onMapToggle: gameState.toggleMap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    const icons = {
      'tree': Icons.forest,
      'rock': Icons.landscape,
      'water': Icons.phishing,
      'berry_bush': Icons.spa,
      'animal': Icons.pets,
      'village': Icons.house,
    };
    final target = gameState.interactionTarget;
    final active = target != 'none';

    return SizedBox(
      width: 72,
      height: 72,
      child: FloatingActionButton(
        heroTag: null,
        shape: const CircleBorder(),
        backgroundColor: active ? Colors.amber : Colors.grey.withValues(alpha: 0.6),
        onPressed: gameState.interact,
        child: Icon(icons[target] ?? Icons.touch_app, size: 32),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
