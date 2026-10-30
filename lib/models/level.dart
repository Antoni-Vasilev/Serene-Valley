import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import 'npc.dart';

/// A stable pseudo-random value in 0..1 for a tile.
double tileHash(int x, int y) => (((x * 73856093) ^ (y * 19349663)) & 0xFF) / 255.0;

/// A map the player can walk around in: the valley, or the old mine under it.
abstract class Level {
  final int width;
  final int height;
  final int seed;
  late final Random random = Random(seed);

  // Terrain, one tile type per cell.
  List<List<String>> tiles = [];
  // Rocks keyed '<type>_<x>_<y>', positioned at their tile's top-left corner.
  Map<String, Offset> rocks = {};
  List<Npc> npcs = [];
  List<Offset> campfires = [];

  // Tiles blocked by things standing on them.
  Set<Point<int>> _solid = {};

  Level({required this.width, required this.height, int? seed}) : seed = seed ?? Random().nextInt(1 << 31);

  /// Tile types that can be walked on.
  Set<String> get walkableTiles;

  /// Tiles blocked by things standing on them, such as villagers and fires.
  Iterable<Point<int>> get solidTiles;

  /// Fires that are burning.
  List<Offset> get fires;

  /// Where the way home starts: beside the elder in the valley, and at the
  /// foot of the ladder in the mine.
  List<Point<int>> get homeTiles;

  /// Tiles that are blocked for now but open up later in the story, like the
  /// broken bridge.
  Set<Point<int>> get clearableTiles => const <Point<int>>{};

  /// Groups of tiles of which at least one must always stay reachable.
  List<List<Point<int>>> essentialPlaces();

  /// Whether the ground on (x, y) could hold a campfire at all.
  bool isCampfireGround(int x, int y);

  /// How bright it is, from 0 (pitch dark) to 1 (full daylight).
  double getLightLevel();

  Npc? npc(String id) => npcs.where((n) => n.id == id).firstOrNull;

  String getTileAt(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      return tiles[y][x];
    }
    return 'void';
  }

  bool isWalkable(int x, int y) => walkableTiles.contains(getTileAt(x, y)) && !_solid.contains(Point(x, y));

  void refreshSolid() {
    _solid = solidTiles.toSet();
  }

  /// Tiles reachable on foot from [start]. With [cleared], everything that
  /// opens up later counts as open already; [blocked] tiles count as solid.
  Set<Point<int>> reachableTiles(
    Point<int> start, {
    bool cleared = false,
    Set<Point<int>> blocked = const {},
  }) {
    final later = cleared ? clearableTiles : const <Point<int>>{};
    bool open(Point<int> p) => (isWalkable(p.x, p.y) || later.contains(p)) && !blocked.contains(p);

    final seen = <Point<int>>{};
    if (!open(start)) return seen;
    final queue = Queue<Point<int>>()..add(start);
    seen.add(start);
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      for (final n in neighbours(p)) {
        if (!seen.contains(n) && open(n)) {
          seen.add(n);
          queue.add(n);
        }
      }
    }
    return seen;
  }

  /// The tile closest to [origin] from which the way home can be walked, so
  /// whoever is placed there can never end up sealed in.
  Offset nearestReachableTile(Offset origin) {
    final reachable = <Point<int>>{};
    for (final home in homeTiles) {
      if (!reachable.contains(home)) reachable.addAll(reachableTiles(home));
    }
    if (reachable.isEmpty) return findWalkableNear(origin);
    final best = reachable.reduce((a, b) {
      final da = (Offset(a.x + 0.5, a.y + 0.5) - origin).distanceSquared;
      final db = (Offset(b.x + 0.5, b.y + 0.5) - origin).distanceSquared;
      return da <= db ? a : b;
    });
    return Offset(best.x.toDouble(), best.y.toDouble());
  }

  /// Returns the walkable tile closest to [origin], searching outward in rings.
  Offset findWalkableNear(Offset origin) {
    final ox = origin.dx.floor().clamp(0, width - 1);
    final oy = origin.dy.floor().clamp(0, height - 1);
    for (int r = 0; r < max(width, height); r++) {
      for (int y = oy - r; y <= oy + r; y++) {
        for (int x = ox - r; x <= ox + r; x++) {
          final onRing = (x - ox).abs() == r || (y - oy).abs() == r;
          if (onRing && isWalkable(x, y)) {
            return Offset(x.toDouble(), y.toDouble());
          }
        }
      }
    }
    return Offset(ox.toDouble(), oy.toDouble());
  }

  /// Whether a player standing on [from] may place a campfire on (x, y).
  /// Fires are solid, so one may never cut off a place the story needs. A
  /// place that is out of reach already, say walled in by older fires,
  /// doesn't stop a fire somewhere else.
  bool canPlaceCampfire(int x, int y, {required Point<int> from}) {
    if (!isWalkable(x, y) || !isCampfireGround(x, y)) return false;
    final before = reachableTiles(from, cleared: true);
    final after = reachableTiles(from, cleared: true, blocked: {Point(x, y)});
    return essentialPlaces().every((place) => !place.any(before.contains) || place.any(after.contains));
  }

  void placeCampfire(int x, int y) {
    campfires.add(Offset(x.toDouble(), y.toDouble()));
    refreshSolid();
  }

  /// The four tiles beside [p].
  static List<Point<int>> neighbours(Point<int> p) => [
        Point(p.x + 1, p.y),
        Point(p.x - 1, p.y),
        Point(p.x, p.y + 1),
        Point(p.x, p.y - 1),
      ];

  /// The four tiles beside the one at [o].
  static List<Point<int>> around(Offset o) => neighbours(tileOf(o));

  static Point<int> tileOf(Offset o) => Point(o.dx.toInt(), o.dy.toInt());

  // ---------------------------------------------------------------------------
  // Saving

  /// Tile rows as strings, one character per tile.
  static List<String> tilesToJson(List<List<String>> tiles, Map<String, String> codes) => [
        for (final row in tiles) row.map((t) => codes[t] ?? codes.values.first).join(),
      ];

  static List<List<String>> tilesFromJson(dynamic rows, Map<String, String> codes) {
    final types = {for (final e in codes.entries) e.value: e.key};
    return [
      for (final row in rows as List) [for (final code in (row as String).split('')) types[code] ?? codes.keys.first],
    ];
  }

  static List<double> pointToJson(Offset o) => [o.dx, o.dy];

  static Offset pointFromJson(dynamic json) {
    final list = json as List;
    return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
  }

  static List<List<int>> tilesListToJson(Iterable<Point<int>> points) => [
        for (final p in points) [p.x, p.y],
      ];

  static List<Point<int>> tilesListFromJson(dynamic json) => [
        for (final p in json as List) Point((p as List)[0] as int, p[1] as int),
      ];

  /// Objects saved by their keys, which say where they are.
  static Map<String, Offset> objectsFromJson(dynamic keys) => {
        for (final key in (keys as List).cast<String>()) key: positionOfKey(key),
      };

  static Offset positionOfKey(String key) {
    final parts = key.split('_');
    return Offset(double.parse(parts[parts.length - 2]), double.parse(parts.last));
  }
}
