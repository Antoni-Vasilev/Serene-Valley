import 'package:flutter/material.dart';
import 'dart:math';
import 'player.dart';
import 'world.dart';

class GameState with ChangeNotifier {
  Player player;
  World world;

  // Game state
  bool isPaused;
  bool showInventory;
  bool showCrafting;
  bool showMap;
  String currentAction;

  // Camera: the world position (in tiles) shown at the centre of the screen.
  Offset cameraOffset;
  double cameraZoom;

  // Movement requested by the controls, each axis in -1..1.
  Offset moveInput = Offset.zero;
  bool isMoving = false;
  // Seconds spent walking; drives the walk animation.
  double walkTime = 0;

  // Interaction
  String interactionTarget;
  String? _interactionKey;
  String? get interactionKey => _interactionKey;

  // Random instance
  final Random _random = Random();
  int _actionMessageId = 0;

  GameState({
    Offset? playerStart,
    int? worldSeed,
  })  : player = Player(
          position: playerStart ?? const Offset(50.5, 50.5),
        ),
        world = World(seed: worldSeed),
        isPaused = false,
        showInventory = false,
        showCrafting = false,
        showMap = false,
        currentAction = 'none',
        cameraOffset = Offset.zero,
        cameraZoom = 2.0,
        interactionTarget = 'none' {
    world.generate();
    if (playerStart == null) {
      player.position = world.playerSpawn + const Offset(0.5, 0.5);
    }
    cameraOffset = player.position;
  }

  bool get isMenuOpen => showInventory || showCrafting || showMap || isPaused;

  /// Advances the simulation by [dt] seconds.
  void update(double dt) {
    if (isPaused) return;

    world.updateTime(dt);

    isMoving = moveInput != Offset.zero && !isMenuOpen;
    if (isMoving) {
      _movePlayer(moveInput, dt);
      walkTime += dt;
    }

    player.updateStats(dt, moving: isMoving);
    if (player.isDead) {
      _respawn();
    }

    _checkInteractions();
    _updateCamera(dt);

    notifyListeners();
  }

  void _movePlayer(Offset direction, double dt) {
    if (direction.distance > 1) {
      direction = direction / direction.distance;
    }
    final step = direction * player.speed * dt;

    // Resolve each axis separately so the player slides along walls.
    final pos = player.position;
    final nextX = Offset(pos.dx + step.dx, pos.dy);
    if (_canStandAt(nextX)) player.position = nextX;
    final nextY = Offset(player.position.dx, pos.dy + step.dy);
    if (_canStandAt(nextY)) player.position = nextY;

    if (direction.dx.abs() > direction.dy.abs()) {
      player.updateDirection(direction.dx > 0 ? 'right' : 'left');
    } else {
      player.updateDirection(direction.dy > 0 ? 'down' : 'up');
    }
  }

  bool _canStandAt(Offset p) {
    // Check the corners of a slightly smaller-than-tile hitbox.
    const r = 0.3;
    for (final c in [
      Offset(p.dx - r, p.dy - r),
      Offset(p.dx + r, p.dy - r),
      Offset(p.dx - r, p.dy + r),
      Offset(p.dx + r, p.dy + r),
    ]) {
      if (!world.isWalkable(c.dx.floor(), c.dy.floor())) return false;
    }
    return true;
  }

  void _updateCamera(double dt) {
    // Frame-rate independent smoothing.
    final t = 1 - pow(0.001, dt).toDouble();
    cameraOffset = Offset.lerp(cameraOffset, player.position, t)!;
  }

  /// Finds the key of the closest entry in [items] within reach of the player.
  String? _nearest(Map<String, Offset> items, {String prefix = ''}) {
    String? best;
    double bestDist = 1.3;
    for (final entry in items.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final centre = entry.value + const Offset(0.5, 0.5);
      final d = (centre - player.position).distance;
      if (d < bestDist) {
        bestDist = d;
        best = entry.key;
      }
    }
    return best;
  }

  bool _isNextToWater() {
    final px = player.position.dx.floor();
    final py = player.position.dy.floor();
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (world.getTileAt(px + dx, py + dy) == 'water') return true;
      }
    }
    return false;
  }

  void _checkInteractions() {
    String? key;
    if ((key = _nearest(world.trees)) != null) {
      interactionTarget = 'tree';
    } else if ((key = _nearest(world.rocks)) != null) {
      interactionTarget = 'rock';
    } else if ((key = _nearest(world.plants, prefix: 'berry_bush')) != null) {
      interactionTarget = 'berry_bush';
    } else if ((key = _nearest(world.animals)) != null) {
      interactionTarget = 'animal';
    } else if (_isNextToWater()) {
      interactionTarget = 'water';
    } else if (world.villageLocations
        .any((l) => (l - player.position).distance <= 4)) {
      interactionTarget = 'village';
    } else {
      interactionTarget = 'none';
    }
    _interactionKey = key;
  }

  void interact() {
    if (isPaused) return;
    final key = _interactionKey;

    switch (interactionTarget) {
      case 'tree':
        if (player.selectedTool == 'axe' || player.selectedTool == 'none') {
          world.trees.remove(key);
          player.addItem('wood', 3);
          if (_random.nextDouble() < 0.3) player.addItem('apple', 1);
          player.addExperience(5);
          _showAction('Chopped tree! +3 Wood');
        } else {
          _showAction('Use an axe to chop trees');
        }
        break;

      case 'rock':
        if (player.selectedTool == 'pickaxe' || player.selectedTool == 'none') {
          world.rocks.remove(key);
          player.addItem('stone', 2);
          player.addExperience(5);
          _showAction('Mined rock! +2 Stone');
        } else {
          _showAction('Use a pickaxe to mine rocks');
        }
        break;

      case 'water':
        if (player.selectedTool == 'fishing_rod') {
          if (_random.nextDouble() < 0.3) {
            player.addItem('fish', 1);
            player.addExperience(10);
            _showAction('Caught a fish!');
          } else {
            _showAction('Nothing caught...');
          }
        } else {
          _showAction('Select the fishing rod to fish');
        }
        break;

      case 'berry_bush':
        world.plants.remove(key);
        player.addItem('berry', 2);
        player.addExperience(3);
        _showAction('Picked berries! +2 Berries');
        break;

      case 'animal':
        world.animals.remove(key);
        _showAction('The animal ran away!');
        break;

      case 'village':
        _showAction('Welcome to the village!');
        break;

      default:
        _showAction('Nothing to interact with');
    }
    notifyListeners();
  }

  void _showAction(String message) {
    currentAction = message;
    final id = ++_actionMessageId;
    Future.delayed(const Duration(seconds: 2), () {
      // Only clear if no newer message replaced this one.
      if (id == _actionMessageId) {
        currentAction = 'none';
        notifyListeners();
      }
    });
  }

  void _respawn() {
    player.health = (player.maxHealth / 2).ceil();
    player.hunger = player.maxHunger / 2;
    player.energy = player.maxEnergy / 2;
    player.position = world.playerSpawn + const Offset(0.5, 0.5);
    _showAction('You fainted and woke up in the village...');
  }

  void selectTool(String tool) {
    if (player.count(tool) > 0) {
      player.selectedTool = player.selectedTool == tool ? 'none' : tool;
      showInventory = false;
      notifyListeners();
    }
  }

  void eatFood(String food) {
    switch (food) {
      case 'apple':
        player.consumeFood(food, 20, 5);
        break;
      case 'berry':
        player.consumeFood(food, 10, 2);
        break;
      case 'fish':
        player.consumeFood(food, 30, 10);
        break;
    }
    showInventory = false;
    notifyListeners();
  }

  void toggleInventory() {
    showInventory = !showInventory;
    showCrafting = false;
    showMap = false;
    notifyListeners();
  }

  void toggleCrafting() {
    showCrafting = !showCrafting;
    showInventory = false;
    showMap = false;
    notifyListeners();
  }

  void toggleMap() {
    showMap = !showMap;
    showInventory = false;
    showCrafting = false;
    notifyListeners();
  }

  void togglePause() {
    isPaused = !isPaused;
    notifyListeners();
  }

  void craftItem(String recipe) {
    final inv = player;
    switch (recipe) {
      case 'stick':
        if (inv.count('wood') >= 1) {
          player.removeItem('wood', 1);
          player.addItem('stick', 1);
          player.addExperience(2);
        }
        break;

      case 'wooden_sword':
        if (inv.count('wood') >= 2 && inv.count('stick') >= 1) {
          player.removeItem('wood', 2);
          player.removeItem('stick', 1);
          player.addItem('wooden_sword', 1);
          player.addExperience(10);
        }
        break;

      case 'campfire':
        if (inv.count('wood') >= 5 && inv.count('stone') >= 3) {
          player.removeItem('wood', 5);
          player.removeItem('stone', 3);
          player.addItem('campfire', 1);
          player.addExperience(15);
        }
        break;

      case 'fishing_rod':
        if (inv.count('stick') >= 2 && inv.count('wood') >= 1) {
          player.removeItem('stick', 2);
          player.removeItem('wood', 1);
          player.addItem('fishing_rod', 1);
          player.addExperience(10);
        }
        break;
    }

    showCrafting = false;
    notifyListeners();
  }

  void rest() {
    if (isPaused) return;
    player.rest();
    if (player.hunger > 50 && _random.nextDouble() < 0.3) {
      player.heal(1);
    }
    _showAction('Rested. +10 Energy');
    notifyListeners();
  }
}
