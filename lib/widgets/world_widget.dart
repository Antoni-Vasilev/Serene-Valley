import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'player_widget.dart';
import 'tile_widget.dart';

/// Renders the visible part of the world, its objects and the player onto a
/// single canvas. Repaints whenever [gameState] notifies.
class WorldWidget extends StatelessWidget {
  final GameState gameState;
  final double tileSize;

  const WorldWidget({
    super.key,
    required this.gameState,
    required this.tileSize,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: WorldPainter(gameState: gameState, tileSize: tileSize),
      ),
    );
  }
}

class WorldPainter extends CustomPainter {
  final GameState gameState;
  final double tileSize;

  final Paint _paint = Paint();
  final Paint _tilePaint = Paint()..isAntiAlias = false;

  WorldPainter({required this.gameState, required this.tileSize})
      : super(repaint: gameState);

  @override
  void paint(Canvas canvas, Size size) {
    final world = gameState.world;
    final px = tileSize * gameState.cameraZoom;
    final camera = gameState.cameraOffset;

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

    bool visible(Offset p) =>
        p.dx >= minX && p.dx <= maxX && p.dy >= minY && p.dy <= maxY;

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

    // Ground decorations first so trees and animals draw on top of them.
    for (final entry in world.plants.entries) {
      if (visible(entry.value)) _drawPlant(canvas, entry.key, entry.value);
    }
    for (final location in world.caveEntrances) {
      if (visible(location)) _drawCave(canvas, location);
    }
    for (final location in world.villageLocations) {
      if (visible(location)) _drawVillageMarker(canvas, location);
    }
    for (final entry in world.rocks.entries) {
      if (visible(entry.value)) _drawRock(canvas, entry.value);
    }
    for (final entry in world.animals.entries) {
      if (visible(entry.value)) _drawAnimal(canvas, entry.key, entry.value);
    }

    _drawInteractionHighlight(canvas);

    final playerOrigin = gameState.player.position - const Offset(0.5, 0.5);
    final walkPhase = gameState.isMoving ? sin(gameState.walkTime * 14) : 0.0;
    PlayerSprite.paint(canvas, playerOrigin, gameState.player.direction, walkPhase);

    // Trees last so the canopy can overlap the player walking behind them.
    for (final entry in world.trees.entries) {
      if (visible(entry.value)) _drawTree(canvas, entry.value);
    }

    canvas.restore();

    // Darken the screen at night.
    final darkness = (1 - world.getLightLevel()) * 0.6;
    if (darkness > 0) {
      _paint.color = const Color(0xFF0A0A2A).withValues(alpha: darkness);
      canvas.drawRect(Offset.zero & size, _paint);
    }
  }

  void _drawInteractionHighlight(Canvas canvas) {
    final key = gameState.interactionKey;
    if (key == null) return;
    final world = gameState.world;
    final pos = world.trees[key] ?? world.rocks[key] ?? world.plants[key] ?? world.animals[key];
    if (pos == null) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(pos + const Offset(0.5, 0.5), 0.6, paint);
  }

  void _drawTree(Canvas canvas, Offset p) {
    // Trunk
    _paint.color = const Color(0xFF8B4513);
    canvas.drawRect(Rect.fromLTWH(p.dx + 0.4, p.dy + 0.45, 0.2, 0.55), _paint);
    // Leaves
    _paint.color = const Color(0xFF228B22);
    canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.3), 0.45, _paint);
    _paint.color = const Color(0xFF32CD32);
    canvas.drawCircle(Offset(p.dx + 0.42, p.dy + 0.22), 0.25, _paint);
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
      _paint.color = Colors.red;
      canvas.drawCircle(Offset(p.dx + 0.35, p.dy + 0.55), 0.07, _paint);
      canvas.drawCircle(Offset(p.dx + 0.6, p.dy + 0.5), 0.07, _paint);
      canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.72), 0.07, _paint);
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

  void _drawVillageMarker(Canvas canvas, Offset p) {
    _paint.color = Colors.brown;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 0.2, p.dy + 0.2, 0.6, 0.6), const Radius.circular(0.08)),
      _paint,
    );
    // A small house icon.
    _paint.color = Colors.white;
    final roof = Path()
      ..moveTo(p.dx + 0.3, p.dy + 0.5)
      ..lineTo(p.dx + 0.5, p.dy + 0.3)
      ..lineTo(p.dx + 0.7, p.dy + 0.5)
      ..close();
    canvas.drawPath(roof, _paint);
    canvas.drawRect(Rect.fromLTWH(p.dx + 0.36, p.dy + 0.5, 0.28, 0.2), _paint);
  }

  void _drawCave(Canvas canvas, Offset p) {
    _paint.color = Colors.black;
    canvas.drawOval(Rect.fromLTWH(p.dx + 0.1, p.dy + 0.3, 0.8, 0.5), _paint);
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) =>
      oldDelegate.gameState != gameState || oldDelegate.tileSize != tileSize;
}
