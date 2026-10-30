import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../graphics/textures.dart';
import '../graphics/ui_textures.dart';
import '../models/game_state.dart';
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

  @override
  void paint(Canvas canvas, Size size) {
    final textures = Textures.instance;
    final world = gameState.world;
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
    _paint.color = const Color(0xFF1a1a2e);
    canvas.drawRect(Offset.zero & size, _paint);

    // Visible tiles, with a margin for trees and roofs that reach over.
    final minX = max(0, (-tx / px).floor() - 1);
    final minY = max(0, (-ty / px).floor() - 1);
    final maxX = min(world.width - 1, ((size.width - tx) / px).ceil() + 1);
    final maxY = min(world.height - 1, ((size.height - ty) / px).ceil() + 2);
    bool visible(Offset p) => p.dx >= minX - 1 && p.dx <= maxX + 1 && p.dy >= minY - 1 && p.dy <= maxY + 2;

    canvas.save();
    // From here on, one unit equals one tile.
    canvas.translate(tx, ty);
    canvas.scale(px);

    _drawTerrain(canvas, textures, minX, minY, maxX, maxY, clock);
    _drawGround(canvas, textures, visible);
    _drawStanding(canvas, textures, visible, clock, minX, minY, maxX, maxY);
    _drawHighlight(canvas, textures, clock);

    canvas.restore();

    _drawNight(canvas, size, px, toScreen, clock);
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
    bool wet(String t) => t == 'water' || t == 'bridge' || t == 'void';

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final type = world.tiles[y][x];
        final v = _variant(x, y);
        final fx = x.toDouble();
        final fy = y.toDouble();

        if (type == 'water') {
          _image(canvas, textures.water[v][waterFrame], fx, fy);
          final dry = [for (var s = 0; s < 4; s++) !wet(side(x, y, s))];
          for (var s = 0; s < 4; s++) {
            if (dry[s]) _image(canvas, textures.shore[s][foamFrame], fx, fy);
          }
          // Corners, clockwise from the top left, between two wet sides.
          for (var corner = 0; corner < 4; corner++) {
            final a = (corner + 3) % 4;
            final b = corner;
            final diagonal = world.getTileAt(x + _sides[a].x + _sides[b].x, y + _sides[a].y + _sides[b].y);
            if (!dry[a] && !dry[b] && !wet(diagonal)) _image(canvas, textures.shoreCorner[corner], fx, fy);
          }
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
    for (final cave in world.caveEntrances) {
      if (visible(cave)) _image(canvas, textures.cave, cave.dx, cave.dy);
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
    for (final npc in world.npcs) {
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
      final forest = world.getTileAt(x, y) == 'forest_grass';
      final image = forest && _variant(x, y, 2) == 0
          ? textures.pines[_variant(y, x, 2)]
          : textures.oaks[_variant(x, y, 3)];
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

    final fires = [(world.firePit, world.firePitBuilt), for (final c in world.campfires) (c, true)];
    for (final (i, (p, lit)) in fires.indexed) {
      if (!visible(p)) continue;
      final image = lit ? textures.fire[((clock * 8).floor() + i) % 3] : textures.coldFirePit;
      add(p.dy + 1, () => _image(canvas, image, p.dx, p.dy));
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

    for (final npc in world.npcs) {
      if (!visible(npc.position)) continue;
      final image = textures.character(npc.look)[_facing(npc)]!.first;
      add(npc.position.dy + 1, () => _image(canvas, image, npc.position.dx, npc.position.dy + 1 - 17 / 16));
    }

    final player = gameState.player;
    final frames = textures.character(CharacterLook.player)[player.direction] ??
        textures.character(CharacterLook.player)['down']!;
    final step = gameState.isMoving ? const [0, 1, 0, 2][(gameState.walkTime * 8).floor() % 4] : 0;
    add(player.position.dy + 0.5, () {
      _image(canvas, frames[step], player.position.dx - 0.5, player.position.dy + 0.5 - 17 / 16);
    });

    for (final house in world.houses) {
      if (!visible(house.topLeft) && !visible(house.bottomRight)) continue;
      add(house.bottom, () => _drawHouse(canvas, textures, house, clock));
    }

    sprites.sort((a, b) => a.$1.compareTo(b.$1));
    for (final sprite in sprites) {
      sprite.$2();
    }
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

  void _drawNight(Canvas canvas, Size size, double px, Offset Function(Offset) toScreen, double clock) {
    final world = gameState.world;
    final darkness = (1 - world.getLightLevel()) * 0.85;
    if (darkness < 0.01) return;

    final screen = Offset.zero & size;
    final fires = world.fires;
    final windows = [
      for (final house in world.houses)
        for (int x = house.left.toInt(); x < house.right; x++)
          if (_isWindow(house, x)) Offset(x + 0.5, house.bottom - 0.6),
    ];

    // Darken everything, then cut soft holes around the lights.
    canvas.saveLayer(screen, Paint());
    canvas.drawRect(screen, Paint()..color = const Color(0xFF0A0A2A).withValues(alpha: darkness));
    final cut = Paint()..blendMode = BlendMode.dstOut;
    void light(Offset tile, double radius, double strength) {
      final c = toScreen(tile);
      final r = radius * px;
      cut.shader = RadialGradient(
        colors: [Colors.black.withValues(alpha: strength), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, cut);
    }

    for (int i = 0; i < fires.length; i++) {
      light(fires[i] + const Offset(0.5, 0.5), 4.5 + 0.15 * sin(clock * 6 + i), 1.0);
    }
    for (final window in windows) {
      light(window, 1.8, 0.75);
    }
    light(gameState.player.position, 2.2, 0.6);
    canvas.restore();

    // Warm glow around fires and windows.
    void glow(Offset tile, double radius, double strength) {
      final c = toScreen(tile);
      final r = radius * px;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFF9800).withValues(alpha: strength * darkness), Colors.transparent],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    for (final fire in fires) {
      glow(fire + const Offset(0.5, 0.5), 3, 0.3);
    }
    for (final window in windows) {
      glow(window, 1.2, 0.25);
    }
  }

  void _drawNames(Canvas canvas, Offset Function(Offset) toScreen) {
    for (final npc in gameState.world.npcs) {
      final centre = npc.position + const Offset(0.5, 0.5);
      if ((centre - gameState.player.position).distance > 3) continue;
      _drawText(canvas, npc.name, toScreen(npc.position + const Offset(0.5, -0.3)), UiColors.cream, 13);
    }
  }

  void _drawQuestMarker(Canvas canvas, double px, Offset Function(Offset) toScreen, double clock) {
    if (gameState.questTargetPosition == null) return;
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
