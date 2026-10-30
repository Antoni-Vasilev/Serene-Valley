import 'package:flutter/material.dart';

/// Colour palette for terrain tiles.
class TileColors {
  static Color of(String tileType) {
    switch (tileType) {
      case 'grass':
        return const Color(0xFF7CC243);
      case 'dirt':
        return const Color(0xFF8B5A2B);
      case 'sand':
        return const Color(0xFFE8CF7A);
      case 'stone':
        return const Color(0xFF808080);
      case 'water':
        return const Color(0xFF3A7BD5);
      case 'forest_grass':
        return const Color(0xFF3E8E2F);
      case 'wood_floor':
        return const Color(0xFFCD853F);
      case 'wood_wall':
        return const Color(0xFF8B4A2B);
      case 'path':
        return const Color(0xFFCDB389);
      case 'bridge':
        return const Color(0xFFA0703F);
      case 'farmland':
        return const Color(0xFF7A4E2A);
      case 'fence':
        // Fences stand on grass.
        return const Color(0xFF7CC243);
      case 'void':
        return Colors.black;
      default:
        return const Color(0xFF7CC243);
    }
  }

  /// Deterministic per-tile shade so large fields don't look flat.
  static Color shaded(String tileType, int x, int y) {
    final amount = hash(x, y) * 0.08;
    return Color.lerp(of(tileType), Colors.black, amount)!;
  }

  /// A stable pseudo-random value in 0..1 for a tile.
  static double hash(int x, int y) => (((x * 73856093) ^ (y * 19349663)) & 0xFF) / 255.0;
}
