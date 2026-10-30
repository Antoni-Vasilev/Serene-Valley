import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../graphics/textures.dart';
import '../graphics/ui_textures.dart';
import '../models/game_state.dart';
import '../models/level.dart';
import '../models/mine.dart';
import '../models/npc.dart';
import 'pixel_ui.dart';
import 'tile_widget.dart';

/// Renders the visible part of the world, its objects and the player onto a
/// single canvas. Repaints whenever [gameState] notifies.
class WorldWidget extends StatelessWidget {
  final GameState gameState;
  final double tileSize;
  // Screen areas covered by the HUD, kept clear for the quest arrow.
  final EdgeInsets hudInsets;

  const WorldWidget({
    super.key,
    required this.gameState,
    required this.tileSize,
    this.hudInsets = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: WorldPainter(
          gameState: gameState,
          tileSize: tileSize,
          hudInsets: hudInsets,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
      ),
    );
  }
}

/// A light in the dark: it clears the darkness within [radius] tiles of
/// [centre], and may tint its surroundings with a [glow].
class _Light {
  final Offset centre;
  final double radius;
  final double strength;
  final Color? glow;
  final double glowRadius;
  final double glowStrength;
  // Held lights shine at full strength out to half their radius.
  final bool steady;

  const _Light(
    this.centre,
    this.radius,
    this.strength, {
    this.glow,
    this.glowRadius = 0,
    this.glowStrength = 0,
    this.steady = false,
  });
}

class WorldPainter extends CustomPainter {
  final GameState gameState;
  final double tileSize;
  final EdgeInsets hudInsets;
  final double devicePixelRatio;

  final Paint _paint = Paint();
  final Paint _pixels = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  // Device pixels per tile, used to snap sprites to whole pixels.
  double _unit = 16;

  WorldPainter({
    required this.gameState,
    required this.tileSize,
    this.hudInsets = EdgeInsets.zero,
    this.devicePixelRatio = 1,
  }) : super(repaint: gameState);

  static const _sides = [Point(0, -1), Point(1, 0), Point(0, 1), Point(-1, 0)];
  static const _fireGlow = Color(0xFFFF9800);

  @override
  void paint(Canvas canvas, Size size) {
    final textures = Textures.instance;
    final level = gameState.level;
    final mine = gameState.underground ? gameState.mine : null;
    final camera = gameState.cameraOffset;
    final clock = gameState.clock;

    // Scale so every texture pixel covers a whole number of device pixels,
    // and keep the camera on the device pixel grid, so the art stays crisp.
    final texel = max(1, (tileSize * gameState.cameraZoom * devicePixelRatio / 16).round());
    final px = texel * 16 / devicePixelRatio;
    _unit = texel * 16.0;
    final tx = ((size.width / 2 - camera.dx * px) * devicePixelRatio).roundToDouble() / devicePixelRatio;
    final ty = ((size.height / 2 - camera.dy * px) * devicePixelRatio).roundToDouble() / devicePixelRatio;
    Offset toScreen(Offset tile) => Offset(tx + tile.dx * px, ty + tile.dy * px);

    // Area outside the world.
    _paint.color = mine != null ? const Color(0xFF070606) : const Color(0xFF1a1a2e);
    canvas.drawRect(Offset.zero & size, _paint);

    // Visible tiles, with a margin for trees and roofs that reach over.
    final minX = max(0, (-tx / px).floor() - 1);
    final minY = max(0, (-ty / px).floor() - 1);
    final maxX = min(level.width - 1, ((size.width - tx) / px).ceil() + 1);
    final maxY = min(level.height - 1, ((size.height - ty) / px).ceil() + 2);
    bool visible(Offset p) => p.dx >= minX - 1 && p.dx <= maxX + 1 && p.dy >= minY - 1 && p.dy <= maxY + 2;

    canvas.save();
    // From here on, one unit equals one tile.
    canvas.translate(tx, ty);
    canvas.scale(px);

    if (mine != null) {
      _drawMineTerrain(canvas, textures, mine, minX, minY, maxX, maxY, clock);
      _drawMineGround(canvas, textures, mine, visible);
      _drawMineStanding(canvas, textures, mine, visible, clock);
    } else {
      _drawTerrain(canvas, textures, minX, minY, maxX, maxY, clock);
      _drawGround(canvas, textures, visible);
      _drawStanding(canvas, textures, visible, clock, minX, minY, maxX, maxY);
    }
    _drawHighlight(canvas, textures, clock);

    canvas.restore();

    _drawDarkness(canvas, size, px, toScreen, clock);
    _drawNames(canvas, toScreen);
    _drawQuestMarker(canvas, px, toScreen, clock);
    _drawFloatingTexts(canvas, toScreen);
    _drawQuestArrow(canvas, size, toScreen);
  }

  /// Draws [image] (16 pixels per tile) with its top-left corner at (x, y).
  void _image(Canvas canvas, ui.Image image, double x, double y, {double opacity = 1}) {
    final paint = opacity >= 1
        ? _pixels
        : (Paint()
          ..filterQuality = FilterQuality.none
          ..color = Color.fromRGBO(0, 0, 0, opacity));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(_snap(x), _snap(y), image.width / 16, image.height / 16),
      paint,
    );
  }

  /// Draws [image] standing on the bottom edge of tile (x, y), centred.
  void _standing(Canvas canvas, ui.Image image, double x, double y, {double opacity = 1}) {
    _image(canvas, image, x + 0.5 - image.width / 32, y + 1 - image.height / 16, opacity: opacity);
  }

  void _centred(Canvas canvas, ui.Image image, double cx, double cy) {
    _image(canvas, image, cx - image.width / 32, cy - image.height / 32);
  }

  double _snap(double v) => (v * _unit).roundToDouble() / _unit;

  int _variant(int x, int y, [int count = Textures.variants]) =>
      (TileColors.hash(x, y) * count).floor().clamp(0, count - 1);

  Offset _shake(String key) {
    if (gameState.shakeKey != key || gameState.shakeTime <= 0) return Offset.zero;
    return Offset((sin(gameState.shakeTime * 70) * 1.5).roundToDouble() / 16, 0);
  }

  // ---------------------------------------------------------------------------
  // Terrain

  void _drawTerrain(Canvas canvas, Textures textures, int minX, int minY, int maxX, int maxY, double clock) {
    final world = gameState.world;
    final waterFrame = (clock * 3).floor() % 4;
    final foamFrame = (clock * 1.5).floor() % 2;
    String side(int x, int y, int s) => world.getTileAt(x + _sides[s].x, y + _sides[s].y);

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final type = world.tiles[y][x];
        final v = _variant(x, y);
        final fx = x.toDouble();
        final fy = y.toDouble();

        if (type == 'water') {
          _drawWater(canvas, textures, world, x, y, waterFrame, foamFrame);
          continue;
        }

        final base = switch (type) {
          'fence' => textures.tiles['grass']![v],
          'farmland' => textures.tiles[world.crops['${x}_$y']?.watered == true ? 'farmland_wet' : 'farmland']![v],
          _ => (textures.tiles[type] ?? textures.tiles['grass']!)[v],
        };
        _image(canvas, base, fx, fy);

        // Grass spills over the edges of paths and bare ground, and the
        // forest floor over the edges of open grass.
        if (type == 'path' || type == 'dirt' || type == 'sand') {
          for (var s = 0; s < 4; s++) {
            final n = side(x, y, s);
            if (n == 'grass' || n == 'fence' || n == 'forest_grass') {
              final ramp = n == 'forest_grass' ? 'forest' : 'grass';
              _image(canvas, textures.fringe[ramp]![s][_variant(x, y, 2)], fx, fy);
            }
          }
        } else if (type == 'grass' || type == 'fence') {
          for (var s = 0; s < 4; s++) {
            if (side(x, y, s) == 'forest_grass') {
              _image(canvas, textures.fringe['forest']![s][_variant(x, y, 2)], fx, fy);
            }
          }
        }

        if (type == 'stone') {
          if (side(x, y, 2) != 'stone') _image(canvas, textures.cliffFace, fx, fy);
          if (side(x, y, 0) != 'stone') _image(canvas, textures.cliffTop, fx, fy);
          if (side(x, y, 3) != 'stone') _image(canvas, textures.cliffLeft, fx, fy);
          if (side(x, y, 1) != 'stone') _image(canvas, textures.cliffRight, fx, fy);
        } else if (side(x, y, 0) == 'stone') {
          _image(canvas, textures.cliffShadow, fx, fy);
        }

        if (type == 'bridge') {
          if (side(x, y, 0) != 'bridge') _image(canvas, textures.railTop, fx, fy);
          if (side(x, y, 2) != 'bridge') _image(canvas, textures.railBottom, fx, fy);
        } else {
          for (var s = 0; s < 4; s++) {
            if (side(x, y, s) == 'water') _image(canvas, textures.landEdge[s], fx, fy);
          }
        }
      }
    }
  }

  /// A water tile with shallows and foam along its shores.
  void _drawWater(Canvas canvas, Textures textures, Level level, int x, int y, int waterFrame, int foamFrame) {
    String side(int s) => level.getTileAt(x + _sides[s].x, y + _sides[s].y);
    bool wet(String t) => t == 'water' || t == 'bridge' || t == 'void';
    final fx = x.toDouble();
    final fy = y.toDouble();

    _image(canvas, textures.water[_variant(x, y)][waterFrame], fx, fy);
    final dry = [for (var s = 0; s < 4; s++) !wet(side(s))];
    for (var s = 0; s < 4; s++) {
      if (dry[s]) _image(canvas, textures.shore[s][foamFrame], fx, fy);
    }
    // Corners, clockwise from the top left, between two wet sides.
    for (var corner = 0; corner < 4; corner++) {
      final a = (corner + 3) % 4;
      final b = corner;
      final diagonal = level.getTileAt(x + _sides[a].x + _sides[b].x, y + _sides[a].y + _sides[b].y);
      if (!dry[a] && !dry[b] && !wet(diagonal)) _image(canvas, textures.shoreCorner[corner], fx, fy);
    }
  }

  /// Tunnels, rock and the underground pool. A wall with floor in front of
  /// it shows its face; deeper rock shows its dark top.
  void _drawMineTerrain(Canvas canvas, Textures textures, Mine mine, int minX, int minY, int maxX, int maxY, double clock) {
    final waterFrame = (clock * 1.5).floor() % 4;
    final foamFrame = (clock * 0.8).floor() % 2;
    String side(int x, int y, int s) => mine.getTileAt(x + _sides[s].x, y + _sides[s].y);
    bool rock(String t) => t == 'cave_wall' || t == 'void';

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final type = mine.tiles[y][x];
        final v = _variant(x, y);
        final fx = x.toDouble();
        final fy = y.toDouble();

        if (type == 'water') {
          _drawWater(canvas, textures, mine, x, y, waterFrame, foamFrame);
        } else if (type == 'cave_wall') {
          if (rock(side(x, y, 2))) {
            _image(canvas, textures.caveTop[v], fx, fy);
            for (final s in const [0, 1, 3]) {
              if (!rock(side(x, y, s))) _image(canvas, textures.caveRim[s], fx, fy);
            }
          } else {
            _image(canvas, textures.caveFace[v], fx, fy);
            if (!rock(side(x, y, 3))) _image(canvas, textures.caveFaceLeft, fx, fy);
            if (!rock(side(x, y, 1))) _image(canvas, textures.caveFaceRight, fx, fy);
          }
        } else {
          _image(canvas, textures.caveFloor[v], fx, fy);
          if (rock(side(x, y, 0))) _image(canvas, textures.caveShadow, fx, fy);
          if (mine.rails.contains(Point(x, y))) _image(canvas, textures.rails, fx, fy);
          for (var s = 0; s < 4; s++) {
            if (side(x, y, s) == 'water') _image(canvas, textures.landEdge[s], fx, fy);
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Things lying flat on the ground, and the shadows of standing things.

  void _drawGround(Canvas canvas, Textures textures, bool Function(Offset) visible) {
    final world = gameState.world;

    if (!world.bridgeBuilt) {
      for (final p in world.bridgeTiles) {
        _image(canvas, textures.brokenPosts, p.x.toDouble(), p.y.toDouble());
      }
    }
    if (!world.farmUnlocked) {
      final area = world.farmArea;
      for (int y = area.top.toInt(); y < area.bottom; y++) {
        for (int x = area.left.toInt(); x < area.right; x++) {
          _image(canvas, textures.tallGrass[_variant(x, y, 3)], x.toDouble(), y.toDouble());
        }
      }
    }
    for (final entry in world.crops.entries) {
      final parts = entry.key.split('_');
      final spot = Offset(double.parse(parts[0]), double.parse(parts[1]));
      if (visible(spot)) _image(canvas, textures.crops[entry.value.stage.clamp(0, 3)], spot.dx, spot.dy);
    }
    for (final entry in world.plants.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final x = p.dx.toInt();
      final y = p.dy.toInt();
      if (entry.key.startsWith('flower')) {
        _image(canvas, textures.flowers[_variant(x, y)], p.dx, p.dy);
      } else if (entry.key.startsWith('grass_tall')) {
        _image(canvas, textures.tallGrass[_variant(x, y, 3)], p.dx, p.dy);
      } else {
        _centred(canvas, textures.shadowMedium, p.dx + 0.5, p.dy + 0.92);
      }
    }
    for (final (i, cave) in world.caveEntrances.indexed) {
      if (!visible(cave)) continue;
      // The first cave is the old mine.
      final image = i > 0
          ? textures.cave
          : world.mineOpen
              ? textures.mineEntrance
              : textures.boardedMineEntrance;
      _image(canvas, image, cave.dx, cave.dy);
    }
    if (visible(world.bed)) _image(canvas, textures.bed, world.bed.dx, world.bed.dy);

    for (final tree in [...world.trees.values, ...world.appleTrees.values]) {
      if (visible(tree)) _centred(canvas, textures.shadowLarge, tree.dx + 0.5, tree.dy + 0.95);
    }
    for (final rock in world.rocks.values) {
      if (visible(rock)) _centred(canvas, textures.shadowMedium, rock.dx + 0.5, rock.dy + 0.92);
    }
    for (final animal in world.animals.values) {
      if (visible(animal)) _centred(canvas, textures.shadowSmall, animal.dx + 0.5, animal.dy + 0.94);
    }
    _drawPeopleShadows(canvas, textures, world.npcs, visible);
  }

  void _drawMineGround(Canvas canvas, Textures textures, Mine mine, bool Function(Offset) visible) {
    for (final p in mine.mushrooms.values) {
      if (visible(p)) _image(canvas, textures.mushrooms[_variant(p.dx.toInt(), p.dy.toInt())], p.dx, p.dy);
    }
    // The ladder stands against the rock face, its top in the shaft above.
    _standing(canvas, textures.ladder, mine.ladder.x.toDouble(), mine.ladder.y.toDouble());

    for (final rock in [...mine.rocks.values, if (mine.cart case final cart?) cart]) {
      if (visible(rock)) _centred(canvas, textures.shadowMedium, rock.dx + 0.5, rock.dy + 0.92);
    }
    _drawPeopleShadows(canvas, textures, mine.npcs, visible);
  }

  void _drawPeopleShadows(Canvas canvas, Textures textures, List<Npc> npcs, bool Function(Offset) visible) {
    for (final npc in npcs) {
      if (visible(npc.position)) _centred(canvas, textures.shadowSmall, npc.position.dx + 0.5, npc.position.dy + 0.96);
    }
    final player = gameState.player.position;
    _centred(canvas, textures.shadowSmall, player.dx, player.dy + 0.46);
  }

  // ---------------------------------------------------------------------------
  // Standing things, drawn in depth order so nearer things cover farther ones.

  void _drawStanding(
    Canvas canvas,
    Textures textures,
    bool Function(Offset) visible,
    double clock,
    int minX,
    int minY,
    int maxX,
    int maxY,
  ) {
    final world = gameState.world;
    final sprites = <(double, VoidCallback)>[];
    void add(double depth, VoidCallback draw) => sprites.add((depth, draw));

    for (final entry in world.trees.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final x = p.dx.toInt();
      final y = p.dy.toInt();
      final image = world.isPine(x, y) ? textures.pines[_variant(y, x, 2)] : textures.oaks[_variant(x, y, 3)];
      final shake = _shake(entry.key);
      add(p.dy + 1, () => _standing(canvas, image, p.dx + shake.dx, p.dy));
    }
    for (final entry in world.appleTrees.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final v = _variant(p.dx.toInt(), p.dy.toInt(), 2);
      final image = world.hasFruit(entry.key) ? textures.appleTrees[v] : textures.bareAppleTrees[v];
      add(p.dy + 1, () => _standing(canvas, image, p.dx, p.dy));
    }
    for (final entry in world.rocks.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final image = textures.rocks[_variant(p.dx.toInt(), p.dy.toInt())];
      final shake = _shake(entry.key);
      add(p.dy + 1, () => _standing(canvas, image, p.dx + shake.dx, p.dy));
    }
    for (final entry in world.plants.entries) {
      final p = entry.value;
      if (!entry.key.startsWith('berry_bush') || !visible(p)) continue;
      final v = _variant(p.dx.toInt(), p.dy.toInt(), 3);
      final image = world.hasFruit(entry.key) ? textures.bushes[v] : textures.bareBushes[v];
      add(p.dy + 1, () => _standing(canvas, image, p.dx, p.dy));
    }

    _addFires(add, canvas, textures, [(world.firePit, world.firePitBuilt), for (final c in world.campfires) (c, true)],
        visible, clock);

    final forge = _forgeSpot;
    if (visible(forge)) {
      final image = world.forgeBuilt ? textures.forge[(clock * 6).floor() % 3] : textures.forgeRuin;
      add(forge.dy + 1, () => _image(canvas, image, forge.dx, forge.dy + 1 - image.height / 16));
    }

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (world.tiles[y][x] != 'fence') continue;
        add(y + 1.0, () => _drawFence(canvas, textures, x, y));
      }
    }

    for (final entry in world.animals.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final x = p.dx.toInt();
      final y = p.dy.toInt();
      final images = entry.key.startsWith('rabbit')
          ? textures.rabbit
          : entry.key.startsWith('deer')
              ? textures.deer
              : textures.bird;
      final image = images[_variant(x, y, 2)];
      // Small animals hop now and then.
      final hop = !entry.key.startsWith('deer') && ((clock * 0.8 + TileColors.hash(y, x)) % 1) < 0.08;
      add(p.dy + 1, () => _image(canvas, image, p.dx, p.dy - (hop ? 2 / 16 : 0)));
    }

    _addNpcs(add, canvas, textures, world.npcs, visible);
    _addPlayer(add, canvas, textures, clock);

    for (final house in world.houses) {
      if (!visible(house.topLeft) && !visible(house.bottomRight)) continue;
      add(house.bottom, () => _drawHouse(canvas, textures, house, clock));
    }

    sprites.sort((a, b) => a.$1.compareTo(b.$1));
    for (final sprite in sprites) {
      sprite.$2();
    }
  }

  void _drawMineStanding(Canvas canvas, Textures textures, Mine mine, bool Function(Offset) visible, double clock) {
    final sprites = <(double, VoidCallback)>[];
    void add(double depth, VoidCallback draw) => sprites.add((depth, draw));

    for (final entry in mine.rocks.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final v = _variant(p.dx.toInt(), p.dy.toInt());
      final image = entry.key.startsWith('iron')
          ? textures.oreRocks[v]
          : entry.key.startsWith('crystal')
              ? textures.crystals[v]
              : textures.mineRocks[v];
      final shake = _shake(entry.key);
      add(p.dy + 1, () => _standing(canvas, image, p.dx + shake.dx, p.dy));
    }
    for (final web in mine.webs.values) {
      if (visible(web)) add(web.dy + 1, () => _image(canvas, textures.cobweb, web.dx, web.dy));
    }
    for (final entry in mine.rubble.entries) {
      final p = entry.value;
      if (!visible(p)) continue;
      final shake = _shake(entry.key);
      add(p.dy + 1, () => _standing(canvas, textures.rubble, p.dx + shake.dx, p.dy));
    }
    for (final frame in mine.frames.values) {
      if (visible(frame)) add(frame.dy + 1, () => _standing(canvas, textures.timberFrame, frame.dx, frame.dy));
    }
    if (mine.cart case final cart?) {
      if (visible(cart)) add(cart.dy + 1, () => _standing(canvas, textures.mineCart, cart.dx, cart.dy));
    }
    _addFires(add, canvas, textures, [for (final c in mine.campfires) (c, true)], visible, clock);
    _addNpcs(add, canvas, textures, mine.npcs, visible);
    _addPlayer(add, canvas, textures, clock);

    sprites.sort((a, b) => a.$1.compareTo(b.$1));
    for (final sprite in sprites) {
      sprite.$2();
    }
  }

  /// The forge's top-left tile.
  Offset get _forgeSpot {
    final t = gameState.world.forgeTiles.first;
    return Offset(t.x.toDouble(), t.y.toDouble());
  }

  void _addFires(
    void Function(double, VoidCallback) add,
    Canvas canvas,
    Textures textures,
    List<(Offset, bool)> fires,
    bool Function(Offset) visible,
    double clock,
  ) {
    for (final (i, (p, lit)) in fires.indexed) {
      if (!visible(p)) continue;
      final image = lit ? textures.fire[((clock * 8).floor() + i) % 3] : textures.coldFirePit;
      add(p.dy + 1, () => _image(canvas, image, p.dx, p.dy));
    }
  }

  void _addNpcs(
    void Function(double, VoidCallback) add,
    Canvas canvas,
    Textures textures,
    List<Npc> npcs,
    bool Function(Offset) visible,
  ) {
    for (final npc in npcs) {
      if (!visible(npc.position)) continue;
      final image = textures.character(npc.look)[_facing(npc)]!.first;
      add(npc.position.dy + 1, () => _image(canvas, image, npc.position.dx, npc.position.dy + 1 - 17 / 16));
    }
  }

  /// The player, with a torch or lantern in hand when it's dark.
  void _addPlayer(void Function(double, VoidCallback) add, Canvas canvas, Textures textures, double clock) {
    final player = gameState.player;
    final frames = textures.character(CharacterLook.player)[player.direction] ??
        textures.character(CharacterLook.player)['down']!;
    final step = gameState.isMoving ? const [0, 1, 0, 2][(gameState.walkTime * 8).floor() % 4] : 0;
    final held = gameState.heldLight;
    add(player.position.dy + 0.5, () {
      final x = player.position.dx - 0.5;
      final y = player.position.dy + 0.5 - 17 / 16;
      void drawHeld() {
        if (held == null) return;
        final image = held == 'lantern' ? textures.heldLantern : textures.heldTorch[(clock * 8).floor() % 3];
        // In the hand on the side the player faces. From behind, it is held
        // up past the shoulder, so the flame shows beside the head.
        final hand = switch (player.direction) {
          'up' => 13,
          'left' => 3,
          'right' => 12,
          _ => 11,
        };
        final grip = held == 'lantern' ? 3 : 2;
        _image(canvas, image, x + (hand - grip) / 16, y + (14 - image.height) / 16);
      }

      // Seen from behind, the light is in front of the player.
      if (player.direction == 'up') drawHeld();
      _image(canvas, frames[step], x, y);
      if (player.direction != 'up') drawHeld();
    });
  }

  void _drawFence(Canvas canvas, Textures textures, int x, int y) {
    final world = gameState.world;
    for (var s = 0; s < 4; s++) {
      final n = _sides[s];
      if (world.getTileAt(x + n.x, y + n.y) == 'fence') {
        _image(canvas, textures.fenceRails[s], x.toDouble(), y.toDouble());
      }
    }
    _image(canvas, textures.fencePost, x.toDouble(), y.toDouble());
  }

  /// A house's front wall and roof. Both fade away while the player is inside.
  void _drawHouse(Canvas canvas, Textures textures, Rect house, double clock) {
    final world = gameState.world;
    final p = gameState.player.position;
    final inside = Rect.fromLTRB(house.left + 1, house.top + 1, house.right - 1, house.bottom - 1);
    final dx = max(0.0, max(inside.left - p.dx, p.dx - inside.right));
    final dy = max(0.0, max(inside.top - p.dy, p.dy - inside.bottom));
    final opacity = (sqrt(dx * dx + dy * dy) / 0.7).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final night = world.getLightLevel() < 0.6;
    final front = house.bottom.toInt() - 1;
    for (int x = house.left.toInt(); x < house.right; x++) {
      final ui.Image image;
      if (world.getTileAt(x, front) == 'wood_floor') {
        final near = (Offset(x + 0.5, front + 0.5) - p).distance < 1.6;
        image = near ? textures.openDoor : textures.door;
      } else if (_isWindow(house, x)) {
        image = night ? textures.litWindow : textures.window;
      } else {
        image = textures.wall;
      }
      _image(canvas, image, x.toDouble(), front.toDouble(), opacity: opacity);
    }

    final widthTiles = house.width.toInt();
    final roof = textures.roof(widthTiles, house.height.toInt() - 1);
    _image(canvas, roof, house.left, house.top, opacity: opacity);

    // Smoke from the chimney.
    final chimney = Offset(house.left + (widthTiles * 16 - 18) / 16, house.top + 0.35);
    for (var i = 0; i < 3; i++) {
      final t = (clock * 0.35 + i / 3) % 1;
      final puff = chimney + Offset(sin(t * 5 + i) * 0.12 + t * 0.35, -t * 1.6);
      _paint.color = const Color(0xFFD8D8DC).withValues(alpha: (1 - t) * 0.5 * opacity);
      canvas.drawCircle(puff, 0.1 + t * 0.2, _paint);
    }
  }

  /// Windows sit either side of the middle of the front wall.
  bool _isWindow(Rect house, int x) {
    final left = house.left.toInt();
    final right = house.right.toInt() - 1;
    return (x == left + 1 || x == right - 1) &&
        gameState.world.getTileAt(x, house.bottom.toInt() - 1) == 'wood_wall';
  }

  /// Villagers turn towards the player when they come close.
  String _facing(Npc npc) {
    final d = gameState.player.position - (npc.position + const Offset(0.5, 0.5));
    if (d.distance > 3) return 'down';
    if (d.dx.abs() > d.dy.abs()) return d.dx > 0 ? 'right' : 'left';
    return d.dy > 0 ? 'down' : 'up';
  }

  void _drawHighlight(Canvas canvas, Textures textures, double clock) {
    final target = gameState.target;
    if (target == null) return;
    final opacity = 0.65 + 0.35 * sin(clock * 6);
    _image(canvas, textures.bracket, target.tile.x.toDouble(), target.tile.y.toDouble(), opacity: opacity);
  }

  // ---------------------------------------------------------------------------
  // Screen-space overlays

  /// Night in the valley, or the dark of the mine, with holes cut around
  /// every light.
  void _drawDarkness(Canvas canvas, Size size, double px, Offset Function(Offset) toScreen, double clock) {
    final underground = gameState.underground;
    final darkness = underground ? 0.97 : (1 - gameState.world.getLightLevel()) * 0.85;
    if (darkness < 0.01) return;

    final screen = Offset.zero & size;
    final lights = _lights(clock);

    canvas.saveLayer(screen, Paint());
    final shade = underground ? const Color(0xFF050404) : const Color(0xFF0A0A2A);
    canvas.drawRect(screen, Paint()..color = shade.withValues(alpha: darkness));
    final cut = Paint()..blendMode = BlendMode.dstOut;
    for (final light in lights) {
      final c = toScreen(light.centre);
      final r = light.radius * px;
      if (!screen.inflate(r).contains(c)) continue;
      final core = Colors.black.withValues(alpha: light.strength);
      cut.shader = RadialGradient(
        colors: [core, if (light.steady) core, Colors.transparent],
        stops: light.steady ? const [0, 0.45, 1] : null,
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, cut);
    }
    canvas.restore();

    // A warm or coloured glow around the lights.
    for (final light in lights) {
      final glow = light.glow;
      if (glow == null) continue;
      final c = toScreen(light.centre);
      final r = light.glowRadius * px;
      if (!screen.inflate(r).contains(c)) continue;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [glow.withValues(alpha: light.glowStrength * darkness), Colors.transparent],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  List<_Light> _lights(double clock) {
    final level = gameState.level;
    final lights = <_Light>[
      for (final (i, fire) in level.fires.indexed)
        _Light(fire + const Offset(0.5, 0.5), 4.5 + 0.15 * sin(clock * 6 + i), 1.0,
            glow: _fireGlow, glowRadius: 3, glowStrength: 0.3),
    ];

    if (level is Mine) {
      for (final m in level.mushrooms.values) {
        lights.add(_Light(m + const Offset(0.5, 0.6), 1.7, 0.55,
            glow: const Color(0xFF4FC6C8), glowRadius: 1.2, glowStrength: 0.35));
      }
      for (final e in level.rocks.entries) {
        if (!e.key.startsWith('crystal')) continue;
        lights.add(_Light(e.value + const Offset(0.5, 0.5), 1.4, 0.45,
            glow: const Color(0xFF9A7AF0), glowRadius: 1.1, glowStrength: 0.35));
      }
      // Daylight, or moonlight, falls down the shaft.
      final day = gameState.world.getLightLevel();
      lights.add(_Light(Offset(level.ladder.x + 0.5, level.ladder.y + 0.4), 3.2, 0.35 + 0.5 * day,
          glow: const Color(0xFFCFE6F5), glowRadius: 2, glowStrength: 0.05 + 0.15 * day));
    } else {
      final world = gameState.world;
      for (final house in world.houses) {
        for (int x = house.left.toInt(); x < house.right; x++) {
          if (!_isWindow(house, x)) continue;
          lights.add(_Light(Offset(x + 0.5, house.bottom - 0.6), 1.8, 0.75,
              glow: _fireGlow, glowRadius: 1.2, glowStrength: 0.25));
        }
      }
      if (world.forgeBuilt) {
        lights.add(_Light(_forgeSpot + const Offset(0.66, 0.6), 3 + 0.12 * sin(clock * 7), 0.9,
            glow: _fireGlow, glowRadius: 2.2, glowStrength: 0.35));
      }
    }

    final player = gameState.player.position;
    final radius = gameState.lightRadius;
    // Down in the mine a light carries its full strength out to half its
    // reach; under the night sky it fades from the middle, warmly tinted.
    final underground = gameState.underground;
    switch (gameState.heldLight) {
      case 'torch':
        final flicker = 1 + 0.04 * sin(clock * 9) + 0.03 * sin(clock * 23);
        lights.add(_Light(player, radius * flicker, 1.0,
            glow: _fireGlow,
            glowRadius: radius * 0.8,
            glowStrength: underground ? 0.28 : 0.42,
            steady: underground));
        break;
      case 'lantern':
        lights.add(_Light(player, radius, 1.0,
            glow: const Color(0xFFD8C8FF),
            glowRadius: radius * 0.6,
            glowStrength: underground ? 0.16 : 0.3,
            steady: underground));
        break;
      default:
        lights.add(_Light(player, radius, gameState.underground ? 0.55 : 0.6));
    }
    return lights;
  }

  void _drawNames(Canvas canvas, Offset Function(Offset) toScreen) {
    for (final npc in gameState.level.npcs) {
      final centre = npc.position + const Offset(0.5, 0.5);
      if ((centre - gameState.player.position).distance > 3) continue;
      _drawText(canvas, npc.name, toScreen(npc.position + const Offset(0.5, -0.3)), UiColors.cream, 13);
    }
  }

  void _drawQuestMarker(Canvas canvas, double px, Offset Function(Offset) toScreen, double clock) {
    if (!gameState.elderHasNews || gameState.underground) return;
    final elder = gameState.world.npc(Npc.elderId);
    if (elder == null) return;
    final bob = (sin(clock * 3) * 2).roundToDouble();
    final pixel = uiPixelFor(devicePixelRatio);
    final image = gameState.questReady ? UiTextures.instance.question : UiTextures.instance.exclamation;
    // Above the elder's name.
    final bottom = toScreen(elder.position + const Offset(0.5, -0.55));
    final w = image.width * pixel;
    final h = image.height * pixel;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(bottom.dx - w / 2, bottom.dy - h + bob * pixel, w, h),
      _pixels,
    );
  }

  void _drawFloatingTexts(Canvas canvas, Offset Function(Offset) toScreen) {
    for (final text in gameState.floatingTexts) {
      final progress = text.age / FloatingText.lifetime;
      final pos = toScreen(text.position + Offset(0, -0.3 - progress * 0.9));
      final alpha = (1 - progress * progress).clamp(0.0, 1.0);
      _drawText(canvas, text.text, pos, text.color.withValues(alpha: alpha), 16);
    }
  }

  void _drawQuestArrow(Canvas canvas, Size size, Offset Function(Offset) toScreen) {
    final target = gameState.questTargetPosition;
    if (target == null) return;
    final c = toScreen(target + const Offset(0.5, 0.5));
    const margin = 28.0;
    final view = Rect.fromLTRB(
      hudInsets.left + margin,
      hudInsets.top + margin,
      size.width - hudInsets.right - margin,
      size.height - hudInsets.bottom - margin,
    );
    if (view.isEmpty || view.contains(c)) return;

    // Place the arrow where the line from the view centre to the target
    // crosses the edge of the view.
    final dir = c - view.center;
    final sx = dir.dx == 0 ? double.infinity : (view.width / 2) / dir.dx.abs();
    final sy = dir.dy == 0 ? double.infinity : (view.height / 2) / dir.dy.abs();
    final edge = view.center + dir * min(sx, sy);

    final arrow = UiTextures.instance.icon('arrow');
    final arrowSize = 12 * uiPixelFor(devicePixelRatio) * 1.5;
    canvas.save();
    canvas.translate(edge.dx, edge.dy);
    canvas.rotate(dir.direction);
    canvas.drawImageRect(
      arrow,
      const Rect.fromLTWH(0, 0, 12, 12),
      Rect.fromCenter(center: Offset.zero, width: arrowSize, height: arrowSize),
      _pixels,
    );
    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, Offset centre, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: pixelText(fontSize, color: color, bold: true, shadow: false).copyWith(
          shadows: [
            Shadow(color: UiColors.shadow.withValues(alpha: color.a), offset: const Offset(0, 2)),
            Shadow(color: UiColors.shadow.withValues(alpha: color.a * 0.8), offset: const Offset(1, 1)),
            Shadow(color: UiColors.shadow.withValues(alpha: color.a * 0.8), offset: const Offset(-1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) =>
      oldDelegate.gameState != gameState ||
      oldDelegate.tileSize != tileSize ||
      oldDelegate.hudInsets != hudInsets ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
