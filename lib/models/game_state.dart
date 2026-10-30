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
  
  // Camera
  Offset cameraOffset;
  double cameraZoom;
  
  // Interaction
  Offset? selectedTile;
  String interactionTarget;
  
  // Random instance
  final Random _random = Random();

  GameState({
    Offset? playerStart,
    int? worldSeed,
  }) : player = Player(
          position: playerStart ?? const Offset(50, 50),
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
      player.position = world.playerSpawn;
    }
    cameraOffset = Offset(
      player.position.dx - 8,
      player.position.dy - 6,
    );
  }

  void update(double deltaTime) {
    if (isPaused) return;
    
    // Update world time
    world.updateTime(deltaTime);
    
    // Update player stats
    player.updateStats();
    
    // Check for interactions
    _checkInteractions();
    
    // Update camera
    _updateCamera();
    
    notifyListeners();
  }

  void movePlayer(Offset direction) {
    if (isPaused) return;
    
    Offset newPosition = Offset(
      player.position.dx + direction.dx,
      player.position.dy + direction.dy,
    );
    
    // Check collision
    int tileX = newPosition.dx.floor();
    int tileY = newPosition.dy.floor();
    
    String tile = world.getTileAt(tileX, tileY);
    String object = world.getObjectAt(tileX, tileY);
    
    // Can't walk through water without a bridge
    if (tile == 'water' && player.selectedTool != 'boat') {
      return;
    }
    
    // Can't walk through walls
    if (tile == 'wood_wall' || tile == 'stone') {
      return;
    }
    
    player.move(direction);
    
    // Update direction
    if (direction.dx > 0) {
      player.updateDirection('right');
    } else if (direction.dx < 0) {
      player.updateDirection('left');
    } else if (direction.dy > 0) {
      player.updateDirection('down');
    } else if (direction.dy < 0) {
      player.updateDirection('up');
    }
    
    // Small energy cost for moving
    player.energy = (player.energy - 0.05).clamp(0, player.maxEnergy).floor();
  }

  void _updateCamera() {
    Offset targetOffset = Offset(
      player.position.dx - 8,
      player.position.dy - 6,
    );
    
    cameraOffset = Offset.lerp(
      cameraOffset,
      targetOffset,
      0.1,
    )!;
  }

  void _checkInteractions() {
    int tileX = player.position.dx.floor();
    int tileY = player.position.dy.floor();
    
    // Check for trees
    for (var entry in world.trees.entries) {
      if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
        interactionTarget = 'tree';
        return;
      }
    }
    
    // Check for rocks
    for (var entry in world.rocks.entries) {
      if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
        interactionTarget = 'rock';
        return;
      }
    }
    
    // Check for water
    for (var entry in world.water.entries) {
      if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
        interactionTarget = 'water';
        return;
      }
    }
    
    // Check for plants
    for (var entry in world.plants.entries) {
      if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
        interactionTarget = world.plants[entry.key]!;
        return;
      }
    }
    
    // Check for animals
    for (var entry in world.animals.entries) {
      if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
        interactionTarget = world.animals[entry.key]!;
        return;
      }
    }
    
    // Check for village
    for (var location in world.villageLocations) {
      if ((location - player.position).distance <= 3) {
        interactionTarget = 'village';
        return;
      }
    }
    
    interactionTarget = 'none';
  }

  void interact() {
    if (isPaused) return;
    
    int tileX = player.position.dx.floor();
    int tileY = player.position.dy.floor();
    
    switch (interactionTarget) {
      case 'tree':
        if (player.selectedTool == 'axe' || player.selectedTool == 'none') {
          // Find and remove the tree
          for (var entry in world.trees.entries.toList()) {
            if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
              world.trees.remove(entry.key);
              player.addItem('wood', 3);
              player.addExperience(5);
              currentAction = 'Chopped tree! +3 Wood';
              break;
            }
          }
        }
        break;
        
      case 'rock':
        if (player.selectedTool == 'pickaxe' || player.selectedTool == 'none') {
          for (var entry in world.rocks.entries.toList()) {
            if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY) {
              world.rocks.remove(entry.key);
              player.addItem('stone', 2);
              player.addExperience(5);
              currentAction = 'Mined rock! +2 Stone';
              break;
            }
          }
        }
        break;
        
      case 'water':
        if (player.selectedTool == 'fishing_rod') {
          if (_random.nextDouble() < 0.3) {
            player.addItem('fish', 1);
            player.addExperience(10);
            currentAction = 'Caught a fish!';
          } else {
            currentAction = 'Nothing caught...';
          }
        }
        break;
        
      case 'berry_bush':
        for (var entry in world.plants.entries.toList()) {
          if (entry.key.dx.floor() == tileX && entry.key.dy.floor() == tileY && entry.value == 'berry_bush') {
            world.plants.remove(entry.key);
            player.addItem('berry', 2);
            player.addExperience(3);
            currentAction = 'Picked berries! +2 Berries';
            break;
          }
        }
        break;
        
      case 'rabbit':
      case 'deer':
      case 'bird':
        currentAction = 'The ${interactionTarget} ran away!';
        break;
        
      case 'village':
        currentAction = 'Welcome to the village!';
        break;
        
      default:
        currentAction = 'Nothing to interact with';
    }
    
    Future.delayed(const Duration(seconds: 2), () {
      currentAction = 'none';
      notifyListeners();
    });
  }

  void selectTool(String tool) {
    if (player.inventory[tool]! > 0) {
      player.selectedTool = tool;
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
    switch (recipe) {
      case 'stick':
        if (player.inventory['wood']! >= 1) {
          player.removeItem('wood', 1);
          player.addItem('stick', 1);
          player.addExperience(2);
        }
        break;
        
      case 'wooden_sword':
        if (player.inventory['wood']! >= 2 && player.inventory['stick']! >= 1) {
          player.removeItem('wood', 2);
          player.removeItem('stick', 1);
          player.addItem('wooden_sword', 1);
          player.addExperience(10);
        }
        break;
        
      case 'campfire':
        if (player.inventory['wood']! >= 5 && player.inventory['stone']! >= 3) {
          player.removeItem('wood', 5);
          player.removeItem('stone', 3);
          player.addItem('campfire', 1);
          player.addExperience(15);
        }
        break;
        
      case 'fishing_rod':
        if (player.inventory['stick']! >= 2 && player.inventory['wood']! >= 1) {
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
    player.energy = (player.energy + 1).clamp(0, player.maxEnergy);
    player.hunger = (player.hunger - 0.1).clamp(0, player.maxHunger).floor();
    
    if (player.hunger > 50 && _random.nextDouble() < 0.01) {
      player.heal(1);
    }
  }
}
