import 'package:flutter/material.dart';
import '../graphics/palette.dart';
import '../models/level.dart';

/// Flat colours for terrain tiles, used by the map.
class TileColors {
  static Color of(String tileType) {
    switch (tileType) {
      case 'grass':
      case 'fence':
        return Color(Palette.grass[2]);
      case 'dirt':
        return Color(Palette.dirt[2]);
      case 'sand':
        return Color(Palette.sand[2]);
      case 'stone':
        return Color(Palette.stone[2]);
      case 'water':
        return Color(Palette.water[2]);
      case 'forest_grass':
        return Color(Palette.forest[2]);
      case 'wood_floor':
      case 'bridge':
        return Color(Palette.wood[2]);
      case 'wood_wall':
        return Color(Palette.roof[2]);
      case 'path':
        return Color(Palette.cobble[2]);
      case 'farmland':
        return Color(Palette.soil[2]);
      case 'cave_floor':
        return Color(Palette.caveFloor[3]);
      case 'cave_wall':
        return Color(Palette.caveRock[1]);
      case 'void':
        return Colors.black;
      default:
        return Color(Palette.grass[2]);
    }
  }

  /// A stable pseudo-random value in 0..1 for a tile.
  static double hash(int x, int y) => tileHash(x, y);
}
