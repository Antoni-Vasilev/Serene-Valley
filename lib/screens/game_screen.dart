import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';
import '../widgets/world_widget.dart';
import '../widgets/hud_widget.dart';

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

  static const double tileSize = 16.0;

  static const Map<String, IconData> _actionIcons = {
    'talk': Icons.chat_bubble,
    'chop': Icons.forest,
    'mine': Icons.construction,
    'pick': Icons.spa,
    'pick_apple': Icons.apple,
    'search': Icons.grass,
    'fish': Icons.phishing,
    'cook': Icons.outdoor_grill,
    'sleep': Icons.bed,
    'plant': Icons.eco,
    'water': Icons.water_drop,
    'growing': Icons.hourglass_bottom,
    'harvest': Icons.agriculture,
    'bridge_site': Icons.info_outline,
    'cave': Icons.visibility,
    'watch': Icons.pets,
  };

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game saved'), duration: Duration(seconds: 2)),
    );
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
    final controlsBottom = padding.bottom + 72;

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
                hudInsets: EdgeInsets.only(top: padding.top + 100, bottom: controlsBottom),
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
                        right: 24,
                        bottom: controlsBottom + 24,
                        child: _buildActionButton(),
                      ),
                    ],
                    HUDWidget(
                      gameState: gameState,
                      onSave: _saveFromMenu,
                      onMainMenu: _goToMainMenu,
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

  Widget _buildActionButton() {
    final target = gameState.target;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Says what the button will do, e.g. "Chop" or "Talk".
        AnimatedOpacity(
          opacity: target == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              target?.label ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            heroTag: null,
            shape: const CircleBorder(),
            backgroundColor: target != null ? Colors.amber : Colors.grey.withValues(alpha: 0.6),
            onPressed: _interact,
            child: Icon(_actionIcons[target?.type] ?? Icons.touch_app, size: 32),
          ),
        ),
      ],
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
