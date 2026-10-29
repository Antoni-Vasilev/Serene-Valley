import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player.dart';
import '../models/world.dart';
import '../models/game_state.dart';
import '../widgets/world_widget.dart';
import '../widgets/player_widget.dart';
import '../widgets/hud_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameState gameState;
  late AnimationController _animationController;
  
  // Input state
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  Offset _lastTouchPosition = Offset.zero;
  bool _isTouching = false;
  
  // Joystick
  Offset _joystickPosition = Offset.zero;
  bool _showJoystick = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize game state
    gameState = GameState();
    
    // Animation controller for game loop
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    );
    
    _animationController.addListener(_gameLoop);
    _animationController.forward();
    
    // Listen to keyboard
    RawKeyboard.instance.addListener(_handleKeyEvent);
    
    // Listen to game state changes
    gameState.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    gameState.dispose();
    super.dispose();
  }

  void _gameLoop() {
    if (!_animationController.isAnimating) return;
    
    // Calculate delta time
    double deltaTime = _animationController.lastElapsedDuration!.inMilliseconds.toDouble();
    
    // Update game state
    gameState.update(deltaTime);
    
    // Handle keyboard input
    _handleKeyboardInput();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
    } else if (event is RawKeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    
    // Handle special keys
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        gameState.interact();
      } else if (event.logicalKey == LogicalKeyboardKey.keyI) {
        gameState.toggleInventory();
      } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
        gameState.toggleCrafting();
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        gameState.toggleMap();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        gameState.togglePause();
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        gameState.rest();
      }
      
      // Number keys for quick tool selection
      if (event.logicalKey.keyId >= 49 && event.logicalKey.keyId <= 57) {
        // Keys 1-9
        int index = event.logicalKey.keyId - 49;
        List<String> tools = ['axe', 'pickaxe', 'fishing_rod', 'stick', 'wooden_sword'];
        if (index < tools.length) {
          gameState.selectTool(tools[index]);
        }
      }
    }
  }

  void _handleKeyboardInput() {
    Offset movement = Offset.zero;
    
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      movement += const Offset(0, -1);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      movement += const Offset(0, 1);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      movement += const Offset(-1, 0);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      movement += const Offset(1, 0);
    }
    
    // Normalize diagonal movement
    if (movement != Offset.zero) {
      movement = Offset(movement.dx / movement.distance, movement.dy / movement.distance);
    }
    
    // Apply movement
    if (movement != Offset.zero) {
      gameState.movePlayer(movement);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate tile size based on screen
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double tileSize = 16.0;
    
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKey: (node, event) {
          if (event is RawKeyDownEvent) {
            _pressedKeys.add(event.logicalKey);
          } else if (event is RawKeyUpEvent) {
            _pressedKeys.remove(event.logicalKey);
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Stack(
            children: [
              // Game world
              Transform.translate(
                offset: -gameState.cameraOffset,
                child: Transform.scale(
                  scale: gameState.cameraZoom,
                  child: SizedBox(
                    width: gameState.world.width * tileSize,
                    height: gameState.world.height * tileSize,
                    child: Stack(
                      children: [
                        WorldWidget(
                          world: gameState.world,
                          gameState: gameState,
                          tileSize: tileSize,
                        ),
                        PlayerWidget(
                          player: gameState.player,
                          tileSize: tileSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // HUD
              HUDWidget(
                player: gameState.player,
                gameState: gameState,
                onToolSelected: gameState.selectTool,
                onFoodEaten: gameState.eatFood,
                onInventoryToggle: gameState.toggleInventory,
                onCraftingToggle: gameState.toggleCrafting,
                onMapToggle: gameState.toggleMap,
              ),
              
              // Touch controls (for mobile)
              if (_showJoystick)
                Positioned(
                  left: 20,
                  bottom: 100,
                  child: _buildJoystick(),
                ),
              
              // Interaction button (for mobile)
              if (_showJoystick)
                Positioned(
                  right: 20,
                  bottom: 100,
                  child: FloatingActionButton(
                    onPressed: gameState.interact,
                    child: const Icon(Icons.touch_app),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    _lastTouchPosition = details.globalPosition;
    _isTouching = true;
    
    // Check if touch is in the left half of the screen
    if (details.globalPosition.dx < MediaQuery.of(context).size.width / 2) {
      _showJoystick = true;
    }
    
    setState(() {});
  }

  void _handleTapUp(TapUpDetails details) {
    _isTouching = false;
    _joystickPosition = Offset.zero;
    
    // Hide joystick after a delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _showJoystick = false;
      if (mounted) setState(() {});
    });
  }

  void _handlePanStart(DragStartDetails details) {
    _lastTouchPosition = details.globalPosition;
    _isTouching = true;
    
    if (details.globalPosition.dx < MediaQuery.of(context).size.width / 2) {
      _showJoystick = true;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isTouching) return;
    
    Offset currentPosition = details.globalPosition;
    Offset delta = currentPosition - _lastTouchPosition;
    _lastTouchPosition = currentPosition;
    
    // Update joystick
    if (_showJoystick) {
      _joystickPosition += delta;
      
      // Clamp joystick position
      double maxDistance = 50;
      double distance = _joystickPosition.distance;
      if (distance > maxDistance) {
        _joystickPosition = Offset.fromDirection(
          _joystickPosition.direction,
          maxDistance,
        );
      }
      
      // Move player based on joystick
      if (distance > 10) {
        Offset direction = Offset(
          _joystickPosition.dx / distance,
          _joystickPosition.dy / distance,
        );
        gameState.movePlayer(direction);
      }
    }
    
    setState(() {});
  }

  void _handlePanEnd(DragEndDetails details) {
    _isTouching = false;
    _joystickPosition = Offset.zero;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _showJoystick = false;
      if (mounted) setState(() {});
    });
  }

  Widget _buildJoystick() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // Joystick base
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Joystick handle
          Center(
            child: Transform.translate(
              offset: _joystickPosition,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
