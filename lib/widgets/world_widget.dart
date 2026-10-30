import 'dart:math';
import 'package:flutter/material.dart';
import '../models/farm.dart';
import '../models/game_state.dart';
import '../models/npc.dart';
import 'player_widget.dart';
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
        painter: WorldPainter(gameState: gameState, tileSize: tileSize, hudInsets: hudInsets),
      ),
    );
  }
}

class WorldPainter extends CustomPainter {
  final GameState gameState;
  final double tileSize;
  final EdgeInsets hudInsets;

  final Paint _paint = Paint();
  final Paint _tilePaint = Paint()..isAntiAlias = false;

  WorldPainter({required this.gameState, required this.tileSize, this.hudInsets = EdgeInsets.zero})
      : super(repaint: gameState);

  static const _tileTargets = {'plant', 'water', 'growing', 'harvest', 'fish', 'bridge_site'};

  @override
  void paint(Canvas canvas, Size size) {
    final world = gameState.world;
    final px = tileSize * gameState.cameraZoom;
    final camera = gameState.cameraOffset;
    final clock = gameState.clock;

    Offset toScreen(Offset tile) => (tile - camera) * px + size.center(Offset.zero);

    // Area outside the world.
    _paint.color = const Color(0xFF1a1a2e);
    canvas.drawRect(Offset.zero & size, _paint);

    // Visible tile range, with a one-tile margin for tall objects.
    final halfW = size.width / 2 / px;
    final halfH = size.height / 2 / px;
    final minX = max(0, (camera.dx - halfW).floor() - 1);
    final minY = max(0, (camera.dy - halfH).floor() - 1);
    final maxX = min(world.width - 1, (camera.dx + halfW).ceil() + 1);
    final maxY = min(world.height - 1, (camera.dy + halfH).ceil() + 1);

    bool visible(Offset p) => p.dx >= minX && p.dx <= maxX && p.dy >= minY && p.dy <= maxY;

    canvas.save();
    // From here on, one unit equals one tile.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(px);
    canvas.translate(-camera.dx, -camera.dy);

    // Terrain. Tiles overlap slightly to avoid seams between them.
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        _tilePaint.color = TileColors.shaded(world.tiles[y][x], x, y);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.02, 1.02), _tilePaint);
      }
    }
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        _drawTileDetail(canvas, world.tiles[y][x], x, y, clock);
      }
    }

    if (!world.bridgeBuilt) _drawBrokenBridge(canvas);
    if (!world.farmUnlocked) _drawOvergrownField(canvas);

    // Ground objects first so trees and characters draw on top of them.
    for (final entry in world.crops.entries) {
      final parts = entry.key.split('_');
      final spot = Offset(double.parse(parts[0]), double.parse(parts[1]));
      if (visible(spot)) _drawCrop(canvas, spot, entry.value);
    }
    for (final entry in world.plants.entries) {
      if (visible(entry.value)) _drawPlant(canvas, entry.key, entry.value);
    }
    for (final location in world.caveEntrances) {
      if (visible(location)) _drawCave(canvas, location);
    }
    if (visible(world.firePit)) {
      _drawFirePit(canvas, world.firePit, lit: world.firePitBuilt, clock: clock);
    }
    for (int i = 0; i < world.campfires.length; i++) {
      final fire = world.campfires[i];
      if (visible(fire)) _drawFirePit(canvas, fire, lit: true, clock: clock + i);
    }
    if (visible(world.bed)) _drawBed(canvas, world.bed);
    for (final entry in world.rocks.entries) {
      if (visible(entry.value)) _drawRock(canvas, entry.value + _shake(entry.key));
    }
    for (final entry in world.animals.entries) {
      if (visible(entry.value)) _drawAnimal(canvas, entry.key, entry.value);
    }

    _drawInteractionHighlight(canvas);
    _drawCharacters(canvas, visible);

    // Trees last so the canopy can overlap the player walking behind them.
    for (final entry in world.trees.entries) {
      if (visible(entry.value)) _drawTree(canvas, entry.value + _shake(entry.key));
    }
    for (final entry in world.appleTrees.entries) {
      if (visible(entry.value)) {
        _drawTree(canvas, entry.value, apples: world.hasFruit(entry.key));
      }
    }

    canvas.restore();

    _drawNight(canvas, size, px, toScreen, clock);
    _drawNames(canvas, toScreen);
    _drawQuestMarker(canvas, px, toScreen, clock);
    _drawFloatingTexts(canvas, toScreen);
    _drawQuestArrow(canvas, size, toScreen);
  }

  Offset _shake(String key) {
    if (gameState.shakeKey != key || gameState.shakeTime <= 0) return Offset.zero;
    return Offset(sin(gameState.shakeTime * 70) * 0.06, 0);
  }

  // ---------------------------------------------------------------------------
  // Terrain

  void _drawTileDetail(Canvas canvas, String tile, int x, int y, double clock) {
    final world = gameState.world;
    final fx = x.toDouble();
    final fy = y.toDouble();
    switch (tile) {
      case 'water':
        // A ripple drifting back and forth.
        final phase = clock * 1.2 + TileColors.hash(x, y) * 6.28;
        _paint.color = Colors.white.withValues(alpha: 0.16 + 0.08 * sin(phase));
        canvas.drawRect(
          Rect.fromLTWH(fx + 0.25 + 0.15 * sin(phase), fy + 0.2 + 0.5 * TileColors.hash(y, x), 0.35, 0.05),
          _paint,
        );
        break;
      case 'bridge':
        _paint.color = const Color(0xFF6E4A26);
        for (final dx in const [0.25, 0.5, 0.75]) {
          canvas.drawRect(Rect.fromLTWH(fx + dx, fy, 0.03, 1), _paint);
        }
        // Rails along the outer edges.
        if (world.getTileAt(x, y - 1) != 'bridge') canvas.drawRect(Rect.fromLTWH(fx, fy, 1.02, 0.1), _paint);
        if (world.getTileAt(x, y + 1) != 'bridge') canvas.drawRect(Rect.fromLTWH(fx, fy + 0.9, 1.02, 0.1), _paint);
        break;
      case 'farmland':
        final crop = world.crops['${x}_$y'];
        if (crop != null && crop.watered) {
          _paint.color = const Color(0xFF2A1A0E).withValues(alpha: 0.35);
          canvas.drawRect(Rect.fromLTWH(fx, fy, 1.02, 1.02), _paint);
        }
        _paint.color = const Color(0xFF5A3618);
        for (final dy in const [0.2, 0.5, 0.8]) {
          canvas.drawRect(Rect.fromLTWH(fx + 0.08, fy + dy, 0.84, 0.06), _paint);
        }
        break;
      case 'fence':
        _paint.color = const Color(0xFF8D6E4A);
        bool fenceAt(int nx, int ny) => world.getTileAt(nx, ny) == 'fence';
        if (fenceAt(x - 1, y)) canvas.drawRect(Rect.fromLTWH(fx, fy + 0.45, 0.5, 0.08), _paint);
        if (fenceAt(x + 1, y)) canvas.drawRect(Rect.fromLTWH(fx + 0.5, fy + 0.45, 0.52, 0.08), _paint);
        if (fenceAt(x, y - 1)) canvas.drawRect(Rect.fromLTWH(fx + 0.46, fy, 0.08, 0.5), _paint);
        if (fenceAt(x, y + 1)) canvas.drawRect(Rect.fromLTWH(fx + 0.46, fy + 0.5, 0.08, 0.52), _paint);
        _paint.color = const Color(0xFF6D4C30);
        canvas.drawRect(Rect.fromLTWH(fx + 0.4, fy + 0.3, 0.2, 0.4), _paint);
        break;
      case 'wood_wall':
        _paint.color = const Color(0xFF5E3119);
        for (final dy in const [0.33, 0.66]) {
          canvas.drawRect(Rect.fromLTWH(fx, fy + dy, 1.02, 0.05), _paint);
        }
        break;
      case 'wood_floor':
        _paint.color = const Color(0xFFB0723A);
        for (final dy in const [0.25, 0.5, 0.75]) {
          canvas.drawRect(Rect.fromLTWH(fx, fy + dy, 1.02, 0.03), _paint);
        }
        break;
      case 'path':
        _paint.color = const Color(0xFFB09A73);
        final h = TileColors.hash(x, y);
        canvas.drawCircle(Offset(fx + 0.2 + h * 0.6, fy + 0.3), 0.05, _paint);
        canvas.drawCircle(Offset(fx + 0.8 - h * 0.5, fy + 0.75), 0.04, _paint);
        break;
      case 'stone':
        _paint.color = const Color(0xFF9E9E9E);
        canvas.drawRect(Rect.fromLTWH(fx + 0.1, fy + 0.1, 0.4, 0.08), _paint);
        _paint.color = const Color(0xFF666666);
        canvas.drawRect(Rect.fromLTWH(fx + 0.45, fy + 0.6, 0.4, 0.06), _paint);
        break;
    }
  }

  void _drawBrokenBridge(Canvas canvas) {
    final world = gameState.world;
    _paint.color = const Color(0xFF5D3A1A);
    for (final p in world.bridgeTiles) {
      final fx = p.x.toDouble();
      final fy = p.y.toDouble();
      // Posts sticking out of the water where the bridge used to be.
      if (!world.bridgeTiles.contains(Point(p.x, p.y - 1))) {
        canvas.drawRect(Rect.fromLTWH(fx + 0.4, fy + 0.02, 0.14, 0.25), _paint);
      }
      if (!world.bridgeTiles.contains(Point(p.x, p.y + 1))) {
        canvas.drawRect(Rect.fromLTWH(fx + 0.4, fy + 0.75, 0.14, 0.25), _paint);
      }
    }
  }

  void _drawOvergrownField(Canvas canvas) {
    final area = gameState.world.farmArea;
    _paint.color = const Color(0xFF4E7D2A);
    for (double y = area.top; y < area.bottom; y++) {
      for (double x = area.left; x < area.right; x++) {
        canvas.drawRect(Rect.fromLTWH(x + 0.25, y + 0.35, 0.06, 0.5), _paint);
        canvas.drawRect(Rect.fromLTWH(x + 0.6, y + 0.2, 0.06, 0.55), _paint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Objects

  void _drawCrop(Canvas canvas, Offset p, Crop crop) {
    final cx = p.dx + 0.5;
    switch (crop.stage) {
      case 0:
        _paint.color = const Color(0xFF3E2410);
        canvas.drawCircle(Offset(cx - 0.12, p.dy + 0.55), 0.05, _paint);
        canvas.drawCircle(Offset(cx + 0.1, p.dy + 0.5), 0.05, _paint);
        break;
      case 1:
        _paint.color = const Color(0xFF7CB342);
        canvas.drawOval(Rect.fromLTWH(cx - 0.16, p.dy + 0.45, 0.14, 0.08), _paint);
        canvas.drawOval(Rect.fromLTWH(cx + 0.02, p.dy + 0.42, 0.14, 0.08), _paint);
        canvas.drawRect(Rect.fromLTWH(cx - 0.02, p.dy + 0.45, 0.04, 0.15), _paint);
        break;
      default:
        final ripe = crop.isRipe;
        if (ripe) {
          _paint.color = const Color(0xFFFF8F00);
          canvas.drawOval(Rect.fromLTWH(cx - 0.12, p.dy + 0.55, 0.24, 0.16), _paint);
        }
        _paint.color = ripe ? const Color(0xFF558B2F) : const Color(0xFF7CB342);
        final leaf = ripe ? 0.32 : 0.24;
        canvas.drawOval(Rect.fromLTWH(cx - 0.05, p.dy + 0.58 - leaf, 0.1, leaf), _paint);
        canvas.drawOval(Rect.fromLTWH(cx - 0.2, p.dy + 0.62 - leaf * 0.8, 0.1, leaf * 0.8), _paint);
        canvas.drawOval(Rect.fromLTWH(cx + 0.1, p.dy + 0.62 - leaf * 0.8, 0.1, leaf * 0.8), _paint);
    }
  }

  void _drawFirePit(Canvas canvas, Offset p, {required bool lit, required double clock}) {
    final c = p + const Offset(0.5, 0.55);
    // Ring of stones.
    _paint.color = const Color(0xFF757575);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawCircle(c + Offset(cos(a) * 0.32, sin(a) * 0.24), 0.08, _paint);
    }
    // Logs.
    _paint.color = lit ? const Color(0xFF6D4C41) : const Color(0xFF3E3E3E);
    canvas.drawRect(Rect.fromCenter(center: c, width: 0.42, height: 0.08), _paint);
    canvas.drawRect(Rect.fromCenter(center: c, width: 0.08, height: 0.3), _paint);
    if (!lit) return;

    // Flickering flames.
    final flicker = sin(clock * 9) * 0.04 + sin(clock * 13.7) * 0.03;
    _paint.color = const Color(0xFFE53935);
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, -0.12), width: 0.34, height: 0.42 + flicker), _paint);
    _paint.color = const Color(0xFFFF9800);
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, -0.1), width: 0.24, height: 0.32 - flicker), _paint);
    _paint.color = const Color(0xFFFFEB3B);
    canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, -0.06), width: 0.12, height: 0.18 + flicker), _paint);
  }

  void _drawBed(Canvas canvas, Offset p) {
    _paint.color = const Color(0xFF6D4C41);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 0.1, p.dy + 0.05, 0.8, 0.9), const Radius.circular(0.08)),
      _paint,
    );
    _paint.color = const Color(0xFFF5F5F5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 0.2, p.dy + 0.12, 0.6, 0.2), const Radius.circular(0.06)),
      _paint,
    );
    _paint.color = const Color(0xFFC0504D);
    canvas.drawRect(Rect.fromLTWH(p.dx + 0.15, p.dy + 0.38, 0.7, 0.52), _paint);
  }

  void _drawTree(Canvas canvas, Offset p, {bool apples = false}) {
    // Trunk
    _paint.color = const Color(0xFF8B4513);
    canvas.drawRect(Rect.fromLTWH(p.dx + 0.4, p.dy + 0.45, 0.2, 0.55), _paint);
    // Leaves
    _paint.color = const Color(0xFF228B22);
    canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.3), 0.45, _paint);
    _paint.color = const Color(0xFF32CD32);
    canvas.drawCircle(Offset(p.dx + 0.42, p.dy + 0.22), 0.25, _paint);
    if (apples) {
      _paint.color = const Color(0xFFE53935);
      canvas.drawCircle(Offset(p.dx + 0.3, p.dy + 0.4), 0.07, _paint);
      canvas.drawCircle(Offset(p.dx + 0.62, p.dy + 0.2), 0.07, _paint);
      canvas.drawCircle(Offset(p.dx + 0.66, p.dy + 0.48), 0.07, _paint);
    }
  }

  void _drawRock(Canvas canvas, Offset p) {
    final rect = Rect.fromLTWH(p.dx + 0.1, p.dy + 0.25, 0.8, 0.65);
    _paint.color = const Color(0xFF696969);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(0.2)), _paint);
    _paint.color = const Color(0xFFA9A9A9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 0.2, p.dy + 0.3, 0.45, 0.3), const Radius.circular(0.12)),
      _paint,
    );
  }

  void _drawPlant(Canvas canvas, String key, Offset p) {
    if (key.startsWith('berry_bush')) {
      _paint.color = const Color(0xFF228B22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 0.15, p.dy + 0.4, 0.7, 0.5), const Radius.circular(0.2)),
        _paint,
      );
      if (gameState.world.hasFruit(key)) {
        _paint.color = Colors.red;
        canvas.drawCircle(Offset(p.dx + 0.35, p.dy + 0.55), 0.07, _paint);
        canvas.drawCircle(Offset(p.dx + 0.6, p.dy + 0.5), 0.07, _paint);
        canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.72), 0.07, _paint);
      }
    } else if (key.startsWith('flower')) {
      _paint.color = Colors.green;
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.47, p.dy + 0.5, 0.06, 0.4), _paint);
      _paint.color = Colors.yellow;
      canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.45), 0.12, _paint);
    } else {
      _paint.color = const Color(0xFF2E7D32);
      for (final dx in const [0.3, 0.45, 0.6]) {
        canvas.drawRect(Rect.fromLTWH(p.dx + dx, p.dy + 0.45, 0.06, 0.45), _paint);
      }
    }
  }

  void _drawAnimal(Canvas canvas, String key, Offset p) {
    if (key.startsWith('rabbit')) {
      _paint.color = Colors.white;
      canvas.drawOval(Rect.fromLTWH(p.dx + 0.25, p.dy + 0.5, 0.5, 0.35), _paint);
      canvas.drawCircle(Offset(p.dx + 0.68, p.dy + 0.48), 0.13, _paint);
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.62, p.dy + 0.2, 0.05, 0.2), _paint);
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.71, p.dy + 0.2, 0.05, 0.2), _paint);
    } else if (key.startsWith('deer')) {
      _paint.color = const Color(0xFF8B4513);
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.28, p.dy + 0.65, 0.08, 0.3), _paint);
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.62, p.dy + 0.65, 0.08, 0.3), _paint);
      canvas.drawOval(Rect.fromLTWH(p.dx + 0.2, p.dy + 0.4, 0.6, 0.35), _paint);
      canvas.drawCircle(Offset(p.dx + 0.78, p.dy + 0.35), 0.13, _paint);
      _paint.color = const Color(0xFF5D3A1A);
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.72, p.dy + 0.08, 0.04, 0.18), _paint);
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.82, p.dy + 0.08, 0.04, 0.18), _paint);
    } else {
      _paint.color = Colors.blue;
      canvas.drawOval(Rect.fromLTWH(p.dx + 0.3, p.dy + 0.4, 0.4, 0.22), _paint);
      _paint.color = Colors.red;
      canvas.drawCircle(Offset(p.dx + 0.68, p.dy + 0.42), 0.1, _paint);
      _paint.color = Colors.orange;
      canvas.drawRect(Rect.fromLTWH(p.dx + 0.77, p.dy + 0.4, 0.07, 0.05), _paint);
    }
  }

  void _drawCave(Canvas canvas, Offset p) {
    _paint.color = Colors.black;
    canvas.drawOval(Rect.fromLTWH(p.dx + 0.1, p.dy + 0.3, 0.8, 0.5), _paint);
  }

  void _drawCharacters(Canvas canvas, bool Function(Offset) visible) {
    final player = gameState.player;
    final characters = <(double, VoidCallback)>[];

    for (final npc in gameState.world.npcs) {
      if (!visible(npc.position)) continue;
      characters.add((
        npc.position.dy + 0.5,
        () => CharacterSprite.paint(canvas, npc.position, _facing(npc), 0, look: npc.look),
      ));
    }
    final walkPhase = gameState.isMoving ? sin(gameState.walkTime * 14) : 0.0;
    characters.add((
      player.position.dy,
      () => CharacterSprite.paint(canvas, player.position - const Offset(0.5, 0.5), player.direction, walkPhase),
    ));

    // Whoever stands further down the screen is drawn in front.
    characters.sort((a, b) => a.$1.compareTo(b.$1));
    for (final c in characters) {
      c.$2();
    }
  }

  /// Villagers turn towards the player when they come close.
  String _facing(Npc npc) {
    final d = gameState.player.position - (npc.position + const Offset(0.5, 0.5));
    if (d.distance > 3) return 'down';
    if (d.dx.abs() > d.dy.abs()) return d.dx > 0 ? 'right' : 'left';
    return d.dy > 0 ? 'down' : 'up';
  }

  void _drawInteractionHighlight(Canvas canvas) {
    final target = gameState.target;
    if (target == null) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06
      ..color = Colors.white.withValues(alpha: 0.8);
    final tile = Offset(target.tile.x.toDouble(), target.tile.y.toDouble());
    if (_tileTargets.contains(target.type)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(tile.dx + 0.06, tile.dy + 0.06, 0.88, 0.88), const Radius.circular(0.15)),
        paint,
      );
    } else {
      canvas.drawCircle(tile + const Offset(0.5, 0.5), 0.6, paint);
    }
  }

  // ---------------------------------------------------------------------------
  // Screen-space overlays

  void _drawNight(Canvas canvas, Size size, double px, Offset Function(Offset) toScreen, double clock) {
    final world = gameState.world;
    final darkness = (1 - world.getLightLevel()) * 0.85;
    if (darkness < 0.01) return;

    final screen = Offset.zero & size;
    final fires = world.fires;

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
    light(gameState.player.position, 2.2, 0.6);
    canvas.restore();

    // Warm glow around fires.
    for (final fire in fires) {
      final c = toScreen(fire + const Offset(0.5, 0.5));
      final r = 3 * px;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFF9800).withValues(alpha: 0.3 * darkness), Colors.transparent],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  void _drawNames(Canvas canvas, Offset Function(Offset) toScreen) {
    for (final npc in gameState.world.npcs) {
      final centre = npc.position + const Offset(0.5, 0.5);
      if ((centre - gameState.player.position).distance > 3) continue;
      _drawText(canvas, npc.name, toScreen(npc.position + const Offset(0.5, -0.15)), Colors.white, 11);
    }
  }

  void _drawQuestMarker(Canvas canvas, double px, Offset Function(Offset) toScreen, double clock) {
    if (gameState.questTargetPosition == null) return;
    final elder = gameState.world.npc(Npc.elderId);
    if (elder == null) return;
    final bob = sin(clock * 3) * 0.08;
    final c = toScreen(elder.position + Offset(0.5, -0.85 + bob));
    final r = 0.26 * px;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF5D4037),
    );
    _drawText(canvas, gameState.questReady ? '?' : '!', c, const Color(0xFF5D4037), r * 1.3, shadow: false);
  }

  void _drawFloatingTexts(Canvas canvas, Offset Function(Offset) toScreen) {
    for (final text in gameState.floatingTexts) {
      final progress = text.age / FloatingText.lifetime;
      final pos = toScreen(text.position + Offset(0, -0.3 - progress * 0.9));
      final alpha = (1 - progress * progress).clamp(0.0, 1.0);
      _drawText(canvas, text.text, pos, text.color.withValues(alpha: alpha), 14);
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

    canvas.save();
    canvas.translate(edge.dx, edge.dy);
    canvas.rotate(dir.direction);
    final arrow = Path()
      ..moveTo(16, 0)
      ..lineTo(-10, -12)
      ..lineTo(-4, 0)
      ..lineTo(-10, 12)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF5D4037),
    );
    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, Offset centre, Color color, double fontSize, {bool shadow = true}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: shadow ? [Shadow(color: Colors.black.withValues(alpha: color.a * 0.9), blurRadius: 3)] : null,
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
      oldDelegate.hudInsets != hudInsets;
}
