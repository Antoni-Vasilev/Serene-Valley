import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';

class World {
  final int width;
  final int height;
  final int tileSize;
  final Random random;
  
  // Time system
  double timeOfDay;
  bool isDay;
  
  // World data
  List<List<String>> tiles;
  List<List<String>> objects;
  Map<String, Offset> trees;
  Map<String, Offset> rocks;
  Map<String, Offset> water;
  Map<String, Offset> animals;
  Map<String, Offset> plants;
  
  // Spawn points
  Offset playerSpawn;
  List<Offset> villageLocations;
  List<Offset> caveEntrances;
  List<Offset> riverPaths;

  World({
    this.width = 100,
    this.height = 100,
    this.tileSize = 16,
    int? seed,
  }) : random = Random(seed ?? DateTime.now().millisecondsSinceEpoch),
       tiles = [],
       objects = [],
       trees = {},
       rocks = {},
       water = {},
       animals = {},
       plants = {},
       playerSpawn = const Offset(50, 50),
       villageLocations = [],
       caveEntrances = [],
       riverPaths = [],
       timeOfDay = 6.0,
       isDay = true;

  void generate() {
    // Initialize tiles
    tiles = List.generate(height, (y) => List.filled(width, 'grass'));
    objects = List.generate(height, (y) => List.filled(width, 'none'));
    
    // Generate terrain
    _generateTerrain();
    _generateRivers();
    _generateForests();
    _generateMountains();
    _generateVillage();
    _generateCaves();
    
    // Generate resources
    _generateTrees();
    _generateRocks();
    _generatePlants();
    _generateAnimals();
    
    // Generate water bodies
    _generateLakes();
  }

  void _generateTerrain() {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double noise = random.nextDouble();
        if (noise < 0.05) {
          tiles[y][x] = 'dirt';
        } else if (noise < 0.1) {
          tiles[y][x] = 'sand';
        } else if (noise < 0.15) {
          tiles[y][x] = 'stone';
        }
      }
    }
  }

  void _generateRivers() {
    int startX = random.nextInt(width);
    int startY = 0;
    
    for (int y = startY; y < height; y++) {
      int x = startX + (random.nextInt(3) - 1);
      x = x.clamp(0, width - 1);
      
      if (random.nextDouble() < 0.7) {
        tiles[y][x] = 'water';
        water['river_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        riverPaths.add(Offset(x.toDouble(), y.toDouble()));
      }
      
      startX = x;
    }
  }

  void _generateForests() {
    int forestCount = random.nextInt(5) + 3;
    for (int i = 0; i < forestCount; i++) {
      int centerX = random.nextInt(width - 20) + 10;
      int centerY = random.nextInt(height - 20) + 10;
      int forestSize = random.nextInt(15) + 10;
      
      for (int y = centerY - forestSize; y < centerY + forestSize; y++) {
        for (int x = centerX - forestSize; x < centerX + forestSize; x++) {
          if (x >= 0 && x < width && y >= 0 && y < height) {
            double dist = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));
            if (dist < forestSize && random.nextDouble() < 0.3) {
              tiles[y][x] = 'forest_grass';
            }
          }
        }
      }
    }
  }

  void _generateMountains() {
    int mountainCount = random.nextInt(3) + 2;
    for (int i = 0; i < mountainCount; i++) {
      int centerX = random.nextInt(width - 30) + 15;
      int centerY = random.nextInt(height - 30) + 15;
      int mountainSize = random.nextInt(10) + 8;
      
      for (int y = centerY - mountainSize; y < centerY + mountainSize; y++) {
        for (int x = centerX - mountainSize; x < centerX + mountainSize; x++) {
          if (x >= 0 && x < width && y >= 0 && y < height) {
            double dist = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));
            if (dist < mountainSize) {
              double heightFactor = 1.0 - (dist / mountainSize);
              if (random.nextDouble() < heightFactor * 0.5) {
                tiles[y][x] = 'stone';
              } else if (random.nextDouble() < heightFactor * 0.8) {
                tiles[y][x] = 'dirt';
              }
            }
          }
        }
      }
    }
  }

  void _generateVillage() {
    int villageX = random.nextInt(width - 40) + 20;
    int villageY = random.nextInt(height - 40) + 20;
    
    villageLocations.add(Offset(villageX.toDouble(), villageY.toDouble()));
    
    for (int y = villageY - 2; y <= villageY + 2; y++) {
      for (int x = villageX - 2; x <= villageX + 2; x++) {
        if (x >= 0 && x < width && y >= 0 && y < height) {
          tiles[y][x] = 'wood_floor';
        }
      }
    }
    
    for (int i = 0; i < 3; i++) {
      int houseX = villageX + (random.nextInt(3) - 1) * 8;
      int houseY = villageY + (random.nextInt(3) - 1) * 6;
      
      for (int y = houseY; y < houseY + 4; y++) {
        for (int x = houseX; x < houseX + 6; x++) {
          if (x >= 0 && x < width && y >= 0 && y < height) {
            if (y == houseY || y == houseY + 3 || x == houseX || x == houseX + 5) {
              tiles[y][x] = 'wood_wall';
            } else {
              tiles[y][x] = 'wood_floor';
            }
          }
        }
      }
    }
    
    playerSpawn = Offset(villageX.toDouble(), villageY.toDouble() - 5);
  }

  void _generateCaves() {
    int caveCount = random.nextInt(3) + 1;
    for (int i = 0; i < caveCount; i++) {
      int caveX = random.nextInt(width - 10) + 5;
      int caveY = random.nextInt(height - 10) + 5;
      
      if (tiles[caveY][caveX] == 'stone' || tiles[caveY][caveX] == 'dirt') {
        caveEntrances.add(Offset(caveX.toDouble(), caveY.toDouble()));
        objects[caveY][caveX] = 'cave_entrance';
      }
    }
  }

  void _generateTrees() {
    int treeCount = random.nextInt(100) + 150;
    for (int i = 0; i < treeCount; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      
      if (tiles[y][x] != 'water' && 
          tiles[y][x] != 'wood_floor' && 
          tiles[y][x] != 'wood_wall' &&
          random.nextDouble() < 0.7) {
        trees['tree_$x_$y'] = Offset(x.toDouble(), y.toDouble());
      }
    }
  }

  void _generateRocks() {
    int rockCount = random.nextInt(80) + 100;
    for (int i = 0; i < rockCount; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      
      if (tiles[y][x] != 'water' && 
          tiles[y][x] != 'wood_floor' && 
          tiles[y][x] != 'wood_wall' &&
          random.nextDouble() < 0.6) {
        rocks['rock_$x_$y'] = Offset(x.toDouble(), y.toDouble());
      }
    }
  }

  void _generatePlants() {
    int plantCount = random.nextInt(200) + 300;
    for (int i = 0; i < plantCount; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      
      if (tiles[y][x] != 'water' && 
          tiles[y][x] != 'wood_floor' && 
          tiles[y][x] != 'wood_wall' &&
          tiles[y][x] != 'stone' &&
          random.nextDouble() < 0.5) {
        
        if (random.nextDouble() < 0.4) {
          plants['berry_bush_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        } else if (random.nextDouble() < 0.6) {
          plants['flower_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        } else {
          plants['grass_tall_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        }
      }
    }
  }

  void _generateAnimals() {
    int animalCount = random.nextInt(30) + 40;
    for (int i = 0; i < animalCount; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      
      if (tiles[y][x] != 'water' && 
          tiles[y][x] != 'wood_floor' && 
          tiles[y][x] != 'wood_wall') {
        
        if (random.nextDouble() < 0.4) {
          animals['rabbit_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        } else if (random.nextDouble() < 0.7) {
          animals['deer_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        } else {
          animals['bird_$x_$y'] = Offset(x.toDouble(), y.toDouble());
        }
      }
    }
  }

  void _generateLakes() {
    int lakeCount = random.nextInt(3) + 2;
    for (int i = 0; i < lakeCount; i++) {
      int centerX = random.nextInt(width - 20) + 10;
      int centerY = random.nextInt(height - 20) + 10;
      int lakeSize = random.nextInt(8) + 5;
      
      for (int y = centerY - lakeSize; y < centerY + lakeSize; y++) {
        for (int x = centerX - lakeSize; x < centerX + lakeSize; x++) {
          if (x >= 0 && x < width && y >= 0 && y < height) {
            double dist = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));
            if (dist < lakeSize && random.nextDouble() < 0.6) {
              tiles[y][x] = 'water';
              water['lake_$x_$y'] = Offset(x.toDouble(), y.toDouble());
            }
          }
        }
      }
    }
  }

  String getTileAt(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      return tiles[y][x];
    }
    return 'void';
  }

  String getObjectAt(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      return objects[y][x];
    }
    return 'none';
  }

  void updateTime(double deltaTime) {
    timeOfDay += deltaTime * 0.001;
    
    if (timeOfDay >= 24.0) {
      timeOfDay = 0.0;
    }
    
    isDay = timeOfDay >= 6.0 && timeOfDay <= 18.0;
  }

  Color getTimeColor() {
    if (timeOfDay >= 6.0 && timeOfDay <= 8.0) {
      double progress = (timeOfDay - 6.0) / 2.0;
      return Color.lerp(
        const Color(0xFF1a1a2e),
        const Color(0xFF87CEEB),
        progress,
      )!;
    } else if (timeOfDay >= 16.0 && timeOfDay <= 18.0) {
      double progress = (timeOfDay - 16.0) / 2.0;
      return Color.lerp(
        const Color(0xFF87CEEB),
        const Color(0xFF1a1a2e),
        progress,
      )!;
    } else if (isDay) {
      return const Color(0xFF87CEEB);
    } else {
      return const Color(0xFF1a1a2e);
    }
  }

  double getLightLevel() {
    if (isDay) {
      if (timeOfDay >= 12.0 && timeOfDay <= 13.0) {
        return 1.0;
      }
      double timeFromNoon = (timeOfDay - 12.0).abs();
      return 1.0 - (timeFromNoon / 6.0).clamp(0.0, 0.5);
    } else {
      return 0.2;
    }
  }
}
