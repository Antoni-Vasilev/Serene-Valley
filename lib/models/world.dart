import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'farm.dart';
import 'level.dart';
import 'npc.dart';

/// The valley: the village on the west bank of the river, and the hills
/// beyond it.
class World extends Level {
  final int tileSize;

  // Time system
  double timeOfDay;
  int day;
  bool isDay;

  // Objects keyed '<type>_<x>_<y>', positioned at their tile's top-left corner.
  Map<String, Offset> trees;
  Map<String, Offset> animals;
  Map<String, Offset> plants;
  Map<String, Offset> appleTrees;
  // Hours until a picked berry bush or apple tree bears fruit again.
  Map<String, double> regrowTimers;
  // Caves in the eastern hills. The first one leads into the old mine.
  List<Offset> caveEntrances;
  // Whether Elder Rowan has handed over the key to the old mine.
  bool mineOpen;

  // Village
  Offset playerSpawn;
  List<Offset> villageLocations;
  Offset bed;
  Offset firePit;
  bool firePitBuilt;
  // The old forge east of the plaza.
  bool forgeBuilt;

  // The storm-broken bridge on the road east of the village.
  List<Point<int>> bridgeTiles;
  bool bridgeBuilt;

  // Fenced farm field south of the plaza, in tiles.
  Rect farmArea;
  bool farmUnlocked;
  // Crops keyed '<x>_<y>'.
  Map<String, Crop> crops;

  // Generation scratch data.
  List<int> _riverWest = [];
  List<int> _riverEast = [];
  List<List<bool>> _reserved = [];
  List<Point<int>> _mountainEdge = [];

  static const double regrowHours = 24;
  // Real seconds in one in-game day.
  static const double secondsPerDay = 600;

  static const Set<String> _walkableTiles = {
    'grass',
    'dirt',
    'sand',
    'forest_grass',
    'wood_floor',
    'path',
    'bridge',
    'farmland',
  };

  World({
    super.width = 100,
    super.height = 100,
    this.tileSize = 16,
    super.seed,
  })  : trees = {},
        animals = {},
        plants = {},
        appleTrees = {},
        regrowTimers = {},
        caveEntrances = [],
        mineOpen = false,
        playerSpawn = const Offset(50, 50),
        villageLocations = [],
        bed = Offset.zero,
        firePit = Offset.zero,
        firePitBuilt = false,
        forgeBuilt = false,
        bridgeTiles = [],
        bridgeBuilt = false,
        farmArea = Rect.zero,
        farmUnlocked = false,
        crops = {},
        timeOfDay = 6.0,
        day = 1,
        isDay = true;

  Offset get villageCenter =>
      villageLocations.isEmpty ? Offset(width / 2, height / 2) : villageLocations.first;

  /// Fires that are burning: the village fire pit once rebuilt, and campfires.
  @override
  List<Offset> get fires => [if (firePitBuilt) firePit, ...campfires];

  /// The way into the old mine.
  Offset? get mineEntrance => caveEntrances.firstOrNull;

  /// The two tiles the forge stands on, east of the plaza.
  List<Point<int>> get forgeTiles {
    final x = villageCenter.dx.toInt() + 7;
    final y = villageCenter.dy.toInt() - 3;
    return [Point(x, y), Point(x + 1, y)];
  }

  /// Where Bram the miner stands once he is home again, beside the forge.
  Offset get minerHome => villageCenter + const Offset(9, -3);

  /// Whether the tree on (x, y) is a pine, which also gives resin. Pines
  /// grow in the forest, among the oaks.
  bool isPine(int x, int y) => getTileAt(x, y) == 'forest_grass' && tileHash(x, y) < 0.5;

  List<Rect>? _houses;

  /// Every house as a rectangle of tiles, walls included. Houses never change,
  /// so they are found once from the tiles.
  List<Rect> get houses => _houses ??= _findHouses();

  List<Rect> _findHouses() {
    bool isHouse(int x, int y) {
      final tile = getTileAt(x, y);
      return tile == 'wood_wall' || tile == 'wood_floor';
    }

    final seen = <Point<int>>{};
    final result = <Rect>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!isHouse(x, y) || seen.contains(Point(x, y))) continue;
        var left = x, right = x, top = y, bottom = y;
        final queue = Queue<Point<int>>()..add(Point(x, y));
        seen.add(Point(x, y));
        while (queue.isNotEmpty) {
          final p = queue.removeFirst();
          left = min(left, p.x);
          right = max(right, p.x);
          top = min(top, p.y);
          bottom = max(bottom, p.y);
          for (final n in [Point(p.x + 1, p.y), Point(p.x - 1, p.y), Point(p.x, p.y + 1), Point(p.x, p.y - 1)]) {
            if (isHouse(n.x, n.y) && seen.add(n)) queue.add(n);
          }
        }
        result.add(Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0));
      }
    }
    return result;
  }

  static String cropKey(int x, int y) => '${x}_$y';

  // ---------------------------------------------------------------------------
  // Generation

  void generate() {
    // Retry until the layout is playable. The seeded Random keeps this
    // deterministic for a given seed.
    for (var attempt = 0; attempt < 20; attempt++) {
      _generateOnce();
      if (_isPlayable()) break;
    }
    _ensureMineEntrance();
    _reserved = [];
    _mountainEdge = [];
  }

  void _generateOnce() {
    tiles = List.generate(height, (_) => List.filled(width, 'grass'));
    _reserved = List.generate(height, (_) => List.filled(width, false));
    trees = {};
    rocks = {};
    animals = {};
    plants = {};
    appleTrees = {};
    regrowTimers = {};
    caveEntrances = [];
    villageLocations = [];
    npcs = [];
    campfires = [];
    bridgeTiles = [];
    crops = {};
    bridgeBuilt = false;
    firePitBuilt = false;
    forgeBuilt = false;
    mineOpen = false;
    farmUnlocked = false;
    _mountainEdge = [];
    _houses = null;

    _generateTerrain();
    _generateForests();
    _generateRiver();
    _reserveVillage();
    _generateMountains();
    _generateLakes();
    _buildVillage();
    _generateCaves();
    _generateTrees();
    _generateRocks();
    _generatePlants();
    _generateAnimals();
    refreshSolid();
  }

  void _generateTerrain() {
    // Patches of bare dirt and sand break up the grass.
    final patches = 25 + random.nextInt(15);
    for (int i = 0; i < patches; i++) {
      final cx = random.nextInt(width);
      final cy = random.nextInt(height);
      final r = 1 + random.nextInt(3);
      final type = random.nextDouble() < 0.6 ? 'dirt' : 'sand';
      for (int y = cy - r - 1; y <= cy + r + 1; y++) {
        for (int x = cx - r - 1; x <= cx + r + 1; x++) {
          if (_inBounds(x, y) && _dist(x, y, cx, cy) <= r + random.nextDouble() * 0.8) {
            tiles[y][x] = type;
          }
        }
      }
    }
  }

  void _generateForests() {
    int forestCount = random.nextInt(4) + 4;
    for (int i = 0; i < forestCount; i++) {
      int centerX = random.nextInt(width - 20) + 10;
      int centerY = random.nextInt(height - 20) + 10;
      int forestSize = random.nextInt(8) + 8;

      for (int y = centerY - forestSize; y < centerY + forestSize; y++) {
        for (int x = centerX - forestSize; x < centerX + forestSize; x++) {
          if (_inBounds(x, y) &&
              _dist(x, y, centerX, centerY) < forestSize &&
              random.nextDouble() < 0.85) {
            tiles[y][x] = 'forest_grass';
          }
        }
      }
    }

    // Smooth the speckles into solid patches of forest floor.
    for (var pass = 0; pass < 2; pass++) {
      final before = [for (final row in tiles) List.of(row)];
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final tile = before[y][x];
          if (tile != 'grass' && tile != 'forest_grass') continue;
          var forest = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if ((dx != 0 || dy != 0) && _inBounds(x + dx, y + dy) && before[y + dy][x + dx] == 'forest_grass') {
                forest++;
              }
            }
          }
          if (tile == 'forest_grass' && forest < 3) tiles[y][x] = 'grass';
          if (tile == 'grass' && forest >= 5) tiles[y][x] = 'forest_grass';
        }
      }
    }
  }

  void _generateRiver() {
    // A continuous river, 2-3 tiles wide, runs from the top edge to the bottom
    // edge and splits the valley in two. Each row overlaps the previous one,
    // so there are no gaps to slip through.
    _riverWest = List.filled(height, 0);
    _riverEast = List.filled(height, 0);
    final minX = (width * 0.4).round();
    final maxX = (width * 0.6).round();
    int x = width ~/ 2 + random.nextInt(11) - 5;

    for (int y = 0; y < height; y++) {
      if (y > 0) {
        final r = random.nextDouble();
        if (r < 0.25) {
          x--;
        } else if (r > 0.75) {
          x++;
        }
        x = x.clamp(minX, maxX);
      }
      final riverWidth = random.nextDouble() < 0.3 ? 3 : 2;
      for (int i = 0; i < riverWidth; i++) {
        tiles[y][x + i] = 'water';
      }
      _riverWest[y] = x;
      _riverEast[y] = x + riverWidth - 1;
    }
  }

  void _reserveVillage() {
    // The village sits on the west bank with room for houses, farm and orchard.
    final vy = 22 + random.nextInt(height - 44);
    final maxX = _riverWest[vy] - 16;
    final vx = 12 + random.nextInt(max(1, maxX - 11));
    villageLocations = [Offset(vx.toDouble(), vy.toDouble())];

    _reserve(vx - 11, vy - 9, vx + 10, vy + 10);
    // Keep the road to the bridge and the landing on the far bank clear.
    for (int y = vy - 2; y <= vy + 3; y++) {
      _reserve(vx + 3, y, _riverWest[y], y);
      _reserve(_riverEast[y] + 1, y - 1, _riverEast[y] + 7, y + 1);
    }
  }

  void _generateMountains() {
    // Rocky hills rise only on the east bank, beyond the river.
    final count = 3 + random.nextInt(2);
    for (int i = 0; i < count; i++) {
      final centerY = 12 + random.nextInt(height - 24);
      final minX = _riverEast[centerY] + 9;
      final maxX = width - 10;
      if (minX >= maxX) continue;
      final centerX = minX + random.nextInt(maxX - minX);
      final size = 6 + random.nextInt(4);

      for (int y = centerY - size; y <= centerY + size; y++) {
        for (int x = centerX - size; x <= centerX + size; x++) {
          // Never spill over to the village side where the river bends.
          if (!_inBounds(x, y) || _reserved[y][x] || x <= _riverEast[y] + 1 || tiles[y][x] == 'water') continue;
          final d = _dist(x, y, centerX, centerY) + random.nextDouble() * 0.8;
          if (d < size * 0.55) {
            tiles[y][x] = 'stone';
          } else if (d < size) {
            tiles[y][x] = 'dirt';
            _mountainEdge.add(Point(x, y));
          }
        }
      }
    }
  }

  void _generateLakes() {
    int lakeCount = random.nextInt(3) + 2;
    for (int i = 0; i < lakeCount; i++) {
      int centerX = random.nextInt(width - 16) + 8;
      int centerY = random.nextInt(height - 16) + 8;
      int lakeSize = random.nextInt(4) + 3;

      for (int y = centerY - lakeSize; y <= centerY + lakeSize; y++) {
        for (int x = centerX - lakeSize; x <= centerX + lakeSize; x++) {
          if (!_inBounds(x, y) || _reserved[y][x] || tiles[y][x] == 'stone') continue;
          final d = _dist(x, y, centerX, centerY) + random.nextDouble() * 1.2;
          if (d < lakeSize) {
            tiles[y][x] = 'water';
          }
        }
      }
    }
  }

  void _buildVillage() {
    final vx = villageCenter.dx.toInt();
    final vy = villageCenter.dy.toInt();

    // Clear the village grounds in a rough oval around the buildings.
    for (int y = vy - 14; y <= vy + 15; y++) {
      for (int x = vx - 15; x <= vx + 15; x++) {
        if (!_inBounds(x, y) || tiles[y][x] == 'water') continue;
        final dx = (x - vx + 0.5) / 14;
        final dy = (y - vy - 0.5) / 13;
        if (dx * dx + dy * dy < 1 + (random.nextDouble() - 0.5) * 0.25) tiles[y][x] = 'grass';
      }
    }

    // Plaza with the old fire pit in the middle.
    _fill(vx - 3, vy - 2, vx + 3, vy + 2, 'path');
    firePit = Offset(vx.toDouble(), vy.toDouble());

    // The player's house, Mira's house and the elder's house.
    _buildHouse(vx - 5, vy - 7, vx - 1, vy - 3, Point(vx - 3, vy - 3));
    _buildHouse(vx + 1, vy - 7, vx + 5, vy - 3, Point(vx + 3, vy - 3));
    _buildHouse(vx - 9, vy - 1, vx - 5, vy + 3, Point(vx - 7, vy + 3));
    bed = Offset(vx - 4.0, vy - 6.0);

    // Road east to the broken bridge, continuing on the far bank.
    for (int y = vy; y <= vy + 1; y++) {
      for (int x = vx + 4; x < _riverWest[y]; x++) {
        tiles[y][x] = 'path';
      }
      for (int x = _riverWest[y]; x <= _riverEast[y]; x++) {
        bridgeTiles.add(Point(x, y));
      }
      for (int x = _riverEast[y] + 1; x <= _riverEast[y] + 4 && x < width; x++) {
        tiles[y][x] = 'path';
      }
    }

    // Farm field inside a fence, with a gate facing the plaza.
    farmArea = Rect.fromLTWH(vx - 3.0, vy + 4.0, 6, 4);
    for (int y = vy + 3; y <= vy + 8; y++) {
      for (int x = vx - 4; x <= vx + 3; x++) {
        if (y == vy + 3 || y == vy + 8 || x == vx - 4 || x == vx + 3) {
          tiles[y][x] = 'fence';
        }
      }
    }
    tiles[vy + 3][vx - 1] = 'grass';
    tiles[vy + 3][vx] = 'grass';

    // A small orchard.
    for (final p in [
      Point(vx + 5, vy + 4),
      Point(vx + 7, vy + 5),
      Point(vx + 5, vy + 7),
      Point(vx + 8, vy + 7),
    ]) {
      appleTrees['apple_tree_${p.x}_${p.y}'] = Offset(p.x.toDouble(), p.y.toDouble());
    }

    final tomY = vy + 3;
    npcs = [
      Npc.create(Npc.elderId, Offset(vx - 2.0, vy - 2.0)),
      Npc.create(Npc.miraId, Offset(vx + 4.0, vy - 2.0)),
      Npc.create(Npc.tomId, Offset(_riverWest[tomY] - 1.0, tomY.toDouble())),
    ];

    // Right outside the player's front door.
    playerSpawn = Offset(vx - 3.0, vy - 2.0);
  }

  void _buildHouse(int x0, int y0, int x1, int y1, Point<int> door) {
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final wall = y == y0 || y == y1 || x == x0 || x == x1;
        tiles[y][x] = wall ? 'wood_wall' : 'wood_floor';
      }
    }
    tiles[door.y][door.x] = 'wood_floor';
  }

  void _generateCaves() {
    // Caves open where a rock face meets walkable ground below it.
    final candidates = <Point<int>>{
      for (final p in _mountainEdge)
        if (tiles[p.y][p.x] == 'dirt' && _inBounds(p.x, p.y - 1) && tiles[p.y - 1][p.x] == 'stone')
          Point(p.x, p.y - 1),
    }.toList()
      ..shuffle(random);
    for (final c in candidates.take(1 + random.nextInt(2))) {
      caveEntrances.add(Offset(c.x.toDouble(), c.y.toDouble()));
    }
  }

  void _generateTrees() {
    for (int i = 0; i < 1400; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      final tile = tiles[y][x];
      final chance = tile == 'forest_grass'
          ? 0.45
          : tile == 'grass'
              ? 0.06
              : 0.0;
      if (_reserved[y][x] || random.nextDouble() >= chance) continue;
      trees['tree_${x}_$y'] = Offset(x.toDouble(), y.toDouble());
    }
  }

  void _generateRocks() {
    // Rocks gather around the hills east of the river.
    final edge = _mountainEdge.toSet().toList()..shuffle(random);
    for (final p in edge.take(70)) {
      if (random.nextDouble() < 0.5) _placeRock(p.x, p.y);
    }
    // A few loose boulders elsewhere on the east bank.
    for (int i = 0; i < 40; i++) {
      final y = random.nextInt(height);
      final x = _riverEast[y] + 2 + random.nextInt(max(1, width - _riverEast[y] - 2));
      _placeRock(x, y);
    }
  }

  void _placeRock(int x, int y) {
    if (!_inBounds(x, y) || x <= _riverEast[y] || _reserved[y][x] || !_isNaturalGround(x, y) || _occupied(x, y)) {
      return;
    }
    rocks['rock_${x}_$y'] = Offset(x.toDouble(), y.toDouble());
  }

  void _generatePlants() {
    for (int i = 0; i < 500; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      if (_reserved[y][x] || !_isNaturalGround(x, y) || _occupied(x, y)) continue;

      final r = random.nextDouble();
      final type = r < 0.35
          ? 'berry_bush'
          : r < 0.65
              ? 'flower'
              : 'grass_tall';
      plants['${type}_${x}_$y'] = Offset(x.toDouble(), y.toDouble());
    }
  }

  void _generateAnimals() {
    for (int i = 0; i < 60; i++) {
      int x = random.nextInt(width);
      int y = random.nextInt(height);
      if (_reserved[y][x] || !_isNaturalGround(x, y) || _occupied(x, y)) continue;

      final r = random.nextDouble();
      final type = r < 0.45
          ? 'rabbit'
          : r < 0.75
              ? 'deer'
              : 'bird';
      animals['${type}_${x}_$y'] = Offset(x.toDouble(), y.toDouble());
    }
  }

  bool _isPlayable() {
    final start = Point(playerSpawn.dx.toInt(), playerSpawn.dy.toInt());
    final westBank = reachableTiles(start);
    final withBridge = reachableTiles(start, cleared: true);
    bool reachable(Set<Point<int>> area, Offset o) => area.contains(Point(o.dx.toInt(), o.dy.toInt()));

    final treesNearVillage = trees.values.where((t) => reachable(westBank, t)).length;
    final rocksAcrossRiver = rocks.values.where((r) => reachable(withBridge, r)).length;
    return treesNearVillage >= 15 && rocksAcrossRiver >= 12;
  }

  /// Makes sure the first cave is one the player can walk up to, as it leads
  /// into the old mine. If no cave can be reached, a new one opens in the
  /// rock face closest to the bridge.
  void _ensureMineEntrance() {
    final reachable = reachableTiles(spawnTile, cleared: true);
    final open = caveEntrances.where((c) => reachable.contains(Point(c.dx.toInt(), c.dy.toInt() + 1)));
    if (open.isNotEmpty) {
      final entrance = open.first;
      caveEntrances = [entrance, ...caveEntrances.where((c) => c != entrance)];
      _clearMineApproach();
      return;
    }
    final landing = bridgeTiles.isEmpty
        ? playerSpawn
        : Offset(bridgeTiles.map((p) => p.x).reduce(max) + 1.0, bridgeTiles.first.y.toDouble());
    Point<int>? best;
    var bestDistance = double.infinity;
    for (final p in reachable) {
      if (getTileAt(p.x, p.y - 1) != 'stone') continue;
      final d = (Offset(p.x.toDouble(), p.y.toDouble()) - landing).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = Point(p.x, p.y - 1);
      }
    }
    if (best != null) caveEntrances.insert(0, Offset(best.x.toDouble(), best.y.toDouble()));
    _clearMineApproach();
  }

  /// Clears the spot in front of the mine, so nothing else is in the way
  /// of going in.
  void _clearMineApproach() {
    final entrance = mineEntrance;
    if (entrance == null) return;
    final spot = entrance + const Offset(0, 1);
    for (final objects in [trees, rocks, plants, animals]) {
      objects.removeWhere((_, o) => o == spot);
    }
  }

  bool _inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  double _dist(int x, int y, int cx, int cy) => sqrt(pow(x - cx, 2) + pow(y - cy, 2));

  void _fill(int x0, int y0, int x1, int y1, String type) {
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        if (_inBounds(x, y)) tiles[y][x] = type;
      }
    }
  }

  void _reserve(int x0, int y0, int x1, int y1) {
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        if (_inBounds(x, y)) _reserved[y][x] = true;
      }
    }
  }

  bool _isNaturalGround(int x, int y) {
    final tile = tiles[y][x];
    return tile == 'grass' || tile == 'forest_grass' || tile == 'dirt' || tile == 'sand';
  }

  bool _occupied(int x, int y) =>
      trees.containsKey('tree_${x}_$y') ||
      rocks.containsKey('rock_${x}_$y') ||
      plants.values.contains(Offset(x.toDouble(), y.toDouble()));

  // ---------------------------------------------------------------------------
  // Queries

  @override
  Set<String> get walkableTiles => _walkableTiles;

  @override
  Iterable<Point<int>> get solidTiles => [
        for (final n in npcs) Level.tileOf(n.position),
        for (final f in [firePit, bed, ...campfires]) Level.tileOf(f),
        // Standing or in ruins, the forge is in the way.
        ...forgeTiles,
      ];

  Point<int> get spawnTile => Point(playerSpawn.dx.toInt(), playerSpawn.dy.toInt());

  /// Anything connected to the elder counts as part of the village.
  @override
  List<Point<int>> get homeTiles {
    final elder = npc(Npc.elderId);
    return elder == null ? [spawnTile] : Level.around(elder.position);
  }

  @override
  Set<Point<int>> get clearableTiles => bridgeBuilt ? const <Point<int>>{} : bridgeTiles.toSet();

  bool isBridgeSite(int x, int y) => !bridgeBuilt && bridgeTiles.contains(Point(x, y));

  bool hasFruit(String key) => !regrowTimers.containsKey(key);

  static const Set<String> _campfireGround = {'grass', 'forest_grass', 'dirt', 'sand', 'path'};

  @override
  bool isCampfireGround(int x, int y) {
    final o = Offset(x.toDouble(), y.toDouble());
    return _campfireGround.contains(getTileAt(x, y)) &&
        Point(x, y) != spawnTile &&
        o != minerHome &&
        !trees.containsValue(o) &&
        !rocks.containsValue(o) &&
        !plants.containsValue(o) &&
        !appleTrees.containsValue(o);
  }

  /// The spawn point, a spot next to each villager, the bed, the fire pit
  /// and the forge, Bram's place beside it, the farm field, both ends of the
  /// bridge and the way into the mine.
  @override
  List<List<Point<int>>> essentialPlaces() {
    final rows = {for (final p in bridgeTiles) p.y};
    List<Point<int>> bridgeEnd({required bool east}) => [
          for (final y in rows)
            east
                ? Point(bridgeTiles.where((p) => p.y == y).map((p) => p.x).reduce(max) + 1, y)
                : Point(bridgeTiles.where((p) => p.y == y).map((p) => p.x).reduce(min) - 1, y),
        ];
    final entrance = mineEntrance;

    return [
      [spawnTile],
      for (final npc in npcs) Level.around(npc.position),
      Level.around(bed),
      Level.around(firePit),
      [for (final t in forgeTiles) ...Level.neighbours(t)],
      Level.around(minerHome),
      [
        for (int y = farmArea.top.toInt(); y < farmArea.bottom; y++)
          for (int x = farmArea.left.toInt(); x < farmArea.right; x++) Point(x, y),
      ],
      if (rows.isNotEmpty) bridgeEnd(east: false),
      if (rows.isNotEmpty) bridgeEnd(east: true),
      if (entrance != null) [Point(entrance.dx.toInt(), entrance.dy.toInt() + 1)],
    ];
  }

  // ---------------------------------------------------------------------------
  // Changes

  void buildBridge() {
    bridgeBuilt = true;
    for (final p in bridgeTiles) {
      tiles[p.y][p.x] = 'bridge';
    }
  }

  void buildFirePit() {
    firePitBuilt = true;
    refreshSolid();
  }

  /// Takes away the campfires an older save may have where the forge or
  /// Bram belong, and returns how many there were.
  int clearStoryGround() {
    final before = campfires.length;
    campfires.removeWhere((c) => forgeTiles.contains(Level.tileOf(c)) || c == minerHome);
    refreshSolid();
    return before - campfires.length;
  }

  void buildForge() {
    forgeBuilt = true;
    refreshSolid();
  }

  void unlockFarm() {
    farmUnlocked = true;
    for (int y = farmArea.top.toInt(); y < farmArea.bottom; y++) {
      for (int x = farmArea.left.toInt(); x < farmArea.right; x++) {
        tiles[y][x] = 'farmland';
      }
    }
  }

  void pickFruit(String key) {
    regrowTimers[key] = regrowHours;
  }

  /// Advances the clock by [dt] real seconds; a full day lasts ten minutes.
  void updateTime(double dt) {
    advanceHours(dt * 24 / secondsPerDay);
  }

  /// Advances the clock by in-game [hours], growing crops and fruit.
  void advanceHours(double hours) {
    timeOfDay += hours;
    while (timeOfDay >= 24.0) {
      timeOfDay -= 24.0;
      day++;
    }
    isDay = timeOfDay >= 6.0 && timeOfDay < 18.0;

    for (final crop in crops.values) {
      crop.advance(hours);
    }
    regrowTimers.updateAll((_, h) => h - hours);
    regrowTimers.removeWhere((_, h) => h <= 0);
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

  /// 1.0 in full daylight (6-18), fading through dawn (4-6) and dusk (18-20).
  @override
  double getLightLevel() {
    const night = 0.15;
    final t = timeOfDay;
    if (t >= 6 && t <= 18) return 1.0;
    if (t > 4 && t < 6) return night + (t - 4) / 2 * (1 - night);
    if (t > 18 && t < 20) return 1.0 - (t - 18) / 2 * (1 - night);
    return night;
  }

  // ---------------------------------------------------------------------------
  // Saving

  static const Map<String, String> _tileCodes = {
    'grass': 'g',
    'dirt': 'd',
    'sand': 's',
    'stone': 'S',
    'water': 'w',
    'forest_grass': 'f',
    'wood_floor': 'F',
    'wood_wall': 'W',
    'path': 'p',
    'bridge': 'b',
    'farmland': 'l',
    'fence': 'e',
  };

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'seed': seed,
        'time': timeOfDay,
        'day': day,
        'tiles': Level.tilesToJson(tiles, _tileCodes),
        'trees': trees.keys.toList(),
        'rocks': rocks.keys.toList(),
        'plants': plants.keys.toList(),
        'animals': animals.keys.toList(),
        'appleTrees': appleTrees.keys.toList(),
        'regrow': regrowTimers,
        'caves': [for (final c in caveEntrances) Level.pointToJson(c)],
        'mineOpen': mineOpen,
        'village': Level.pointToJson(villageCenter),
        'spawn': Level.pointToJson(playerSpawn),
        'bed': Level.pointToJson(bed),
        'firePit': Level.pointToJson(firePit),
        'firePitBuilt': firePitBuilt,
        'forgeBuilt': forgeBuilt,
        'campfires': [for (final c in campfires) Level.pointToJson(c)],
        'bridge': Level.tilesListToJson(bridgeTiles),
        'bridgeBuilt': bridgeBuilt,
        'farm': [farmArea.left, farmArea.top, farmArea.width, farmArea.height],
        'farmUnlocked': farmUnlocked,
        'crops': {for (final e in crops.entries) e.key: e.value.toJson()},
        'npcs': {for (final n in npcs) n.id: Level.pointToJson(n.position)},
      };

  factory World.fromJson(Map<String, dynamic> json) {
    final world = World(
      width: json['width'] as int,
      height: json['height'] as int,
      seed: json['seed'] as int,
    );
    world.tiles = Level.tilesFromJson(json['tiles'], _tileCodes);
    world.timeOfDay = (json['time'] as num).toDouble();
    world.day = json['day'] as int;
    world.isDay = world.timeOfDay >= 6.0 && world.timeOfDay < 18.0;
    world.trees = Level.objectsFromJson(json['trees']);
    world.rocks = Level.objectsFromJson(json['rocks']);
    world.plants = Level.objectsFromJson(json['plants']);
    world.animals = Level.objectsFromJson(json['animals']);
    world.appleTrees = Level.objectsFromJson(json['appleTrees']);
    world.regrowTimers = {
      for (final e in (json['regrow'] as Map).entries) e.key as String: (e.value as num).toDouble(),
    };
    world.caveEntrances = [for (final c in json['caves'] as List) Level.pointFromJson(c)];
    // Saves from before chapter 2 have no mine or forge yet.
    world.mineOpen = json['mineOpen'] as bool? ?? false;
    world.villageLocations = [Level.pointFromJson(json['village'])];
    world.playerSpawn = Level.pointFromJson(json['spawn']);
    world.bed = Level.pointFromJson(json['bed']);
    world.firePit = Level.pointFromJson(json['firePit']);
    world.firePitBuilt = json['firePitBuilt'] as bool;
    world.forgeBuilt = json['forgeBuilt'] as bool? ?? false;
    world.campfires = [for (final c in json['campfires'] as List) Level.pointFromJson(c)];
    world.bridgeTiles = Level.tilesListFromJson(json['bridge']);
    world.bridgeBuilt = json['bridgeBuilt'] as bool;
    final farm = (json['farm'] as List).map((v) => (v as num).toDouble()).toList();
    world.farmArea = Rect.fromLTWH(farm[0], farm[1], farm[2], farm[3]);
    world.farmUnlocked = json['farmUnlocked'] as bool;
    world.crops = {
      for (final e in (json['crops'] as Map).entries) e.key as String: Crop.fromJson(e.value as List),
    };
    world.npcs = [
      for (final e in (json['npcs'] as Map).entries) Npc.create(e.key as String, Level.pointFromJson(e.value)),
    ];
    world.refreshSolid();
    world._ensureMineEntrance();
    return world;
  }
}
