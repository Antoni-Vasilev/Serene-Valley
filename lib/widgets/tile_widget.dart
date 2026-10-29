import 'package:flutter/material.dart';
import 'dart:math';

class TileWidget extends StatelessWidget {
  final String tileType;
  final double tileSize;
  final double lightLevel;

  const TileWidget({
    super.key,
    required this.tileType,
    required this.tileSize,
    this.lightLevel = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tileSize,
      height: tileSize,
      child: Container(
        decoration: BoxDecoration(
          color: _getTileColor(),
          border: Border.all(
            color: Colors.black.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: _buildTileContent(),
      ),
    );
  }

  Color _getTileColor() {
    switch (tileType) {
      case 'grass':
        return const Color(0xFF7CFC00);
      case 'dirt':
        return const Color(0xFF8B4513);
      case 'sand':
        return const Color(0xFFFFD700);
      case 'stone':
        return const Color(0xFF808080);
      case 'water':
        return Colors.blue;
      case 'forest_grass':
        return const Color(0xFF228B22);
      case 'wood_floor':
        return const Color(0xFFCD853F);
      case 'wood_wall':
        return const Color(0xFFA0522D);
      case 'void':
        return Colors.black;
      default:
        return const Color(0xFF7CFC00);
    }
  }

  Widget _buildTileContent() {
    switch (tileType) {
      case 'grass':
        return _buildGrassTile();
      case 'forest_grass':
        return _buildForestGrassTile();
      case 'water':
        return _buildWaterTile();
      case 'sand':
        return _buildSandTile();
      case 'stone':
        return _buildStoneTile();
      case 'dirt':
        return _buildDirtTile();
      case 'wood_floor':
        return _buildWoodFloorTile();
      case 'wood_wall':
        return _buildWoodWallTile();
      default:
        return Container();
    }
  }

  Widget _buildGrassTile() {
    return Container(
      color: const Color(0xFF7CFC00),
    );
  }

  Widget _buildForestGrassTile() {
    return Container(
      color: const Color(0xFF228B22),
    );
  }

  Widget _buildWaterTile() {
    return Container(
      color: Colors.blue,
    );
  }

  Widget _buildSandTile() {
    return Container(
      color: const Color(0xFFFFD700),
    );
  }

  Widget _buildStoneTile() {
    return Container(
      color: const Color(0xFF808080),
    );
  }

  Widget _buildDirtTile() {
    return Container(
      color: const Color(0xFF8B4513),
    );
  }

  Widget _buildWoodFloorTile() {
    return Container(
      color: const Color(0xFFCD853F),
    );
  }

  Widget _buildWoodWallTile() {
    return Container(
      color: const Color(0xFFA0522D),
    );
  }
}
