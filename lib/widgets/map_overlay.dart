import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/npc.dart';
import 'panel.dart';
import 'tile_widget.dart';

class MapOverlay extends StatelessWidget {
  final GameState gameState;

  const MapOverlay({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return FullScreenPanel(
      title: 'Map',
      icon: Icons.map,
      onClose: gameState.toggleMap,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: CustomPaint(
          painter: MapPainter(gameState: gameState),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final GameState gameState;

  MapPainter({required this.gameState});

  @override
  void paint(Canvas canvas, Size size) {
    final world = gameState.world;
    final paint = Paint()..isAntiAlias = false;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1a1a2e));

    final scale = min(size.width / world.width, size.height / world.height);
    final offsetX = (size.width - world.width * scale) / 2;
    final offsetY = (size.height - world.height * scale) / 2;
    Offset toMap(Offset tile) => Offset(offsetX + tile.dx * scale, offsetY + tile.dy * scale);

    for (int y = 0; y < world.height; y++) {
      for (int x = 0; x < world.width; x++) {
        paint.color = TileColors.of(world.tiles[y][x]);
        canvas.drawRect(Rect.fromLTWH(offsetX + x * scale, offsetY + y * scale, scale + 0.5, scale + 0.5), paint);
      }
    }

    paint.color = const Color(0xFF1B5E20);
    for (final tree in [...world.trees.values, ...world.appleTrees.values]) {
      canvas.drawRect(Rect.fromLTWH(toMap(tree).dx, toMap(tree).dy, scale, scale), paint);
    }
    paint.color = const Color(0xFF616161);
    for (final rock in world.rocks.values) {
      canvas.drawRect(Rect.fromLTWH(toMap(rock).dx, toMap(rock).dy, scale, scale), paint);
    }

    final dot = Paint();
    dot.color = Colors.orange;
    for (final fire in world.fires) {
      canvas.drawCircle(toMap(fire + const Offset(0.5, 0.5)), max(3, scale), dot);
    }

    // The elder, highlighted when there is a quest to pick up or hand in.
    final elder = world.npc(Npc.elderId);
    if (elder != null) {
      final c = toMap(elder.position + const Offset(0.5, 0.5));
      final hasNews = gameState.questTargetPosition != null;
      dot.color = hasNews ? const Color(0xFFFFD54F) : const Color(0xFFB39DDB);
      canvas.drawCircle(c, max(4, scale * 1.4), dot);
      if (hasNews) {
        final text = TextPainter(
          text: TextSpan(
            text: gameState.questReady ? '?' : '!',
            style: TextStyle(color: const Color(0xFF5D4037), fontSize: max(8, scale * 2), fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
        text.dispose();
      }
    }

    // The player.
    final p = toMap(gameState.player.position);
    canvas.drawCircle(p, max(4, scale * 1.4), Paint()..color = Colors.white);
    canvas.drawCircle(p, max(3, scale), Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
