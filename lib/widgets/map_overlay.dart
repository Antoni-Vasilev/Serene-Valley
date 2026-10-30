import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../graphics/palette.dart';
import '../graphics/ui_textures.dart';
import '../models/npc.dart';
import 'pixel_ui.dart';
import 'tile_widget.dart';

class MapOverlay extends StatelessWidget {
  final GameState gameState;

  const MapOverlay({super.key, required this.gameState});

  static const _ladder = Color(0xFFDCEBF5);
  static const _mine = Color(0xFF2A2024);

  @override
  Widget build(BuildContext context) {
    final underground = gameState.underground;
    return PixelWindow(
      title: underground ? 'Old Mine' : 'Map',
      icon: 'map',
      onClose: gameState.toggleMap,
      child: Column(
        children: [
          Expanded(
            child: PixelPanel(
              frame: PixelFrame.parchment,
              padding: const EdgeInsets.all(2),
              child: CustomPaint(
                painter: MapPainter(gameState: gameState),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 8),
          PixelPanel(
            frame: PixelFrame.plate,
            padding: const EdgeInsets.all(3),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 4,
              children: [
                _legend(const Color(0xFFE5484D), 'You'),
                if (underground) ...[
                  _legend(_ladder, 'Ladder'),
                  _legend(Colors.orange, 'Fire'),
                ] else ...[
                  _legend(const Color(0xFFFFD54F), 'Elder Rowan'),
                  _legend(Colors.orange, 'Fire'),
                  _legend(TileColors.of('wood_wall'), 'Village'),
                  if (gameState.chapter >= 2) _legend(_mine, 'Old mine'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color,
                border: Border.all(color: UiColors.shadow, width: 2))),
        const SizedBox(width: 6),
        Text(label, style: pixelText(14)),
      ],
    );
  }
}

class MapPainter extends CustomPainter {
  final GameState gameState;

  MapPainter({required this.gameState});

  @override
  void paint(Canvas canvas, Size size) {
    final level = gameState.level;
    final mine = gameState.underground ? gameState.mine : null;
    final paint = Paint()..isAntiAlias = false;

    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFE5CFA5));

    final scale = min(size.width / level.width, size.height / level.height);
    final offsetX = (size.width - level.width * scale) / 2;
    final offsetY = (size.height - level.height * scale) / 2;
    Offset toMap(Offset tile) =>
        Offset(offsetX + tile.dx * scale, offsetY + tile.dy * scale);
    void square(Offset tile, Color color) {
      paint.color = color;
      final p = toMap(tile);
      canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, scale, scale), paint);
    }

    // In the mine, only the tunnels the player has seen are drawn, outlined
    // by the rock around them.
    bool open(int x, int y) => level.getTileAt(x, y) != 'cave_wall' && level.getTileAt(x, y) != 'void';
    for (int y = 0; y < level.height; y++) {
      for (int x = 0; x < level.width; x++) {
        if (mine != null) {
          if (!mine.isExplored(x, y)) continue;
          if (!open(x, y) && !open(x + 1, y) && !open(x - 1, y) && !open(x, y + 1) && !open(x, y - 1)) continue;
        }
        paint.color = TileColors.of(level.tiles[y][x]);
        canvas.drawRect(
            Rect.fromLTWH(offsetX + x * scale, offsetY + y * scale, scale + 0.5,
                scale + 0.5),
            paint);
      }
    }

    final dot = Paint();
    if (mine != null) {
      bool seen(Offset o) => mine.isExplored(o.dx.toInt(), o.dy.toInt());
      for (final e in mine.rocks.entries) {
        if (!seen(e.value)) continue;
        square(e.value, e.key.startsWith('iron')
            ? Color(Palette.rust[2])
            : e.key.startsWith('crystal')
                ? Color(Palette.crystal[3])
                : const Color(0xFF8A8A93));
      }
      for (final o in [...mine.webs.values, ...mine.rubble.values]) {
        if (seen(o)) square(o, const Color(0xFFE8E8F0));
      }
      final ladder = Offset(mine.ladder.x.toDouble(), mine.ladder.y.toDouble());
      dot.color = MapOverlay._ladder;
      canvas.drawCircle(toMap(ladder + const Offset(0.5, 0.5)), max(4, scale * 1.4), dot);
      for (final npc in mine.npcs) {
        if (!seen(npc.position)) continue;
        dot.color = const Color(0xFFFFD54F);
        canvas.drawCircle(toMap(npc.position + const Offset(0.5, 0.5)), max(4, scale * 1.2), dot);
      }
    } else {
      final world = gameState.world;
      paint.color = const Color(0xFF1B5E20);
      for (final tree in [...world.trees.values, ...world.appleTrees.values]) {
        canvas.drawRect(
            Rect.fromLTWH(toMap(tree).dx, toMap(tree).dy, scale, scale), paint);
      }
      paint.color = const Color(0xFF616161);
      for (final rock in world.rocks.values) {
        canvas.drawRect(
            Rect.fromLTWH(toMap(rock).dx, toMap(rock).dy, scale, scale), paint);
      }
      for (final t in world.forgeTiles) {
        square(Offset(t.x.toDouble(), t.y.toDouble()), const Color(0xFF5A5A65));
      }
      final entrance = world.mineEntrance;
      if (entrance != null && gameState.chapter >= 2) {
        final c = toMap(entrance + const Offset(0.5, 0.5));
        canvas.drawCircle(c, max(4, scale * 1.5), Paint()..color = const Color(0xFFF3E3C3));
        canvas.drawCircle(c, max(3, scale * 1.1), Paint()..color = MapOverlay._mine);
      }
    }

    dot.color = Colors.orange;
    for (final fire in level.fires) {
      canvas.drawCircle(
          toMap(fire + const Offset(0.5, 0.5)), max(3, scale), dot);
    }

    // The elder, highlighted when there is a quest to pick up or hand in.
    final elder = mine == null ? gameState.world.npc(Npc.elderId) : null;
    if (elder != null) {
      final c = toMap(elder.position + const Offset(0.5, 0.5));
      final hasNews = gameState.elderHasNews;
      dot.color = hasNews ? const Color(0xFFFFD54F) : const Color(0xFFB39DDB);
      canvas.drawCircle(c, max(4, scale * 1.4), dot);
      if (hasNews) {
        final text = TextPainter(
          text: TextSpan(
            text: gameState.questReady ? '?' : '!',
            style: TextStyle(
                color: const Color(0xFF5D4037),
                fontSize: max(8, scale * 2),
                fontWeight: FontWeight.bold),
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
    canvas.drawCircle(
        p, max(3, scale), Paint()..color = const Color(0xFFE5484D));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
