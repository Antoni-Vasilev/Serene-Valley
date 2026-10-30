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
        return const Color(0xFFA0522D);
      case 'void':
        return Colors.black;
      default:
        return const Color(0xFF7CC243);
    }
  }

  /// Deterministic per-tile shade so large fields don't look flat.
  static Color shaded(String tileType, int x, int y) {
    final hash = ((x * 73856093) ^ (y * 19349663)) & 0xFF;
    final amount = (hash / 255.0) * 0.08;
    return Color.lerp(of(tileType), Colors.black, amount)!;
  }
}
