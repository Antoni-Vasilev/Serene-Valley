import 'package:flutter/material.dart';
import '../models/world.dart';
import '../models/game_state.dart';
import 'tile_widget.dart';
import 'player_widget.dart';

class WorldWidget extends StatelessWidget {
  final World world;
  final GameState gameState;
  final double tileSize;

  const WorldWidget({
    super.key,
    required this.world,
    required this.gameState,
    required this.tileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Container(
            color: world.getTimeColor(),
          ),
        ),
        
        // Tile grid
        ..._buildTiles(),
        
        // Objects (trees, rocks, etc.)
        ..._buildObjects(),
        
        // Animals
        ..._buildAnimals(),
        
        // Player
        PlayerWidget(
          player: gameState.player,
          tileSize: tileSize,
        ),
        
        // Overlay for night
        if (!world.isDay)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTiles() {
    List<Widget> tiles = [];
    
    int startX = (gameState.cameraOffset.dx / tileSize).floor() - 2;
    int startY = (gameState.cameraOffset.dy / tileSize).floor() - 2;
    int endX = startX + (MediaQuery.of(navigatorKey.currentContext!).size.width / tileSize).ceil() + 4;
    int endY = startY + (MediaQuery.of(navigatorKey.currentContext!).size.height / tileSize).ceil() + 4;
    
    // Clamp to world bounds
    startX = startX.clamp(0, world.width - 1);
    startY = startY.clamp(0, world.height - 1);
    endX = endX.clamp(0, world.width);
    endY = endY.clamp(0, world.height);
    
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        if (x >= 0 && x < world.width && y >= 0 && y < world.height) {
          String tileType = world.getTileAt(x, y);
          
          tiles.add(
            Positioned(
              left: x * tileSize,
              top: y * tileSize,
              child: TileWidget(
                tileType: tileType,
                tileSize: tileSize,
                lightLevel: world.getLightLevel(),
              ),
            ),
          );
        }
      }
    }
    
    return tiles;
  }

  List<Widget> _buildObjects() {
    List<Widget> objects = [];
    
    // Trees
    for (var entry in world.trees.entries) {
      int x = entry.key.dx.floor();
      int y = entry.key.dy.floor();
      
      // Only render visible trees
      if (_isVisible(x, y)) {
        objects.add(
          Positioned(
            left: entry.key.dx * tileSize,
            top: entry.key.dy * tileSize,
            child: _buildTree(tileSize),
          ),
        );
      }
    }
    
    // Rocks
    for (var entry in world.rocks.entries) {
      int x = entry.key.dx.floor();
      int y = entry.key.dy.floor();
      
      if (_isVisible(x, y)) {
        objects.add(
          Positioned(
            left: entry.key.dx * tileSize,
            top: entry.key.dy * tileSize,
            child: _buildRock(tileSize),
          ),
        );
      }
    }
    
    // Water objects
    for (var entry in world.water.entries) {
      int x = entry.key.dx.floor();
      int y = entry.key.dy.floor();
      
      if (_isVisible(x, y)) {
        objects.add(
          Positioned(
            left: entry.key.dx * tileSize,
            top: entry.key.dy * tileSize,
            child: _buildWaterObject(tileSize, entry.value),
          ),
        );
      }
    }
    
    // Plants
    for (var entry in world.plants.entries) {
      int x = entry.key.dx.floor();
      int y = entry.key.dy.floor();
      
      if (_isVisible(x, y)) {
        objects.add(
          Positioned(
            left: entry.key.dx * tileSize,
            top: entry.key.dy * tileSize,
            child: _buildPlant(tileSize, entry.value),
          ),
        );
      }
    }
    
    // Village markers
    for (var location in world.villageLocations) {
      if (_isVisible(location.dx.floor(), location.dy.floor())) {
        objects.add(
          Positioned(
            left: location.dx * tileSize,
            top: location.dy * tileSize,
            child: _buildVillageMarker(tileSize),
          ),
        );
      }
    }
    
    // Cave entrances
    for (var location in world.caveEntrances) {
      if (_isVisible(location.dx.floor(), location.dy.floor())) {
        objects.add(
          Positioned(
            left: location.dx * tileSize,
            top: location.dy * tileSize,
            child: _buildCaveEntrance(tileSize),
          ),
        );
      }
    }
    
    return objects;
  }

  List<Widget> _buildAnimals() {
    List<Widget> animals = [];
    
    for (var entry in world.animals.entries) {
      int x = entry.key.dx.floor();
      int y = entry.key.dy.floor();
      
      if (_isVisible(x, y)) {
        animals.add(
          Positioned(
            left: entry.key.dx * tileSize,
            top: entry.key.dy * tileSize,
            child: _buildAnimal(tileSize, entry.value),
          ),
        );
      }
    }
    
    return animals;
  }

  bool _isVisible(int x, int y) {
    double screenWidth = MediaQuery.of(navigatorKey.currentContext!).size.width;
    double screenHeight = MediaQuery.of(navigatorKey.currentContext!).size.height;
    
    double left = x * tileSize;
    double top = y * tileSize;
    double right = left + tileSize;
    double bottom = top + tileSize;
    
    double cameraLeft = gameState.cameraOffset.dx;
    double cameraTop = gameState.cameraOffset.dy;
    double cameraRight = cameraLeft + screenWidth;
    double cameraBottom = cameraTop + screenHeight;
    
    return right > cameraLeft && left < cameraRight && 
           bottom > cameraTop && top < cameraBottom;
  }

  Widget _buildTree(double size) {
    return SizedBox(
      width: size,
      height: size * 2,
      child: Stack(
        children: [
          // Trunk
          Positioned(
            left: size * 0.4,
            bottom: 0,
            child: Container(
              width: size * 0.2,
              height: size * 0.6,
              color: const Color(0xFF8B4513),
            ),
          ),
          // Leaves
          Positioned(
            left: size * 0.1,
            top: size * 0.2,
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                color: const Color(0xFF228B22),
                borderRadius: BorderRadius.circular(size * 0.4),
              ),
            ),
          ),
          Positioned(
            left: size * 0.2,
            top: size * 0.5,
            child: Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: BoxDecoration(
                color: const Color(0xFF32CD32),
                borderRadius: BorderRadius.circular(size * 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRock(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF808080),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Stack(
          children: [
            // Rock texture
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF696969), Color(0xFFA9A9A9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(size * 0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterObject(double size, String type) {
    if (type == 'river') {
      return Container(
        width: size,
        height: size,
        color: Colors.blue.withOpacity(0.6),
      );
    } else {
      return Container(
        width: size,
        height: size,
        color: Colors.blue.withOpacity(0.4),
      );
    }
  }

  Widget _buildPlant(double size, String type) {
    switch (type) {
      case 'berry_bush':
        return SizedBox(
          width: size,
          height: size * 0.8,
          child: Stack(
            children: [
              // Bush
              Positioned(
                left: size * 0.2,
                bottom: 0,
                child: Container(
                  width: size * 0.6,
                  height: size * 0.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22),
                    borderRadius: BorderRadius.circular(size * 0.2),
                  ),
                ),
              ),
              // Berries
              Positioned(
                left: size * 0.3,
                top: size * 0.2,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.1,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: size * 0.5,
                top: size * 0.3,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.1,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
        
      case 'flower':
        return SizedBox(
          width: size,
          height: size * 0.5,
          child: Stack(
            children: [
              // Stem
              Positioned(
                left: size * 0.45,
                bottom: 0,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.4,
                  color: Colors.green,
                ),
              ),
              // Flower
              Positioned(
                left: size * 0.4,
                top: 0,
                child: Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
        
      default: // grass_tall
        return SizedBox(
          width: size,
          height: size * 0.8,
          child: Container(
            width: size * 0.2,
            height: size * 0.8,
            color: Colors.green,
          ),
        );
    }
  }

  Widget _buildAnimal(double size, String type) {
    switch (type) {
      case 'rabbit':
        return SizedBox(
          width: size,
          height: size * 0.6,
          child: Stack(
            children: [
              // Body
              Positioned(
                left: size * 0.2,
                top: size * 0.2,
                child: Container(
                  width: size * 0.6,
                  height: size * 0.4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(size * 0.2),
                  ),
                ),
              ),
              // Head
              Positioned(
                left: size * 0.4,
                top: size * 0.1,
                child: Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Ears
              Positioned(
                left: size * 0.35,
                top: size * 0.05,
                child: Container(
                  width: size * 0.05,
                  height: size * 0.15,
                  color: Colors.white,
                ),
              ),
              Positioned(
                left: size * 0.55,
                top: size * 0.05,
                child: Container(
                  width: size * 0.05,
                  height: size * 0.15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
        
      case 'deer':
        return SizedBox(
          width: size,
          height: size * 0.8,
          child: Stack(
            children: [
              // Body
              Positioned(
                left: size * 0.2,
                top: size * 0.3,
                child: Container(
                  width: size * 0.6,
                  height: size * 0.4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513),
                    borderRadius: BorderRadius.circular(size * 0.2),
                  ),
                ),
              ),
              // Head
              Positioned(
                left: size * 0.4,
                top: size * 0.2,
                child: Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Antlers
              Positioned(
                left: size * 0.3,
                top: size * 0.1,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.15,
                  color: const Color(0xFF8B4513),
                ),
              ),
              Positioned(
                left: size * 0.5,
                top: size * 0.1,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.15,
                  color: const Color(0xFF8B4513),
                ),
              ),
              // Legs
              Positioned(
                left: size * 0.25,
                top: size * 0.6,
                child: Container(
                  width: size * 0.08,
                  height: size * 0.2,
                  color: const Color(0xFF8B4513),
                ),
              ),
              Positioned(
                left: size * 0.45,
                top: size * 0.6,
                child: Container(
                  width: size * 0.08,
                  height: size * 0.2,
                  color: const Color(0xFF8B4513),
                ),
              ),
            ],
          ),
        );
        
      default: // bird
        return SizedBox(
          width: size,
          height: size * 0.4,
          child: Stack(
            children: [
              // Body
              Positioned(
                left: size * 0.3,
                top: size * 0.1,
                child: Container(
                  width: size * 0.4,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(size * 0.1),
                  ),
                ),
              ),
              // Head
              Positioned(
                left: size * 0.5,
                top: size * 0.1,
                child: Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Beak
              Positioned(
                left: size * 0.65,
                top: size * 0.15,
                child: Container(
                  width: size * 0.05,
                  height: size * 0.05,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildVillageMarker(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.6,
          height: size * 0.6,
          decoration: BoxDecoration(
            color: Colors.brown,
            borderRadius: BorderRadius.circular(size * 0.1),
          ),
          child: const Icon(
            Icons.house,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCaveEntrance(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.8,
          height: size * 0.4,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(size * 0.2),
          ),
        ),
      ),
    );
  }
}

// Global key for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
