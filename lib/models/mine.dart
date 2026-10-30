import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import 'level.dart';
import 'npc.dart';

/// The old mine under the eastern hills: caverns and tunnels in three parts,
/// one below the other. A cobweb closes the shaft down to the middle part,
/// and fallen rocks the one down to the deepest part, where Bram is trapped.
class Mine extends Level {
  static const Set<String> _walkable = {'cave_floor'};
  static const Map<String, String> _tileCodes = {'cave_wall': '#', 'cave_floor': '.', 'water': 'w'};

  /// The first and last row of each part of the mine, from the top down.
  /// Solid rock lies between them, crossed by a single narrow shaft.
  static const List<(int, int)> parts = [(2, 19), (23, 41), (45, 61)];

  // The ladder up to the valley, on the rock face above [arrival].
  Point<int> ladder = const Point(0, 0);
  // The middle of each shaft between two parts.
  List<Point<int>> passages = [];
  // What blocks the shafts, keyed '<type>_<x>_<y>'.
  Map<String, Offset> webs = {};
  Map<String, Offset> rubble = {};
  // Glowing mushrooms, and the timber frames propping up narrow tunnels.
  Map<String, Offset> mushrooms = {};
  Map<String, Offset> frames = {};
  // Old rails, and the cart left standing on them.
  Set<Point<int>> rails = {};
  Offset? cart;
  // Tiles the player has seen, for the map.
  List<List<bool>> explored = [];

  Mine({super.width = 48, super.height = 64, super.seed});

  /// Where someone climbing down the ladder arrives.
  Point<int> get arrival => Point(ladder.x, ladder.y + 1);

  @override
  Set<String> get walkableTiles => _walkable;

  @override
  Iterable<Point<int>> get solidTiles => [
        for (final n in npcs) Level.tileOf(n.position),
        for (final c in campfires) Level.tileOf(c),
        for (final w in webs.values) Level.tileOf(w),
        for (final r in rubble.values) Level.tileOf(r),
      ];

  @override
  List<Offset> get fires => campfires;

  @override
  List<Point<int>> get homeTiles => [arrival];

  @override
  Set<Point<int>> get clearableTiles => {
        for (final o in [...webs.values, ...rubble.values]) Level.tileOf(o),
      };

  /// The foot of the ladder, a spot next to Bram while he is down here, and
  /// both shafts, so no part of the mine can be sealed off.
  @override
  List<List<Point<int>>> essentialPlaces() => [
        [arrival],
        for (final npc in npcs) Level.around(npc.position),
        for (final p in passages) [p],
      ];

  @override
  bool isCampfireGround(int x, int y) {
    final o = Offset(x.toDouble(), y.toDouble());
    return getTileAt(x, y) == 'cave_floor' &&
        Point(x, y) != arrival &&
        !rails.contains(Point(x, y)) &&
        !rocks.containsValue(o) &&
        !mushrooms.containsValue(o) &&
        !frames.containsValue(o) &&
        cart != o;
  }

  /// Only what the player brings lights the mine.
  @override
  double getLightLevel() => 0;

  /// Marks the tiles within [radius] of [centre] as seen.
  void explore(Offset centre, double radius) {
    final r = radius.ceil();
    final cx = centre.dx.floor();
    final cy = centre.dy.floor();
    for (var y = cy - r; y <= cy + r; y++) {
      for (var x = cx - r; x <= cx + r; x++) {
        if (!_inBounds(x, y)) continue;
        final dx = x + 0.5 - centre.dx;
        final dy = y + 0.5 - centre.dy;
        if (dx * dx + dy * dy <= radius * radius) explored[y][x] = true;
      }
    }
  }

  bool isExplored(int x, int y) => _inBounds(x, y) && explored[y][x];

  // ---------------------------------------------------------------------------
  // Generation

  void generate() {
    // Retry until the layout is playable; the seeded Random keeps this
    // deterministic for a given seed.
    for (var attempt = 0; attempt < 30; attempt++) {
      _generateOnce();
      if (_isPlayable()) return;
    }
  }

  void _generateOnce() {
    tiles = List.generate(height, (_) => List.filled(width, 'cave_wall'));
    explored = List.generate(height, (_) => List.filled(width, false));
    rocks = {};
    webs = {};
    rubble = {};
    mushrooms = {};
    frames = {};
    rails = {};
    cart = null;
    npcs = [];
    campfires = [];

    final rooms = [for (final part in parts) _carvePart(part)];
    // The middle part is entered on one side and left on the other, so it
    // has to be crossed.
    final middleEntry = rooms[1][random.nextInt(rooms[1].length)];
    final middleExit = rooms[1].reduce((a, b) => (a.x - middleEntry.x).abs() >= (b.x - middleEntry.x).abs() ? a : b);
    final web = _connect(rooms[0][random.nextInt(rooms[0].length)], middleEntry, parts[0], parts[1]);
    final fall = _connect(middleExit, rooms[2][random.nextInt(rooms[2].length)], parts[1], parts[2]);
    passages = [web, fall];
    webs['web_${web.x}_${web.y}'] = _offsetOf(web);
    rubble['rubble_${fall.x}_${fall.y}'] = _offsetOf(fall);

    _placeLadder(rooms[0]);
    _placeLake(rooms[1]);
    refreshSolid();
    _placeMiner(fall);
    _placeRails();
    _placeFrames();
    _placeRocks();
    _placeMushrooms();
    refreshSolid();
  }

  /// Hollows out a few caverns in one part of the mine, joined west to east
  /// by winding tunnels, and returns their centres.
  List<Point<int>> _carvePart((int, int) part) {
    final (top, bottom) = part;
    final count = 4 + random.nextInt(2);
    final band = (width - 10) / count;
    final rooms = [
      for (var i = 0; i < count; i++)
        Point(5 + (band * i + random.nextDouble() * band).floor(), top + 3 + random.nextInt(bottom - top - 5)),
    ];
    for (final room in rooms) {
      _carveCavern(room, 2.2 + random.nextDouble() * 3.0, 1.8 + random.nextDouble() * 1.8, part);
    }
    for (var i = 0; i + 1 < rooms.length; i++) {
      _carveTunnel(rooms[i], rooms[i + 1], part);
    }
    _roughen(part);
    return rooms;
  }

  void _carveCavern(Point<int> centre, double rx, double ry, (int, int) part) {
    for (var y = (centre.y - ry - 1).floor(); y <= (centre.y + ry + 1).ceil(); y++) {
      for (var x = (centre.x - rx - 1).floor(); x <= (centre.x + rx + 1).ceil(); x++) {
        final dx = (x - centre.x) / rx;
        final dy = (y - centre.y) / ry;
        if (dx * dx + dy * dy < 1 + (random.nextDouble() - 0.5) * 0.4) _dig(x, y, part);
      }
    }
    _dig(centre.x, centre.y, part);
  }

  /// Digs a winding tunnel from [a] to [b], now and then two tiles wide.
  void _carveTunnel(Point<int> a, Point<int> b, (int, int) part) {
    final (top, bottom) = part;
    var x = a.x;
    var y = a.y;
    for (var step = 0; step < 300 && (x != b.x || y != b.y); step++) {
      _dig(x, y, part);
      if (random.nextDouble() < 0.3) _dig(x + 1, y, part);
      final dx = (b.x - x).sign;
      final dy = (b.y - y).sign;
      final r = random.nextDouble();
      if (r < 0.12) {
        // Wander off course for a step.
        if (dx == 0) {
          x += random.nextBool() ? 1 : -1;
        } else {
          y += random.nextBool() ? 1 : -1;
        }
      } else if (dx != 0 && (dy == 0 || r < 0.6)) {
        x += dx;
      } else {
        y += dy;
      }
      x = x.clamp(2, width - 3);
      y = y.clamp(top, bottom);
    }
    // Finish in a straight line if the walk ran long.
    while (x != b.x) {
      _dig(x, y, part);
      x += (b.x - x).sign;
    }
    while (y != b.y) {
      _dig(x, y, part);
      y += (b.y - y).sign;
    }
    _dig(x, y, part);
  }

  /// Crumbles the walls a little, so caverns don't look cut with a compass.
  /// Only ever adds floor next to floor, so nothing gets cut off.
  void _roughen((int, int) part) {
    final (top, bottom) = part;
    for (var pass = 0; pass < 2; pass++) {
      final before = [for (final row in tiles) List.of(row)];
      for (var y = top; y <= bottom; y++) {
        for (var x = 2; x <= width - 3; x++) {
          if (before[y][x] != 'cave_wall') continue;
          final open = Level.neighbours(Point(x, y)).where((n) => before[n.y][n.x] == 'cave_floor').length;
          if (open >= 3 || random.nextDouble() < 0.12 * open) tiles[y][x] = 'cave_floor';
        }
      }
    }
  }

  void _dig(int x, int y, (int, int) part) {
    if (x < 2 || x > width - 3 || y < part.$1 || y > part.$2) return;
    tiles[y][x] = 'cave_floor';
  }

  /// Joins two parts of the mine by a tunnel down a shaft through the rock
  /// between them, one tile wide, and returns the middle of the shaft.
  Point<int> _connect(Point<int> from, Point<int> to, (int, int) upper, (int, int) lower) {
    final x = ((from.x + to.x) ~/ 2 + random.nextInt(7) - 3).clamp(4, width - 5);
    _carveTunnel(from, Point(x, upper.$2), upper);
    for (var y = upper.$2; y <= lower.$1; y++) {
      tiles[y][x] = 'cave_floor';
    }
    _carveTunnel(Point(x, lower.$1), to, lower);
    return Point(x, (upper.$2 + lower.$1) ~/ 2);
  }

  /// The ladder stands against the rock face above the highest cavern.
  void _placeLadder(List<Point<int>> rooms) {
    final top = rooms.reduce((a, b) => a.y <= b.y ? a : b);
    var y = top.y;
    while (tiles[y - 1][top.x] == 'cave_floor') {
      y--;
    }
    ladder = Point(top.x, y - 1);
  }

  /// Floods part of a cavern in the middle into a still, dark pool.
  void _placeLake(List<Point<int>> rooms) {
    final centre = rooms[random.nextInt(rooms.length)];
    final rx = 1.6 + random.nextDouble() * 1.4;
    final ry = 1.2 + random.nextDouble() * 0.8;
    final flooded = <Point<int>>[];
    for (var y = (centre.y - ry).floor(); y <= (centre.y + ry).ceil(); y++) {
      for (var x = (centre.x - rx).floor(); x <= (centre.x + rx).ceil(); x++) {
        final dx = (x - centre.x) / rx;
        final dy = (y - centre.y) / ry;
        final nearShaft = passages.any((p) => (p.x - x).abs() <= 2 && (p.y - y).abs() <= 3);
        if (dx * dx + dy * dy < 1 && tiles[y][x] == 'cave_floor' && !nearShaft) {
          tiles[y][x] = 'water';
          flooded.add(Point(x, y));
        }
      }
    }
    // Keep the pool only if every tunnel can still be walked.
    if (!_floorConnected()) {
      for (final p in flooded) {
        tiles[p.y][p.x] = 'cave_floor';
      }
    }
  }

  /// Bram waits at the far end of the deepest part, away from the rockfall.
  void _placeMiner(Point<int> fall) {
    final distances = _distancesFrom(Point(fall.x, fall.y + 1));
    Point<int>? best;
    var bestScore = -1;
    for (final MapEntry(key: p, value: d) in distances.entries) {
      // Somewhere roomy, so he doesn't stand in the way.
      final roomy = Level.neighbours(p).every((n) => isWalkable(n.x, n.y));
      final score = d + (roomy ? 1000 : 0);
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    if (best != null) npcs = [Npc.create(Npc.bramId, _offsetOf(best))];
  }

  /// Old rails along the longest straight stretch of the top two parts.
  void _placeRails() {
    for (final (i, part) in parts.take(2).indexed) {
      var bestStart = const Point(0, 0);
      var bestLength = 0;
      for (var y = part.$1; y <= part.$2; y++) {
        var length = 0;
        for (var x = 2; x <= width - 2; x++) {
          if (isWalkable(x, y) && Point(x, y) != arrival) {
            length++;
            continue;
          }
          if (length > bestLength) {
            bestLength = length;
            bestStart = Point(x - length, y);
          }
          length = 0;
        }
      }
      if (bestLength < 5) continue;
      for (var x = bestStart.x + 1; x < bestStart.x + bestLength - 1; x++) {
        rails.add(Point(x, bestStart.y));
      }
      if (i == 0) cart = _offsetOf(Point(bestStart.x + bestLength - 2, bestStart.y));
    }
  }

  /// Timber frames prop up narrow tunnels running north to south.
  void _placeFrames() {
    final spots = <Point<int>>[];
    for (var y = 2; y < height - 2; y++) {
      for (var x = 2; x < width - 2; x++) {
        final p = Point(x, y);
        if (tiles[y][x] != 'cave_floor' || passages.contains(p) || rails.contains(p) || p == arrival) continue;
        if (tiles[y][x - 1] == 'cave_wall' &&
            tiles[y][x + 1] == 'cave_wall' &&
            tiles[y - 1][x] == 'cave_floor' &&
            tiles[y + 1][x] == 'cave_floor') {
          spots.add(p);
        }
      }
    }
    spots.shuffle(random);
    for (final p in spots) {
      if (frames.values.any((f) => (f.dx - p.x).abs() + (f.dy - p.y).abs() < 4)) continue;
      frames['frame_${p.x}_${p.y}'] = _offsetOf(p);
    }
  }

  void _placeRocks() {
    // How many plain rocks, iron ore and crystals each part has.
    const counts = [(10, 9, 0), (8, 7, 5), (6, 5, 7)];
    for (final (i, part) in parts.indexed) {
      final spots = _freeSpots(part)..shuffle(random);
      // Ore and crystals grow out of the walls.
      final byWall = spots.where((p) => _wallsAround(p) > 0).toList();
      final (stone, iron, crystal) = counts[i];
      _scatter(byWall, 'iron', iron);
      _scatter(byWall, 'crystal', crystal);
      _scatter(spots, 'rock', stone);
    }
  }

  void _scatter(List<Point<int>> spots, String type, int count) {
    var placed = 0;
    for (final p in spots) {
      if (placed == count) return;
      if (rocks.containsValue(_offsetOf(p))) continue;
      rocks['${type}_${p.x}_${p.y}'] = _offsetOf(p);
      placed++;
    }
  }

  void _placeMushrooms() {
    for (final part in parts) {
      final spots = _freeSpots(part).where((p) => _wallsAround(p) >= 2 && !rocks.containsValue(_offsetOf(p))).toList()
        ..shuffle(random);
      for (final p in spots.take(7)) {
        mushrooms['mushroom_${p.x}_${p.y}'] = _offsetOf(p);
      }
    }
  }

  /// Open floor in [part] with nothing on it, away from the ladder, the
  /// shafts and Bram, so nothing gets in the way there.
  List<Point<int>> _freeSpots((int, int) part) {
    final keepClear = <Point<int>>{
      arrival,
      ...Level.neighbours(arrival),
      for (final p in passages) ...[p, ...Level.neighbours(p)],
      for (final n in npcs) ...[Level.tileOf(n.position), ...Level.around(n.position)],
      ...rails,
      for (final f in frames.values) Level.tileOf(f),
      if (cart case final cart?) Level.tileOf(cart),
    };
    return [
      for (var y = part.$1; y <= part.$2; y++)
        for (var x = 2; x < width - 2; x++)
          if (isWalkable(x, y) && !keepClear.contains(Point(x, y))) Point(x, y),
    ];
  }

  int _wallsAround(Point<int> p) => Level.neighbours(p).where((n) => tiles[n.y][n.x] == 'cave_wall').length;

  /// Steps from [start] to every tile that can be walked to.
  Map<Point<int>, int> _distancesFrom(Point<int> start) {
    final distances = {start: 0};
    final queue = Queue<Point<int>>()..add(start);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      for (final n in Level.neighbours(p)) {
        if (!distances.containsKey(n) && isWalkable(n.x, n.y)) {
          distances[n] = distances[p]! + 1;
          queue.add(n);
        }
      }
    }
    return distances;
  }

  /// Whether all the floor is one connected network of tunnels.
  bool _floorConnected() {
    final floor = [
      for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
          if (tiles[y][x] == 'cave_floor') Point(x, y),
    ];
    if (floor.isEmpty) return false;
    final seen = {floor.first};
    final queue = Queue<Point<int>>()..add(floor.first);
    while (queue.isNotEmpty) {
      for (final n in Level.neighbours(queue.removeFirst())) {
        if (getTileAt(n.x, n.y) == 'cave_floor' && seen.add(n)) queue.add(n);
      }
    }
    return seen.length == floor.length;
  }

  bool _isPlayable() {
    final bram = npc(Npc.bramId);
    if (bram == null || !isWalkable(arrival.x, arrival.y)) return false;
    final open = reachableTiles(arrival);
    final all = reachableTiles(arrival, cleared: true);
    // Once the way is cleared, everywhere can be walked to.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (isWalkable(x, y) && !all.contains(Point(x, y))) return false;
      }
    }
    final ironNearby = rocks.entries.where((e) => e.key.startsWith('iron') && open.contains(Level.tileOf(e.value)));
    return ironNearby.length >= 6 &&
        !Level.around(bram.position).any(open.contains) &&
        Level.around(bram.position).any(all.contains);
  }

  bool _inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  static Offset _offsetOf(Point<int> p) => Offset(p.x.toDouble(), p.y.toDouble());

  // ---------------------------------------------------------------------------
  // Saving

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'seed': seed,
        'tiles': Level.tilesToJson(tiles, _tileCodes),
        'ladder': [ladder.x, ladder.y],
        'passages': Level.tilesListToJson(passages),
        'rocks': rocks.keys.toList(),
        'webs': webs.keys.toList(),
        'rubble': rubble.keys.toList(),
        'mushrooms': mushrooms.keys.toList(),
        'frames': frames.keys.toList(),
        'rails': Level.tilesListToJson(rails),
        'cart': cart == null ? null : Level.pointToJson(cart!),
        'campfires': [for (final c in campfires) Level.pointToJson(c)],
        'npcs': {for (final n in npcs) n.id: Level.pointToJson(n.position)},
        'explored': [for (final row in explored) row.map((seen) => seen ? '1' : '0').join()],
      };

  factory Mine.fromJson(Map<String, dynamic> json) {
    final mine = Mine(width: json['width'] as int, height: json['height'] as int, seed: json['seed'] as int);
    mine.tiles = Level.tilesFromJson(json['tiles'], _tileCodes);
    final ladder = json['ladder'] as List;
    mine.ladder = Point(ladder[0] as int, ladder[1] as int);
    mine.passages = Level.tilesListFromJson(json['passages']);
    mine.rocks = Level.objectsFromJson(json['rocks']);
    mine.webs = Level.objectsFromJson(json['webs']);
    mine.rubble = Level.objectsFromJson(json['rubble']);
    mine.mushrooms = Level.objectsFromJson(json['mushrooms']);
    mine.frames = Level.objectsFromJson(json['frames']);
    mine.rails = Level.tilesListFromJson(json['rails']).toSet();
    final cart = json['cart'];
    mine.cart = cart == null ? null : Level.pointFromJson(cart);
    mine.campfires = [for (final c in json['campfires'] as List) Level.pointFromJson(c)];
    mine.npcs = [
      for (final e in (json['npcs'] as Map).entries) Npc.create(e.key as String, Level.pointFromJson(e.value)),
    ];
    mine.explored = [
      for (final row in json['explored'] as List) [for (final c in (row as String).split('')) c == '1'],
    ];
    mine.refreshSolid();
    return mine;
  }
}
